// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Origin, SummerGovernor} from "../src/contracts/SummerGovernor.sol";
import {ISummerGovernorErrors} from "../src/errors/ISummerGovernorErrors.sol";
import {ISummerGovernor} from "../src/interfaces/ISummerGovernor.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {IOAppSetPeer} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {SummerGovernorTestBase, ExposedSummerGovernor} from "./SummerGovernorTestBase.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {Strings} from "@summerfi/dependencies/openzeppelin-contracts/contracts/utils/Strings.sol";

contract SummerGovernorCrossChainTest is SummerGovernorTestBase {
    using OptionsBuilder for bytes;
    using Strings for bytes;

    function setUp() public override {
        initializeTokenTests();
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");

        // Set up Governor A (Hub Chain)
        SummerGovernor.GovernorParams memory paramsA = ISummerGovernor
            .GovernorParams({
                token: aSummerToken,
                timelock: timelockA,
                votingDelay: VOTING_DELAY,
                votingPeriod: VOTING_PERIOD,
                proposalThreshold: PROPOSAL_THRESHOLD,
                quorumFraction: QUORUM_FRACTION,
                initialWhitelistGuardian: whitelistGuardian,
                endpoint: lzEndpointA,
                proposalChainId: 31337,
                peerEndpointIds: new uint32[](0),
                peerAddresses: new address[](0)
            });

        // Set up Governor B (Satellite Chain)
        SummerGovernor.GovernorParams memory paramsB = ISummerGovernor
            .GovernorParams({
                token: bSummerToken,
                timelock: timelockB,
                votingDelay: VOTING_DELAY,
                votingPeriod: VOTING_PERIOD,
                proposalThreshold: PROPOSAL_THRESHOLD,
                quorumFraction: QUORUM_FRACTION,
                initialWhitelistGuardian: whitelistGuardian,
                endpoint: lzEndpointB,
                proposalChainId: 31337,
                peerEndpointIds: new uint32[](0),
                peerAddresses: new address[](0)
            });

        governorA = new ExposedSummerGovernor(paramsA);
        governorB = new ExposedSummerGovernor(paramsB);

        // Set up roles and permissions
        vm.startPrank(address(timelockA));
        accessManagerA.grantDecayControllerRole(address(governorA));
        timelockA.grantRole(timelockA.PROPOSER_ROLE(), address(governorA));
        timelockA.grantRole(timelockA.CANCELLER_ROLE(), address(governorA));
        vm.stopPrank();

        vm.startPrank(address(timelockB));
        accessManagerB.grantDecayControllerRole(address(governorB));
        timelockB.grantRole(timelockB.PROPOSER_ROLE(), address(governorB));
        // So, we can cancel via cross-chain proposals
        timelockB.grantRole(timelockB.CANCELLER_ROLE(), address(timelockB));
        vm.stopPrank();

        // Wire the governors
        vm.prank(address(timelockA));
        IOAppSetPeer(address(governorA)).setPeer(
            bEid,
            addressToBytes32(address(governorB))
        );

        vm.prank(address(timelockB));
        IOAppSetPeer(address(governorB)).setPeer(
            aEid,
            addressToBytes32(address(governorA))
        );

        vm.prank(owner);
        enableTransfers();
        changeTokensOwnership(address(timelockA), address(timelockB));
    }

    // Scenario: A proposal is created on the hub chain, voted on, and executed.
    // The execution triggers a cross-chain message to a satellite chain where
    // the proposal is automatically queued and then executed.
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

        // Verify cross-chain message
        verifyPackets(bEid, addressToBytes32(address(governorB)));

        // Get the logs and verify events
        (
            bool foundReceivedEvent,
            bool foundQueuedEvent,
            uint256 queuedEta
        ) = _verifyProposalEvents(dstProposalId, aEid);

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
            0, // predecessor (always 0 in our case)
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

    // Scenario: An attempt is made to execute a cross-chain proposal without
    // providing sufficient fees for the LayerZero message. This should fail,
    // preventing the proposal from being sent to the target chain.
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

    // Scenario: The governor contract attempts to send a cross-chain message
    // but lacks the necessary native tokens to cover the fees. This should
    // result in a failure, highlighting the importance of proper fee management.
    function test_InsufficientNativeFeeForCrossChainMessage() public {
        // Prepare cross-chain proposal parameters
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

        // Ensure governorA has insufficient ETH
        vm.deal(address(governorA), 1 wei);

        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(200000, 0);

        // Attempt to send proposal
        vm.expectRevert(abi.encodeWithSignature("NotEnoughNative(uint256)", 1));
        governorA.exposedSendProposalToTargetChain(
            bEid,
            srcTargets,
            srcValues,
            srcCalldatas,
            keccak256(bytes(srcDescription)),
            options
        );
    }

    // Scenario: An unauthorized address (non-governance) attempts to send a
    // cross-chain proposal. This should be rejected to maintain the security
    // of the cross-chain governance process.
    function test_NonGovernanceSendCrossChainProposal() public {
        // Prepare cross-chain proposal parameters
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

        // Attempt to send proposal as non-governance address
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSignature(
                "GovernorOnlyExecutor(address)",
                address(alice)
            )
        );
        governorA.sendProposalToTargetChain(
            bEid,
            srcTargets,
            srcValues,
            srcCalldatas,
            keccak256(bytes(srcDescription)),
            ""
        );
    }

    // Scenario: An attempt is made to create a proposal on a chain that is not
    // designated as the hub chain. This should be prevented to maintain the
    // intended governance structure across the multi-chain system.
    function test_ProposalOnlyAllowedOnHubChain() public {
        // Store original chain ID
        uint256 originalChainId = block.chainid;

        // Switch to a non-hub chain
        vm.chainId(999);

        // Setup proposal parameters
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams(address(bSummerToken));

        // Ensure Alice has enough tokens
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.quorum(block.timestamp - 1));
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);

        // Get the proposalChainId from the governor contract
        uint256 expectedProposalChainId = governorA.proposalChainId();

        // Attempt to propose on wrong chain
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSignature(
                "SummerGovernorInvalidChain(uint256,uint256)",
                999,
                expectedProposalChainId
            )
        );
        governorA.propose(targets, values, calldatas, description);

        // Reset chain ID
        vm.chainId(originalChainId);
    }

    // Scenario: A cross-chain message fails to be delivered due to a temporary
    // issue. This test ensures that the system allows for retrying the failed
    // message, maintaining the robustness of the cross-chain governance.
    function test_RetryFailedCrossChainMessage() public {
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
            ,
            ,
            ,

        ) = _createCrossChainProposal(bEid, governorA);

        // Submit and process proposal on chain A
        vm.prank(alice);
        uint256 proposalIdA = governorA.propose(
            srcTargets,
            srcValues,
            srcCalldatas,
            srcDescription
        );

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

        advanceTimeForTimelockMinDelay();

        // Mock LZ endpoint to simulate failed message
        vm.mockCall(
            address(lzEndpointA),
            abi.encodeWithSelector(ILayerZeroEndpointV2.send.selector),
            abi.encode(bytes("Failed"))
        );

        // First attempt should fail
        vm.expectRevert("Failed");
        governorA.execute(
            srcTargets,
            srcValues,
            srcCalldatas,
            hashDescription(srcDescription)
        );

        // Remove mock and retry
        vm.clearMockedCalls();

        // Second attempt should succeed
        governorA.execute(
            srcTargets,
            srcValues,
            srcCalldatas,
            hashDescription(srcDescription)
        );

        // Verify successful execution
        verifyPackets(bEid, addressToBytes32(address(governorB)));
    }

    // Scenario: During the initialization of a new governor, invalid peer
    // configurations are provided. This test ensures that the contract
    // correctly validates and rejects mismatched or incorrect peer setups.
    function test_PeerConfigurationValidation() public {
        // Create invalid peer configurations
        uint32[] memory invalidEndpointIds = new uint32[](2);
        invalidEndpointIds[0] = 1;
        invalidEndpointIds[1] = 2;

        address[] memory invalidAddresses = new address[](1);
        invalidAddresses[0] = address(0x1);

        // Create new governor with mismatched peer arrays
        SummerGovernor.GovernorParams memory invalidParams = ISummerGovernor
            .GovernorParams({
                token: aSummerToken,
                timelock: timelockA,
                votingDelay: VOTING_DELAY,
                votingPeriod: VOTING_PERIOD,
                proposalThreshold: PROPOSAL_THRESHOLD,
                quorumFraction: QUORUM_FRACTION,
                initialWhitelistGuardian: whitelistGuardian,
                endpoint: lzEndpointA,
                proposalChainId: 31337,
                peerEndpointIds: invalidEndpointIds,
                peerAddresses: invalidAddresses
            });

        vm.expectRevert(
            abi.encodeWithSignature("SummerGovernorInvalidPeerArrays()")
        );
        new ExposedSummerGovernor(invalidParams);
    }

    // Scenario: A cross-chain proposal is created and then cancelled by the
    // whitelist guardian before it can be executed. This tests the cancellation
    // mechanism and its effects on both the source and target chains.
    function test_CrossChainProposalCancellation() public {
        vm.recordLogs();

        // Setup: Give Alice enough tokens and ETH
        vm.deal(address(governorA), 100 ether);
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.quorum(block.timestamp - 1));
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        // Create and submit cross-chain proposal
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

        // Submit and process proposal on chain A
        vm.prank(alice);
        uint256 proposalIdA = governorA.propose(
            srcTargets,
            srcValues,
            srcCalldatas,
            srcDescription
        );

        // Complete governance process on chain A
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

        advanceTimeForTimelockMinDelay();

        // Execute on chain A which sends to chain B
        governorA.execute(
            srcTargets,
            srcValues,
            srcCalldatas,
            hashDescription(srcDescription)
        );

        // Verify cross-chain message delivery
        verifyPackets(bEid, addressToBytes32(address(governorB)));

        // Verify proposal was received and queued on chain B
        (
            bool foundReceivedEvent,
            bool foundQueuedEvent,
            uint256 queuedEta
        ) = _verifyProposalEvents(dstProposalId, aEid);

        assertTrue(foundReceivedEvent, "Missing received event on chain B");
        assertTrue(foundQueuedEvent, "Missing queued event on chain B");

        // Create a cancellation proposal on chain A that will send a cross-chain message to chain B
        bytes[] memory cancelCalldatas = new bytes[](1);

        // Create the cross-chain message payload for cancellation
        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(200000, 0);

        // THINK WE NEED TO UPDATE THIS
        // The actual cancellation calldata that will be executed on chain B
        bytes[] memory dstCancelCalldatas = new bytes[](1);
        dstCancelCalldatas[0] = abi.encodeWithSelector(
            timelockB.cancel.selector,
            dstTargets,
            dstValues,
            dstCalldatas,
            bytes32(0), // predecessor
            bytes20(address(governorB)) ^ dstDescriptionHash // salt
        );

        address[] memory dstCancelTargets = new address[](1);
        dstCancelTargets[0] = address(timelockB);

        uint256[] memory dstCancelValues = new uint256[](1);

        // Wrap the cancellation in a cross-chain message
        cancelCalldatas[0] = abi.encodeWithSelector(
            SummerGovernor.sendProposalToTargetChain.selector,
            bEid,
            dstCancelTargets,
            dstCancelValues,
            dstCancelCalldatas,
            keccak256(bytes("Cancel proposal on chain B")),
            options
        );

        address[] memory cancelTargets = new address[](1);
        cancelTargets[0] = address(governorA); // Target the local governor to send cross-chain

        uint256[] memory cancelValues = new uint256[](1);
        string memory cancelDescription = "Send cancellation to chain B";

        // Submit and process cancellation proposal
        vm.prank(alice);
        uint256 cancelProposalId = governorA.propose(
            cancelTargets,
            cancelValues,
            cancelCalldatas,
            cancelDescription
        );

        // Complete governance process on chain A
        advanceTimeForVotingDelay();
        vm.prank(alice);
        governorA.castVote(cancelProposalId, 1);
        advanceTimeForVotingPeriod();

        governorA.queue(
            cancelTargets,
            cancelValues,
            cancelCalldatas,
            hashDescription(cancelDescription)
        );

        advanceTimeForTimelockMinDelay();

        // Execute cancellation proposal on chain A which sends to chain B
        governorA.execute(
            cancelTargets,
            cancelValues,
            cancelCalldatas,
            hashDescription(cancelDescription)
        );

        // Verify cross-chain message delivery for cancellation
        verifyPackets(bEid, addressToBytes32(address(governorB)));

        // Need to wait for timelock delay before executing
        advanceTimeForTimelockMinDelay();

        // Now execute on chain B's timelock
        bytes32 salt = bytes20(address(governorB)) ^ dstDescriptionHash;
        bytes32 timelockId = timelockB.hashOperationBatch(
            dstTargets,
            dstValues,
            dstCalldatas,
            bytes32(0), // predecessor
            salt
        );

        advanceTimeForTimelockMinDelay();

        // Execute the cancellation proposal instead of the original proposal
        timelockB.executeBatch(
            dstCancelTargets,
            dstCancelValues,
            dstCancelCalldatas,
            bytes32(0), // predecessor
            bytes20(address(governorB)) ^
                keccak256(bytes("Cancel proposal on chain B")) // salt for cancellation
        );

        // Verify proposal is cancelled on chain B
        assertEq(
            uint256(governorB.state(dstProposalId)),
            uint256(IGovernor.ProposalState.Canceled)
        );
    }

    // Scenario: An attempt is made to send a cross-chain message with
    // insufficient gas limits. This test ensures that the system properly
    // handles and rejects under-resourced cross-chain communications.
    function test_CrossChainMessageGasLimits() public {
        // Setup proposal parameters
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

        // Create options with very low gas limit
        bytes memory lowGasOptions = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(100, 0);

        // Attempt to send with insufficient gas
        vm.expectRevert();
        governorA.sendProposalToTargetChain(
            bEid,
            srcTargets,
            srcValues,
            srcCalldatas,
            hashDescription(srcDescription),
            lowGasOptions
        );
    }

    // Scenario: A proposal goes through the entire governance process across
    // multiple chains. This test verifies that the proposal states remain
    // consistent and correctly transition on both the source and target chains.
    function test_ProposalConsistencyAcrossChains() public {
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

        // Submit and process proposal on chain A
        vm.prank(alice);
        uint256 proposalIdA = governorA.propose(
            srcTargets,
            srcValues,
            srcCalldatas,
            srcDescription
        );

        // Complete governance process on chain A
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

        advanceTimeForTimelockMinDelay();

        // Execute on chain A which sends to chain B
        governorA.execute(
            srcTargets,
            srcValues,
            srcCalldatas,
            hashDescription(srcDescription)
        );

        // Verify cross-chain message
        verifyPackets(bEid, addressToBytes32(address(governorB)));

        // Verify proposal states are consistent
        assertEq(
            uint256(governorA.state(proposalIdA)),
            uint256(IGovernor.ProposalState.Executed),
            "Inconsistent state on chain A"
        );

        // Verify proposal was received and queued on chain B
        (
            bool foundReceivedEvent,
            bool foundQueuedEvent,
            uint256 queuedEta
        ) = _verifyProposalEvents(dstProposalId, aEid);

        assertTrue(foundReceivedEvent, "Missing received event on chain B");
        assertTrue(foundQueuedEvent, "Missing queued event on chain B");

        // Verify proposal is queued on chain B
        bytes32 salt = bytes20(address(governorB)) ^ dstDescriptionHash;
        bytes32 timelockId = timelockB.hashOperationBatch(
            dstTargets,
            dstValues,
            dstCalldatas,
            0, // predecessor (always 0 in our case)
            salt
        );
        assertTrue(
            timelockB.isOperationPending(timelockId),
            "Operation should be pending in timelock"
        );

        // Execute on chain B after timelock delay
        vm.warp(queuedEta + 1);
        governorB.execute(
            dstTargets,
            dstValues,
            dstCalldatas,
            dstDescriptionHash
        );

        assertTrue(
            timelockB.isOperationDone(timelockId),
            "Operation should be done in timelock"
        );

        // Verify final states match
        assertEq(
            uint256(governorB.state(dstProposalId)),
            uint256(IGovernor.ProposalState.Executed),
            "Inconsistent state on chain B"
        );
    }

    // Scenario: A cross-chain proposal is sent from the hub chain to a satellite
    // chain. This test verifies that the proposal is automatically queued upon
    // receipt, with proper events emitted and state transitions occurring.
    function test_CrossChainProposalAutomaticallyQueued() public {
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

        // Verify cross-chain message
        verifyPackets(bEid, addressToBytes32(address(governorB)));

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
            "Operation should be pending in timelock B"
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
            console.log("Calldata", i, ":", toHexString(dstCalldatas[i]));
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

    function _setupProposerWithTokens(address proposer) internal {
        vm.deal(address(governorA), 100 ether);
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(proposer, governorA.quorum(block.timestamp - 1));
        vm.stopPrank();

        vm.prank(proposer);
        aSummerToken.delegate(proposer);
        advanceTimeAndBlock();
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
        uint256 expectedProposalId,
        uint32 expectedSrcEid
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

    // Add these helper functions to match OZ's calculations
    function timelockSalt(
        address governor,
        bytes32 descriptionHash
    ) internal pure returns (bytes32) {
        return bytes20(governor) ^ descriptionHash;
    }

    function hashOperationBatch(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 salt
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    targets,
                    values,
                    calldatas,
                    0, // predecessor (always 0 in our case)
                    salt
                )
            );
    }

    // Helper function to verify timelock operation
    function _verifyTimelockOperation(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal view returns (bytes32 timelockId, uint256 eta) {
        bytes32 salt = bytes20(address(governorB)) ^ descriptionHash;
        timelockId = timelockB.hashOperationBatch(
            targets,
            values,
            calldatas,
            0, // predecessor (always 0 in our case)
            salt
        );

        // Verify operation is pending
        require(
            timelockB.isOperationPending(timelockId),
            "Operation not pending in timelock"
        );

        // Get scheduled timestamp
        eta = block.timestamp + timelockB.getMinDelay();

        return (timelockId, eta);
    }

    // Add this helper function
    function toHexString(
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
