// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Origin, SummerGovernor} from "../../src/contracts/SummerGovernor.sol";
import {ISummerGovernorErrors} from "../../src/errors/ISummerGovernorErrors.sol";
import {ISummerGovernor} from "../../src/interfaces/ISummerGovernor.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {IOAppSetPeer} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {SummerGovernorTestBase, ExposedSummerGovernor} from "./SummerGovernorTestBase.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

contract SummerGovernorCrossChainTest is SummerGovernorTestBase {
    using OptionsBuilder for bytes;

    function setUp() public override {
        initializeTokenTests();
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");

        useNetworkA();

        // Set up Governor A (Hub Chain)
        SummerGovernor.GovernorParams memory paramsA = ISummerGovernor
            .GovernorParams({
                token: aSummerToken,
                timelock: timelockA,
                accessManager: address(accessManagerA),
                votingDelay: VOTING_DELAY,
                votingPeriod: VOTING_PERIOD,
                proposalThreshold: PROPOSAL_THRESHOLD,
                quorumFraction: QUORUM_FRACTION,
                endpoint: lzEndpointA,
                hubChainId: 31337,
                initialOwner: address(timelockA)
            });

        // Set up Governor B (Satellite Chain)
        SummerGovernor.GovernorParams memory paramsB = ISummerGovernor
            .GovernorParams({
                token: bSummerToken,
                timelock: timelockB,
                accessManager: address(accessManagerB),
                votingDelay: VOTING_DELAY,
                votingPeriod: VOTING_PERIOD,
                proposalThreshold: PROPOSAL_THRESHOLD,
                quorumFraction: QUORUM_FRACTION,
                endpoint: lzEndpointB,
                hubChainId: 31337,
                initialOwner: address(timelockB)
            });

        governorA = new ExposedSummerGovernor(paramsA);

        useNetworkB();
        governorB = new ExposedSummerGovernor(paramsB);

        // Set up roles and permissions
        useNetworkA();
        vm.startPrank(address(timelockA));
        accessManagerA.grantDecayControllerRole(address(governorA));
        timelockA.grantRole(timelockA.PROPOSER_ROLE(), address(governorA));
        timelockA.grantRole(timelockA.CANCELLER_ROLE(), address(governorA));
        vm.stopPrank();

        useNetworkB();
        vm.startPrank(address(timelockB));
        accessManagerB.grantDecayControllerRole(address(governorB));
        timelockB.grantRole(timelockB.PROPOSER_ROLE(), address(governorB));
        // So, we can cancel via cross-chain proposals
        timelockB.grantRole(timelockB.CANCELLER_ROLE(), address(timelockB));
        vm.stopPrank();

        // Wire the governors
        useNetworkA();
        vm.prank(address(timelockA));
        IOAppSetPeer(address(governorA)).setPeer(
            bEid,
            addressToBytes32(address(governorB))
        );

        useNetworkB();
        vm.prank(address(timelockB));
        IOAppSetPeer(address(governorB)).setPeer(
            aEid,
            addressToBytes32(address(governorA))
        );

        useNetworkA();
        vm.prank(owner);
        enableTransfers();
        changeTokensOwnership(address(timelockA), address(timelockB));

        vm.startPrank(address(timelockA));
        aSummerToken.delegate(address(timelockA));
        aSummerToken.transfer(address(timelockA), 1000);
        vm.stopPrank();
    }

    function test_CrossChainGovernanceFullCycle() public {
        // Start recording logs
        vm.recordLogs();

        // Setup: Give Alice enough tokens and ETH
        vm.deal(address(governorA), 100 ether);
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.quorum(block.timestamp - 1));
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        // Create cross-chain proposal
        (
            address[] memory srcTargets,
            uint256[] memory srcValues,
            bytes[] memory srcCalldatas,
            string memory srcDescription,
            uint256 dstProposalId,
            address[] memory dstTargets,
            uint256[] memory dstValues,
            bytes[] memory dstCalldatas,
            bytes32 dstDescriptionHash
        ) = _createCrossChainProposal(bEid, governorA);

        // Submit proposal on chain A
        vm.prank(alice);
        uint256 proposalIdA = governorA.propose(
            srcTargets,
            srcValues,
            srcCalldatas,
            srcDescription
        );

        // Vote and queue on chain A
        advanceTimeForVotingDelay();
        vm.prank(alice);
        governorA.castVote(proposalIdA, 1);
        advanceTimeForVotingPeriod();

        governorA.queue(
            srcTargets,
            srcValues,
            srcCalldatas,
            hashDescription(srcDescription)
        );

        // Execute on chain A which sends to chain B
        advanceTimeForTimelockMinDelay();

        vm.expectEmit(true, true, true, true);
        emit ISummerGovernor.ProposalSentCrossChain(dstProposalId, bEid);
        governorA.execute(
            srcTargets,
            srcValues,
            srcCalldatas,
            hashDescription(srcDescription)
        );

        useNetworkB();

        // Verify cross-chain message
        verifyPackets(bEid, addressToBytes32(address(governorB)));

        // Get the logs and verify events
        (
            bool foundReceivedEvent,
            bool foundQueuedEvent,
            uint256 queuedEta
        ) = _verifyProposalEvents(dstProposalId);

        assertTrue(
            foundReceivedEvent,
            "Missing ProposalReceivedCrossChain event"
        );
        assertTrue(foundQueuedEvent, "Missing ProposalQueued event");

        // Verify proposal is queued on chain B
        bytes32 salt = bytes20(address(governorB)) ^ dstDescriptionHash;
        bytes32 timelockId = timelockB.hashOperationBatch(
            dstTargets,
            dstValues,
            dstCalldatas,
            0, // predecessor
            salt
        );
        assertTrue(
            timelockB.isOperationPending(timelockId),
            "Operation should be pending in timelock"
        );

        // Execute on chain B after timelock delay
        vm.warp(queuedEta + 1);
        vm.deal(address(timelockB), 100 ether);
        deal(address(bSummerToken), address(timelockB), 1000);
        timelockB.executeBatch(
            dstTargets,
            dstValues,
            dstCalldatas,
            0, // predecessor
            salt
        );

        assertTrue(
            timelockB.isOperationDone(timelockId),
            "Operation should be done in timelock"
        );
    }

    function test_CrossChainProposalFailsWithInsufficientFee() public {
        // Setup: Give Alice enough tokens to propose and vote
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.quorum(block.timestamp - 1));
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        // Create cross-chain proposal
        (
            address[] memory srcTargets,
            uint256[] memory srcValues,
            bytes[] memory srcCalldatas,
            string memory srcDescription,
            ,
            ,
            ,
            ,

        ) = _createCrossChainProposal(bEid, governorA);

        // Submit proposal on chain A
        vm.prank(alice);
        uint256 proposalId = governorA.propose(
            srcTargets,
            srcValues,
            srcCalldatas,
            srcDescription
        );

        // Complete governance process on chain A
        advanceTimeForVotingDelay();
        vm.prank(alice);
        governorA.castVote(proposalId, 1);
        advanceTimeForVotingPeriod();

        governorA.queue(
            srcTargets,
            srcValues,
            srcCalldatas,
            hashDescription(srcDescription)
        );

        advanceTimeForTimelockMinDelay();

        // Ensure timelockA has insufficient ETH for LayerZero fees
        vm.deal(address(timelockA), 0);
        vm.deal(address(governorA), 0);

        // Execution should fail due to insufficient LayerZero fees
        vm.expectRevert(abi.encodeWithSignature("NotEnoughNative(uint256)", 0));
        governorA.execute(
            srcTargets,
            srcValues,
            srcCalldatas,
            hashDescription(srcDescription)
        );
    }

    // Scenario: A cross-chain proposal is sent from the hub chain to a satellite
    // chain. This test verifies that the proposal is automatically queued upon
    // receipt, with proper events emitted and state transitions occurring.
    function test_CrossChainProposalAutomaticallyQueued() public {
        // Setup initial state
        vm.deal(address(governorA), 100 ether); // For cross-chain fees

        // Setup voting power for timelockA (like in test_CrossChainGovernanceFullCycle)
        vm.startPrank(address(timelockA));
        aSummerToken.delegate(address(timelockA));
        vm.stopPrank();

        advanceTimeAndBlock();

        // Create and process proposal
        (
            address[] memory srcTargets,
            uint256[] memory srcValues,
            bytes[] memory srcCalldatas,
            string memory srcDescription,
            uint256 expectedDstProposalId,
            address[] memory dstTargets,
            uint256[] memory dstValues,
            bytes[] memory dstCalldatas,
            bytes32 dstDescriptionHash
        ) = _createCrossChainProposal(bEid, governorA);

        useNetworkA();

        // Create and vote on proposal
        vm.startPrank(address(timelockA));
        uint256 proposalId = governorA.propose(
            srcTargets,
            srcValues,
            srcCalldatas,
            srcDescription
        );
        vm.stopPrank();

        advanceTimeForVotingDelay();

        vm.startPrank(address(timelockA));
        governorA.castVote(proposalId, 1);
        vm.stopPrank();

        advanceTimeForVotingPeriod();

        // Queue and execute on chain A
        governorA.queue(
            srcTargets,
            srcValues,
            srcCalldatas,
            hashDescription(srcDescription)
        );

        advanceTimeForTimelockMinDelay();

        // Start recording logs for verification
        vm.recordLogs();

        governorA.execute(
            srcTargets,
            srcValues,
            srcCalldatas,
            hashDescription(srcDescription)
        );

        // Switch to chain B and verify
        useNetworkB();

        // Verify cross-chain message (like in test_CrossChainGovernanceFullCycle)
        verifyPackets(bEid, addressToBytes32(address(governorB)));

        // Get the logs and verify events
        (
            bool foundReceivedEvent,
            bool foundQueuedEvent,

        ) = _verifyProposalEvents(expectedDstProposalId);

        assertTrue(
            foundReceivedEvent,
            "Missing ProposalReceivedCrossChain event"
        );
        assertTrue(foundQueuedEvent, "Missing ProposalQueued event");

        // Verify proposal is queued on chain B
        bytes32 salt = bytes20(address(governorB)) ^ dstDescriptionHash;
        bytes32 timelockId = timelockB.hashOperationBatch(
            dstTargets,
            dstValues,
            dstCalldatas,
            0, // predecessor
            salt
        );
        assertTrue(
            timelockB.isOperationPending(timelockId),
            "Operation should be pending in timelock"
        );
    }

    function test_AllowInitializePath() public view {
        Origin memory origin = Origin({
            srcEid: aEid,
            sender: addressToBytes32(address(governorA)),
            nonce: 0
        });
        assertTrue(
            governorB.allowInitializePath(origin),
            "Should allow initialize path from peer"
        );

        // Test with non-peer
        Origin memory invalidOrigin = Origin({
            srcEid: 999,
            sender: addressToBytes32(address(0x1)),
            nonce: 0
        });
        assertFalse(
            governorB.allowInitializePath(invalidOrigin),
            "Should not allow initialize path from non-peer"
        );
    }

    function test_LzEndpoint() public view {
        assertEq(
            address(governorA.endpoint()),
            address(lzEndpointA),
            "Incorrect endpoint for governor A"
        );
        assertEq(
            address(governorB.endpoint()),
            address(lzEndpointB),
            "Incorrect endpoint for governor B"
        );
    }

    function test_Peers() public view {
        // Check peer configuration for governor A
        bytes32 peerB = governorA.peers(bEid);
        assertEq(
            peerB,
            addressToBytes32(address(governorB)),
            "Incorrect peer B address for governor A"
        );

        // Check peer configuration for governor B
        bytes32 peerA = governorB.peers(aEid);
        assertEq(
            peerA,
            addressToBytes32(address(governorA)),
            "Incorrect peer A address for governor B"
        );
    }

    function test_LzReceive() public {
        // Switch to chain B for the test
        vm.chainId(31338);

        // Create proposal parameters
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams(address(bSummerToken));
        bytes32 descriptionHash = hashDescription(description);

        // Calculate proposal ID that will be received
        uint256 proposalId = governorB.hashProposal(
            targets,
            values,
            calldatas,
            descriptionHash
        );

        // Encode the cross-chain message payload
        bytes memory message = abi.encode(
            proposalId,
            targets,
            values,
            calldatas,
            descriptionHash
        );

        // Setup origin for the message
        Origin memory origin = Origin({
            srcEid: aEid,
            sender: addressToBytes32(address(governorA)),
            nonce: 0
        });

        // Make sure peers are properly set before testing
        vm.prank(address(timelockA));
        governorA.setPeer(bEid, addressToBytes32(address(governorB)));

        vm.prank(address(timelockB));
        governorB.setPeer(aEid, addressToBytes32(address(governorA)));

        // Fund governorB for any operations
        vm.deal(address(governorB), 1 ether);

        // Execute the receive as the LZ endpoint
        vm.prank(address(lzEndpointB));
        governorB.lzReceive(
            origin,
            bytes32(0),
            message,
            address(0),
            "" // No extra data needed
        );

        // Verify the proposal was queued in the timelock
        bytes32 salt = bytes20(address(governorB)) ^ descriptionHash;
        bytes32 timelockId = timelockB.hashOperationBatch(
            targets,
            values,
            calldatas,
            0, // predecessor
            salt
        );
        assertTrue(
            timelockB.isOperationPending(timelockId),
            "Operation should be pending in timelock B"
        );
    }

    function test_SendProposalToTargetChain() public {
        // Setup proposal parameters
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams(address(bSummerToken));

        bytes32 descriptionHash = keccak256(bytes(description));

        // Create proper options using OptionsBuilder like in test_CrossChainGovernanceFullCycle
        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(200000, 0); // Using same gas values as other tests

        vm.deal(address(governorA), 100 ether); // Ensure enough ETH for fees

        // Test sending proposal
        governorA.exposedSendProposalToTargetChain(
            bEid,
            targets,
            values,
            calldatas,
            descriptionHash,
            options
        );
    }

    function _createCrossChainProposal(
        uint32 dstEid,
        SummerGovernor srcGovernor
    )
        internal
        view
        returns (
            address[] memory,
            uint256[] memory,
            bytes[] memory,
            string memory,
            uint256,
            address[] memory,
            uint256[] memory,
            bytes[] memory,
            bytes32
        )
    {
        (
            address[] memory dstTargets,
            uint256[] memory dstValues,
            bytes[] memory dstCalldatas,
            string memory dstDescription
        ) = createProposalParams(address(bSummerToken));

        bytes[] memory srcCalldatas = new bytes[](1);

        string memory srcDescription = string(
            abi.encodePacked("Cross-chain proposal: ", dstDescription)
        );
        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(200000, 0);

        srcCalldatas[0] = abi.encodeWithSelector(
            SummerGovernor.sendProposalToTargetChain.selector,
            dstEid,
            dstTargets,
            dstValues,
            dstCalldatas,
            hashDescription(dstDescription),
            options
        );

        address[] memory srcTargets = new address[](1);
        srcTargets[0] = address(srcGovernor);

        uint256[] memory srcValues = new uint256[](1);
        srcValues[0] = 0;

        uint256 dstProposalId = srcGovernor.hashProposal(
            dstTargets,
            dstValues,
            dstCalldatas,
            hashDescription(dstDescription)
        );

        console.log(
            "Description Hash:",
            uint256(hashDescription(dstDescription))
        );
        console.log("Expected Proposal ID:", dstProposalId);

        console.log("Target count:", dstTargets.length);
        for (uint i = 0; i < dstTargets.length; i++) {
            console.log("Target", i, ":", dstTargets[i]);
            console.log("Value", i, ":", dstValues[i]);
            console.log("Calldata", i, ":", _toHexString(dstCalldatas[i]));
        }

        return (
            srcTargets,
            srcValues,
            srcCalldatas,
            srcDescription,
            dstProposalId,
            dstTargets,
            dstValues,
            dstCalldatas,
            hashDescription(dstDescription)
        );
    }

    function _processProposalThroughVoting(
        address proposer,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) internal returns (uint256 proposalId) {
        vm.prank(proposer);
        proposalId = governorA.propose(targets, values, calldatas, description);

        advanceTimeForVotingDelay();
        vm.prank(proposer);
        governorA.castVote(proposalId, 1);
        advanceTimeForVotingPeriod();

        governorA.queue(
            targets,
            values,
            calldatas,
            hashDescription(description)
        );
        advanceTimeForTimelockMinDelay();
    }

    function _verifyProposalEvents(
        uint256 expectedProposalId
    )
        internal
        returns (
            bool foundReceivedEvent,
            bool foundQueuedEvent,
            uint48 queuedEta
        )
    {
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 receivedEventSig = keccak256(
            "ProposalReceivedCrossChain(uint256,uint32)"
        );
        bytes32 queuedEventSig = keccak256("ProposalQueued(uint256,uint256)");

        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics.length == 0) continue;

            bytes32 topic0 = entries[i].topics[0];

            if (topic0 == receivedEventSig) {
                foundReceivedEvent = true;
                assertEq(
                    uint256(entries[i].topics[1]),
                    expectedProposalId,
                    "Incorrect proposalId"
                );
                console.log("Found ProposalReceivedCrossChain event");
            }

            if (topic0 == queuedEventSig) {
                // For ProposalQueued, the data is in the event data rather than topics
                (uint256 proposalId, uint256 eta) = abi.decode(
                    entries[i].data,
                    (uint256, uint256)
                );
                if (proposalId != expectedProposalId) {
                    continue;
                }
                foundQueuedEvent = true;
                queuedEta = uint48(eta);
                assertGt(queuedEta, block.timestamp, "Invalid ETA");
                console.log("Found ProposalQueued event with ETA:", queuedEta);
            }
        }

        assertTrue(
            foundReceivedEvent,
            "Missing ProposalReceivedCrossChain event"
        );
        assertTrue(foundQueuedEvent, "Missing ProposalQueued event");
    }

    function _toHexString(
        bytes memory data
    ) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < data.length; i++) {
            str[2 + i * 2] = alphabet[uint8(data[i] >> 4)];
            str[2 + i * 2 + 1] = alphabet[uint8(data[i] & 0x0f)];
        }
        return string(str);
    }
}
