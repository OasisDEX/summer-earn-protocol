// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Origin, SummerGovernor} from "../src/contracts/SummerGovernor.sol";
import {ISummerGovernorErrors} from "../src/errors/ISummerGovernorErrors.sol";

import {ISummerGovernor} from "../src/interfaces/ISummerGovernor.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

import {SummerToken} from "../src/contracts/SummerToken.sol";
import {IOAppSetPeer, TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {IVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {ERC20, ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

import {ISummerToken} from "../src/interfaces/ISummerToken.sol";
import {SummerVestingWallet} from "../src/contracts/SummerVestingWallet.sol";
import {ISummerVestingWallet} from "../src/interfaces/ISummerVestingWallet.sol";
import {SummerTokenTestBase} from "./SummerTokenTestBase.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

contract ExposedSummerGovernor is SummerGovernor {
    constructor(GovernorParams memory params) SummerGovernor(params) {}

    function exposedLzReceive(
        Origin calldata _origin,
        bytes calldata payload,
        bytes calldata extraData
    ) public {
        _lzReceive(_origin, bytes32(0), payload, address(0), extraData);
    }

    function setTrustedRemote(
        uint32 _chainId,
        address _trustedRemote
    ) public override {
        trustedRemotes[_chainId] = _trustedRemote;
    }

    function exposedSendProposalToTargetChain(
        uint32 _dstEid,
        address[] memory _dstTargets,
        uint256[] memory _dstValues,
        bytes[] memory _dstCalldatas,
        bytes32 _dstDescriptionHash,
        bytes calldata _options
    ) public {
        _sendProposalToTargetChain(
            _dstEid,
            _dstTargets,
            _dstValues,
            _dstCalldatas,
            _dstDescriptionHash,
            _options
        );
    }

    function forceUpdateDecay(address account) public updateDecay(account) {}
}

/*
 * @title SummerGovernorTest
 * @dev Test contract for SummerGovernor functionality.
 */
contract SummerGovernorTest is
    Test,
    ISummerGovernorErrors,
    SummerTokenTestBase
{
    using OptionsBuilder for bytes;

    ExposedSummerGovernor public governorA;
    ExposedSummerGovernor public governorB;

    address public alice = address(0x111);
    address public bob = address(0x112);
    address public charlie = address(0x113);
    address public david = address(0x114);
    address public whitelistGuardian = address(0x115);

    uint48 public constant VOTING_DELAY = 1 days;
    uint32 public constant VOTING_PERIOD = 1 weeks;
    uint256 public constant PROPOSAL_THRESHOLD = 100000e18;
    uint256 public constant QUORUM_FRACTION = 4;

    /*
     * @dev Sets up the test environment.
     */
    function setUp() public override {
        initializeTokenTests();
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
        vm.label(david, "David");

        vm.label(address(aSummerToken), "chain a token");
        vm.label(address(bSummerToken), "chain b token");

        SummerGovernor.GovernorParams memory paramsA = ISummerGovernor
            .GovernorParams({
                token: IVotes(address(aSummerToken)),
                timelock: timelockA,
                votingDelay: VOTING_DELAY,
                votingPeriod: VOTING_PERIOD,
                proposalThreshold: PROPOSAL_THRESHOLD,
                quorumFraction: QUORUM_FRACTION,
                initialWhitelistGuardian: whitelistGuardian,
                endpoint: lzEndpointA,
                proposalChainId: 31337
            });
        SummerGovernor.GovernorParams memory paramsB = ISummerGovernor
            .GovernorParams({
                token: IVotes(address(bSummerToken)),
                timelock: timelockB,
                votingDelay: VOTING_DELAY,
                votingPeriod: VOTING_PERIOD,
                proposalThreshold: PROPOSAL_THRESHOLD,
                quorumFraction: QUORUM_FRACTION,
                initialWhitelistGuardian: whitelistGuardian,
                endpoint: lzEndpointB,
                proposalChainId: 31337
            });
        governorA = new ExposedSummerGovernor(paramsA);
        governorB = new ExposedSummerGovernor(paramsB);

        vm.prank(address(timelockA));
        accessManagerA.grantDecayControllerRole(address(governorA));

        vm.prank(address(timelockB));
        accessManagerB.grantDecayControllerRole(address(governorB));

        governorA.setTrustedRemote(bEid, address(governorB));
        governorB.setTrustedRemote(aEid, address(governorA));

        vm.label(address(governorA), "SummerGovernor");
        vm.label(address(governorB), "SummerGovernor");

        vm.prank(owner);
        enableTransfers();
        changeTokensOwnership(address(timelockA), address(timelockB));

        timelockA.grantRole(timelockA.PROPOSER_ROLE(), address(governorA));
        timelockA.grantRole(timelockA.CANCELLER_ROLE(), address(governorA));
        timelockB.grantRole(timelockB.PROPOSER_ROLE(), address(governorB));
        timelockB.grantRole(timelockB.CANCELLER_ROLE(), address(governorB));

        // Wire the governors (if needed)
        address[] memory governors = new address[](2);
        governors[0] = address(governorA);
        governors[1] = address(governorB);

        IOAppSetPeer aOApp = IOAppSetPeer(address(governorA));
        IOAppSetPeer bOApp = IOAppSetPeer(address(governorB));

        // Connect governorA to governorB
        // vm.prank(address(governorA));
        uint32 bEid_ = (bOApp.endpoint()).eid();
        vm.prank(address(timelockA));
        aOApp.setPeer(bEid_, addressToBytes32(address(bOApp)));

        // Connect governorB to governorA
        // vm.prank(address(governorB));
        uint32 aEid_ = (aOApp.endpoint()).eid();
        vm.prank(address(timelockB));
        bOApp.setPeer(aEid_, addressToBytes32(address(aOApp)));
    }
    // ===============================================
    // Cross-Chain Messaging Tests
    // ===============================================

    /*
     * @dev Tests cross-chain proposal submission.
     * Ensures a proposal can be submitted from one chain and received on another.
     */
    function test_CrossChainExecutionOnSourceChain() public {
        // Ensure source governorA have enough ETH for messaging costs
        vm.deal(address(governorA), 100 ether);
        vm.prank(address(timelockB));
        bSummerToken.mint(address(governorB), 100 ether);

        // Prepare cross-chain proposal parameters
        (
            address[] memory srcTargets,
            uint256[] memory srcValues,
            bytes[] memory srcCalldatas,
            string memory srcDescription,
            uint256 dstProposalId
        ) = createCrossChainProposal(bEid, governorA);

        // Ensure Alice has enough tokens on chain A
        deal(address(aSummerToken), alice, governorA.proposalThreshold() * 2);
        vm.prank(alice);
        aSummerToken.delegate(alice);

        advanceTimeAndBlock();

        // Submit proposal on chain A
        vm.prank(alice);
        uint256 proposalIdA = governorA.propose(
            srcTargets,
            srcValues,
            srcCalldatas,
            srcDescription
        );

        advanceTimeForVotingDelay();

        // Cast vote
        vm.prank(alice);
        governorA.castVote(proposalIdA, 1); // Vote in favor

        advanceTimeForVotingPeriod();

        governorA.queue(
            srcTargets,
            srcValues,
            srcCalldatas,
            hashDescription(srcDescription)
        );

        advanceTimeForTimelockMinDelay();

        vm.expectEmit(true, true, true, true);
        emit ISummerGovernor.ProposalSentCrossChain(dstProposalId, bEid);
        governorA.execute(
            srcTargets,
            srcValues,
            srcCalldatas,
            hashDescription(srcDescription)
        );

        verifyPackets(bEid, addressToBytes32(address(governorB)));
    }

    function test_ReceiveProposalAndExecuteOnTargetChain() public {
        // Ensure source governorA have enough ETH for messaging costs
        vm.deal(address(governorA), 100 ether);
        vm.prank(address(timelockB));
        bSummerToken.mint(address(governorB), 100 ether);

        // Prepare cross-chainproposal parameters
        (
            address[] memory srcTargets,
            uint256[] memory srcValues,
            bytes[] memory srcCalldatas,
            string memory srcDescription,
            uint256 dstProposalId
        ) = createCrossChainProposal(bEid, governorA);

        // Ensure Alice has enough tokens on chain A
        deal(address(aSummerToken), alice, governorA.proposalThreshold() * 2); // Increased token amount
        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        // Submit proposal on chain A
        vm.prank(alice);
        uint256 proposalIdA = governorA.propose(
            srcTargets,
            srcValues,
            srcCalldatas,
            srcDescription
        );

        advanceTimeForVotingDelay();

        // Cast vote
        vm.prank(alice);
        governorA.castVote(proposalIdA, 1); // Vote in favor

        advanceTimeForVotingPeriod();

        governorA.queue(
            srcTargets,
            srcValues,
            srcCalldatas,
            hashDescription(srcDescription)
        );

        advanceTimeForTimelockMinDelay();

        governorA.execute(
            srcTargets,
            srcValues,
            srcCalldatas,
            hashDescription(srcDescription)
        );

        vm.recordLogs();
        verifyPackets(bEid, addressToBytes32(address(governorB)));
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // Check for the ProposalSentCrossChain event
        bool foundEvent = false;
        for (uint256 i = 0; i < entries.length; i++) {
            // The first topic is the event signature
            if (
                entries[i].topics[0] ==
                keccak256("ProposalReceivedCrossChain(uint256,uint32)")
            ) {
                console.log("ProposalReceivedCrossChain event found");

                uint256 emittedDstProposalId = uint256(entries[i].topics[1]);
                uint32 emittedSrcEid = uint32(uint256(entries[i].topics[2]));
                // Decode the event data

                // Verify the event data
                assertEq(
                    emittedDstProposalId,
                    dstProposalId,
                    "Incorrect proposalId emitted"
                );
                assertEq(emittedSrcEid, aEid, "Incorrect srcEid emitted");

                foundEvent = true;
                break;
            }
        }

        assertTrue(foundEvent, "ProposalSentCrossChain event not found");
    }

    function test_ReceiveProposalFromUntrustedSource() public {
        // Setup: Prepare a cross-chain proposal
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description,
            uint256 proposalId
        ) = createCrossChainProposal(aEid, governorB);

        // Encode the proposal data
        bytes memory payload = abi.encode(
            proposalId,
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        // Create an Origin struct with an untrusted source
        Origin memory origin = Origin(
            aEid,
            bytes32(uint256(uint160(address(0x1234)))),
            0
        );

        // Attempt to receive the proposal
        vm.expectRevert(
            abi.encodeWithSignature(
                "SummerGovernorInvalidSender(address)",
                address(0x1234)
            )
        );
        governorB.exposedLzReceive(origin, payload, "");
    }

    function test_InsufficientNativeFeeForCrossChainMessage() public {
        // Prepare cross-chain proposal parameters
        (
            address[] memory srcTargets,
            uint256[] memory srcValues,
            bytes[] memory srcCalldatas,
            string memory srcDescription,

        ) = createCrossChainProposal(bEid, governorA);

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

    function test_NonGovernanceSendCrossChainProposal() public {
        // Prepare cross-chain proposal parameters
        (
            address[] memory srcTargets,
            uint256[] memory srcValues,
            bytes[] memory srcCalldatas,
            string memory srcDescription,

        ) = createCrossChainProposal(bEid, governorA);

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

    function createCrossChainProposal(
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
            uint256
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

        return (
            srcTargets,
            srcValues,
            srcCalldatas,
            srcDescription,
            dstProposalId
        );
    }

    /*
     * @dev Generates a unique message ID for cross-chain proposals.
     * @param dstChainId The destination chain ID.
     * @param srcAddress The source contract address.
     * @param proposalId The ID of the proposal.
     * @param targets The target addresses for the proposal.
     * @param values The values for the proposal.
     * @param calldatas The calldata for the proposal.
     * @param descriptionHash The description hash for the proposal.
     * @return A unique bytes32 message ID.
     */
    function _generateMessageId(
        uint256 dstChainId,
        address srcAddress,
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    dstChainId,
                    srcAddress,
                    proposalId,
                    targets,
                    values,
                    calldatas,
                    descriptionHash
                )
            );
    }

    // ===============================================
    // Source Chain Governance Tests
    // ===============================================

    /*
     * @dev Tests the initial setup of the governorA.
     * Verifies that the governorA's parameters are set correctly.
     */
    function test_InitialSetup() public {
        address lzEndpointA = address(endpoints[aEid]);

        SummerGovernor.GovernorParams memory params = ISummerGovernor
            .GovernorParams({
                token: IVotes(address(aSummerToken)),
                timelock: timelockA,
                votingDelay: VOTING_DELAY,
                votingPeriod: VOTING_PERIOD,
                proposalThreshold: PROPOSAL_THRESHOLD,
                quorumFraction: QUORUM_FRACTION,
                initialWhitelistGuardian: address(0),
                endpoint: lzEndpointA,
                proposalChainId: 31337
            });
        vm.expectRevert(
            abi.encodeWithSignature(
                "SummerGovernorInvalidWhitelistGuardian(address)",
                address(0)
            )
        );
        new SummerGovernor(params);
        params.initialWhitelistGuardian = whitelistGuardian;
        assertEq(governorA.name(), "SummerGovernor");
        assertEq(governorA.votingDelay(), VOTING_DELAY);
        assertEq(governorA.votingPeriod(), VOTING_PERIOD);
        assertEq(governorA.proposalThreshold(), PROPOSAL_THRESHOLD);
        assertEq(governorA.quorumNumerator(), QUORUM_FRACTION);
        assertEq(governorA.getWhitelistGuardian(), whitelistGuardian);
    }

    /*
     * @dev Tests the proposal creation process.
     * Ensures that a proposal can be created successfully.
     */
    function test_ProposalCreation() public {
        vm.startPrank(address(timelockA));
        aSummerToken.mint(address(alice), governorA.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);

        advanceTimeForVotingDelay();

        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        assertGt(proposalId, 0);
    }

    /*
     * @dev Tests the voting process on a proposal.
     * Verifies that votes are correctly cast and counted.
     */
    function test_Voting() public {
        vm.startPrank(address(timelockA));
        aSummerToken.mint(alice, governorA.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);

        advanceTimeAndBlock();

        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        advanceTimeForVotingDelay();

        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        (, uint256 forVotes, ) = governorA.proposalVotes(proposalId);
        assertEq(forVotes, governorA.proposalThreshold());
    }

    /*
     * @dev Tests the full proposal execution flow.
     * Covers proposal creation, voting, queueing, execution, and result verification.
     */
    function test_ProposalExecution() public {
        vm.startPrank(address(timelockA));
        aSummerToken.mint(address(timelockA), 100);
        aSummerToken.mint(alice, governorA.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);

        advanceTimeAndBlock();

        vm.prank(alice);
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams(address(aSummerToken));
        uint256 proposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        advanceTimeForVotingDelay();

        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        advanceTimeForVotingPeriod();

        governorA.queue(
            targets,
            values,
            calldatas,
            hashDescription(description)
        );

        advanceTimeForTimelockMinDelay();

        governorA.execute(
            targets,
            values,
            calldatas,
            hashDescription(description)
        );

        assertEq(aSummerToken.balanceOf(bob), 100);
    }

    /*
     * @dev Tests the whitelisting process through a governance proposal.
     * Verifies that an account can be whitelisted via a proposal.
     */
    function test_Whitelisting() public {
        address account = address(0x03);
        uint256 expiration = block.timestamp + 10 days;

        uint256 proposalThreshold = governorA.proposalThreshold();

        vm.startPrank(address(timelockA));
        aSummerToken.mint(alice, proposalThreshold);
        vm.stopPrank();

        vm.startPrank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();
        vm.stopPrank();

        address[] memory targets = new address[](1);
        targets[0] = address(governorA);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            SummerGovernor.setWhitelistAccountExpiration.selector,
            account,
            expiration
        );
        string memory description = "Whitelist account proposal";

        vm.prank(alice);
        uint256 proposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        uint256 votingDelay = governorA.votingDelay();
        advanceTimeForVotingDelay();

        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        advanceTimeForVotingPeriod();

        governorA.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        advanceTimeForTimelockMinDelay();

        governorA.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        bool isWhitelisted = governorA.isWhitelisted(account);
        uint256 actualExpiration = governorA.getWhitelistAccountExpiration(
            account
        );

        assertTrue(isWhitelisted, "Account should be whitelisted");
        assertEq(
            actualExpiration,
            expiration,
            "Expiration timestamp should match"
        );
    }

    /*
     * @dev Tests the proposal cancellation process.
     * Ensures that a proposal can be canceled by the whitelist guardian.
     */
    function test_ProposalCancellation() public {
        vm.startPrank(address(timelockA));
        aSummerToken.mint(alice, governorA.proposalThreshold() * 2);
        vm.stopPrank();

        vm.startPrank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        // Create proposal to set Bob as whitelist guardian
        address[] memory targets = new address[](1);
        targets[0] = address(governorA);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            SummerGovernor.setWhitelistGuardian.selector,
            bob
        );
        string memory description = "Set Bob as whitelist guardian";

        uint256 proposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        advanceTimeForVotingDelay();

        governorA.castVote(proposalId, 1);
        vm.stopPrank();

        // Try to cancel with non-guardian (should fail)
        vm.expectRevert(
            abi.encodeWithSignature(
                "SummerGovernorUnauthorizedCancellation(address,address,uint256,uint256)",
                bob,
                alice,
                governorA.proposalThreshold() * 2,
                governorA.proposalThreshold()
            )
        );
        vm.prank(bob);
        governorA.cancel(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        // Cancel with whitelist guardian (should succeed)
        vm.startPrank(whitelistGuardian);
        governorA.cancel(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        assertEq(
            uint256(governorA.state(proposalId)),
            uint256(IGovernor.ProposalState.Canceled),
            "Proposal should be canceled"
        );
        vm.stopPrank();
    }

    /*
     * @dev Tests that a proposal creation fails when the proposer is below threshold and not whitelisted.
     */
    function test_ProposalCreationBelowThresholdAndNotWhitelisted() public {
        // Ensure Charlie has some tokens, but below the proposal threshold
        uint256 belowThreshold = governorA.proposalThreshold() - 1;
        vm.startPrank(address(timelockA));
        aSummerToken.mint(charlie, belowThreshold);
        vm.stopPrank();

        vm.startPrank(charlie);
        aSummerToken.delegate(charlie);
        advanceTimeAndBlock();

        // Attempt to create a proposal
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams(address(aSummerToken));

        // Expect the transaction to revert with SummerGovernorProposerBelowThresholdAndNotWhitelisted error
        vm.expectRevert(
            abi.encodeWithSelector(
                SummerGovernorProposerBelowThresholdAndNotWhitelisted.selector,
                charlie,
                belowThreshold,
                governorA.proposalThreshold()
            )
        );
        governorA.propose(targets, values, calldatas, description);

        vm.stopPrank();
    }
    /*
     * @dev Tests the proposalNeedsQueuing function.
     */

    function test_ProposalNeedsQueuing() public {
        vm.startPrank(address(timelockA));
        aSummerToken.mint(alice, governorA.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);

        advanceTimeAndBlock();

        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        advanceTimeForVotingDelay();

        // Cast votes
        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        advanceTimeForVotingPeriod();

        // Check if the proposal needs queuing
        bool needsQueuing = governorA.proposalNeedsQueuing(proposalId);

        // Since we're using a TimelockController, the proposal should need queuing
        assertTrue(needsQueuing, "Proposal should need queuing");
    }

    /*
     * @dev Tests the CLOCK_MODE function.
     */
    function test_ClockMode() public view {
        string memory clockMode = governorA.CLOCK_MODE();
        assertEq(clockMode, "mode=timestamp", "Incorrect CLOCK_MODE");
    }

    /*
     * @dev Tests the clock function.
     */
    function test_Clock() public view {
        uint256 currentBlock = block.timestamp;
        uint48 clockValue = governorA.clock();
        assertEq(
            uint256(clockValue),
            currentBlock,
            "Clock value should match current block number"
        );
    }
    /*
     * @dev Tests the supportsInterface function of the governorA.
     * Verifies correct interface support.
     */

    function test_SupportsInterface() public view {
        assertTrue(governorA.supportsInterface(type(IGovernor).interfaceId));
        assertFalse(governorA.supportsInterface(0xffffffff));
    }

    /*
     * @dev Tests the proposal threshold settings.
     * Ensures the threshold is within the allowed range.
     */
    function test_ProposalThreshold() public view {
        uint256 threshold = governorA.proposalThreshold();
        assertGe(threshold, governorA.MIN_PROPOSAL_THRESHOLD());
        assertLe(threshold, governorA.MAX_PROPOSAL_THRESHOLD());
    }

    /*
     * @dev Tests setting proposal threshold out of bounds.
     * Verifies that setting thresholds outside the allowed range reverts.
     */
    function test_SetProposalThresholdOutOfBounds() public {
        uint256 belowMin = governorA.MIN_PROPOSAL_THRESHOLD() - 1;
        uint256 aboveMax = governorA.MAX_PROPOSAL_THRESHOLD() + 1;

        SummerGovernor.GovernorParams memory params = ISummerGovernor
            .GovernorParams({
                token: IVotes(address(aSummerToken)),
                timelock: timelockA,
                votingDelay: VOTING_DELAY,
                votingPeriod: VOTING_PERIOD,
                proposalThreshold: belowMin,
                quorumFraction: QUORUM_FRACTION,
                initialWhitelistGuardian: address(0x5),
                endpoint: lzEndpointA,
                proposalChainId: 31337
            });

        vm.expectRevert(
            abi.encodeWithSelector(
                SummerGovernorInvalidProposalThreshold.selector,
                belowMin,
                governorA.MIN_PROPOSAL_THRESHOLD(),
                governorA.MAX_PROPOSAL_THRESHOLD()
            )
        );
        new SummerGovernor(params);

        params.proposalThreshold = aboveMax;
        vm.expectRevert(
            abi.encodeWithSelector(
                SummerGovernorInvalidProposalThreshold.selector,
                aboveMax,
                governorA.MIN_PROPOSAL_THRESHOLD(),
                governorA.MAX_PROPOSAL_THRESHOLD()
            )
        );
        new SummerGovernor(params);
    }

    /*
     * @dev Tests proposal creation by a whitelisted account.
     * Ensures a whitelisted account can create a proposal without meeting the threshold.
     */
    function test_ProposalCreationWhitelisted() public {
        address whitelistedUser = address(0x1234);
        uint256 expiration = block.timestamp + 10 days;

        // Ensure Alice has enough voting power
        uint256 proposalThreshold = governorA.proposalThreshold();
        vm.startPrank(address(timelockA));
        aSummerToken.mint(alice, proposalThreshold);
        vm.stopPrank();

        vm.startPrank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();
        vm.stopPrank();

        // Create and execute a proposal to set the whitelist account expiration
        address[] memory targets = new address[](1);
        targets[0] = address(governorA);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            SummerGovernor.setWhitelistAccountExpiration.selector,
            whitelistedUser,
            expiration
        );
        string memory description = "Set whitelist account expiration";

        vm.prank(alice);
        uint256 proposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        advanceTimeForVotingDelay();

        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        advanceTimeForVotingPeriod();

        vm.prank(alice);
        governorA.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        advanceTimeForTimelockMinDelay();

        vm.prank(bob);
        governorA.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        // Ensure the whitelisted user has no voting power
        vm.prank(whitelistedUser);
        aSummerToken.delegate(address(0));

        // Verify that the user is whitelisted
        assertTrue(
            governorA.isWhitelisted(whitelistedUser),
            "User should be whitelisted"
        );

        // Now create a proposal as the whitelisted user
        vm.startPrank(whitelistedUser);
        (uint256 anotherProposalId, ) = createProposal();
        vm.stopPrank();

        // Verify that the proposal was created successfully
        assertTrue(
            anotherProposalId > 0,
            "Proposal should be created successfully"
        );
        assertEq(
            uint256(governorA.state(anotherProposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "Proposal should be in Pending state"
        );
    }

    /*
     * @dev Tests cancellation of a proposal by the whitelist guardian.
     * Verifies that the guardian can cancel a proposal.
     */
    function test_CancelProposalByGuardian() public {
        vm.startPrank(address(timelockA));
        aSummerToken.mint(alice, governorA.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);

        advanceTimeAndBlock();

        vm.prank(alice);
        (uint256 proposalId, bytes32 descriptionHash) = createProposal();

        address guardian = address(0x5678);

        // Create and execute a proposal to set the whitelist guardian
        address[] memory targets = new address[](1);
        targets[0] = address(governorA);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            SummerGovernor.setWhitelistGuardian.selector,
            guardian
        );
        string memory description = "Set whitelist guardian";

        vm.prank(alice);
        uint256 guardianProposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        advanceTimeForVotingDelay();

        vm.prank(alice);
        governorA.castVote(guardianProposalId, 1);

        advanceTimeForVotingPeriod();

        governorA.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        advanceTimeForTimelockMinDelay();

        governorA.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        // Now cancel the original proposal as the guardian
        (
            address[] memory cancelTargets,
            uint256[] memory cancelValues,
            bytes[] memory cancelCalldatas,

        ) = createProposalParams(address(aSummerToken));

        vm.prank(guardian);
        governorA.cancel(
            cancelTargets,
            cancelValues,
            cancelCalldatas,
            descriptionHash
        );

        assertEq(
            uint256(governorA.state(proposalId)),
            uint256(IGovernor.ProposalState.Canceled)
        );
    }

    /*
     * @dev Tests cancellation of a proposal by the proposer.
     * Ensures the proposer can cancel their own proposal.
     */
    function test_CancelProposalByProposer() public {
        vm.startPrank(address(timelockA));
        aSummerToken.mint(alice, governorA.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);

        advanceTimeForVotingDelay();

        vm.startPrank(alice);
        (uint256 proposalId, bytes32 descriptionHash) = createProposal();
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,

        ) = createProposalParams(address(aSummerToken));

        governorA.cancel(targets, values, calldatas, descriptionHash);
        vm.stopPrank();

        assertEq(
            uint256(governorA.state(proposalId)),
            uint256(IGovernor.ProposalState.Canceled)
        );
    }

    /*
     * @dev Tests a proposal that doesn't reach quorum.
     * Verifies that a proposal is defeated if it doesn't reach quorum.
     */
    function test_ProposalWithoutQuorum() public {
        uint256 supply = 100000000 * 10 ** 18;

        uint256 quorumThreshold = getQuorumThreshold(supply);
        assertTrue(
            quorumThreshold > governorA.proposalThreshold(),
            "Quorum threshold should be greater than proposal threshold"
        );

        // Give Charlie enough tokens to meet the proposal threshold but not enough to reach quorum
        vm.startPrank(address(timelockA));
        aSummerToken.mint(charlie, quorumThreshold / 2);
        aSummerToken.mint(alice, supply - quorumThreshold / 2);
        vm.stopPrank();

        // Charlie delegates to himself
        vm.prank(charlie);
        aSummerToken.delegate(charlie);

        advanceTimeAndBlock();

        console.log("Charlie's votes :", aSummerToken.getVotes(charlie));
        console.log("Charlie's balance :", aSummerToken.balanceOf(charlie));
        // Ensure Charlie has enough tokens to meet the proposal threshold
        uint256 charlieVotes = governorA.getVotes(charlie, block.timestamp - 1);
        uint256 proposalThreshold = governorA.proposalThreshold();
        assertGe(
            charlieVotes,
            proposalThreshold,
            "Charlie should have enough voting power"
        );
        assertLt(
            charlieVotes,
            quorumThreshold,
            "Charlie should not have enough voting power to reach quorum"
        );

        // Create a proposal
        vm.prank(charlie);
        (uint256 proposalId, ) = createProposal();

        advanceTimeForVotingDelay();

        // Charlie votes in favor
        vm.prank(charlie);
        governorA.castVote(proposalId, 1);

        advanceTimeForVotingPeriod();

        // Check proposal state
        assertEq(
            uint256(governorA.state(proposalId)),
            uint256(IGovernor.ProposalState.Defeated),
            "Proposal should be defeated"
        );

        // Verify that quorum was not reached
        (
            uint256 againstVotes,
            uint256 forVotes,
            uint256 abstainVotes
        ) = governorA.proposalVotes(proposalId);
        uint256 quorum = governorA.quorum(block.timestamp - 1);
        assertTrue(
            forVotes + againstVotes + abstainVotes < quorum,
            "Quorum should not be reached"
        );
    }

    /*
     * @dev Tests various voting scenarios.
     * Covers cases like majority in favor, tie, and majority against.
     */
    function test_VariousVotingScenarios() public {
        // Mint tokens to voters
        uint256 aliceTokens = 1000000e18;
        uint256 bobTokens = 300000e18;
        uint256 charlieTokens = 200000e18;
        uint256 davidTokens = 100000e18;

        vm.startPrank(address(timelockA));
        aSummerToken.mint(alice, aliceTokens); // Increased Alice's tokens
        aSummerToken.mint(bob, bobTokens);
        aSummerToken.mint(charlie, charlieTokens);
        aSummerToken.mint(david, davidTokens);
        vm.stopPrank();

        // Delegate votes
        vm.prank(alice);
        aSummerToken.delegate(alice);
        vm.prank(bob);
        aSummerToken.delegate(bob);
        vm.prank(charlie);
        aSummerToken.delegate(charlie);
        vm.prank(david);
        aSummerToken.delegate(david);

        advanceTimeAndBlock();

        // Mint tokens to the timelockA
        vm.startPrank(address(timelockA));
        aSummerToken.mint(address(timelockA), 1000); // Mint more than needed for the proposal
        vm.stopPrank();

        // Scenario 1: Majority in favor, quorum reached
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams(address(aSummerToken));

        vm.prank(alice); // Ensure Alice is the proposer
        uint256 proposalId1 = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        advanceTimeForVotingDelay();

        console.log(
            "Alice's votes     :",
            governorA.getVotes(alice, block.timestamp - 1)
        );
        console.log(
            "Bob's votes       :",
            governorA.getVotes(bob, block.timestamp - 1)
        );
        console.log(
            "Charlie's votes   :",
            governorA.getVotes(charlie, block.timestamp - 1)
        );
        console.log(
            "David's votes     :",
            governorA.getVotes(david, block.timestamp - 1)
        );
        // Cast votes

        vm.prank(alice);
        governorA.castVote(proposalId1, 1);

        vm.prank(bob);
        governorA.castVote(proposalId1, 1);

        vm.prank(charlie);
        governorA.castVote(proposalId1, 0);

        vm.prank(david);
        governorA.castVote(proposalId1, 2);

        advanceTimeForVotingPeriod();

        assertEq(
            uint256(governorA.state(proposalId1)),
            uint256(IGovernor.ProposalState.Succeeded)
        );

        // Queue and execute the proposal
        bytes32 descriptionHash = keccak256(bytes(description));
        governorA.queue(targets, values, calldatas, descriptionHash);

        advanceTimeForTimelockMinDelay();

        governorA.execute(targets, values, calldatas, descriptionHash);

        assertEq(
            uint256(governorA.state(proposalId1)),
            uint256(IGovernor.ProposalState.Executed)
        );

        advanceTimeAndBlock();

        // Scenario 2: Tie, quorum reached
        aliceTokens = aSummerToken.getVotes(alice);
        bobTokens = aSummerToken.getVotes(bob);
        charlieTokens = aSummerToken.getVotes(charlie);
        davidTokens = aSummerToken.getVotes(david);

        uint256 proposalId2 = createProposalAndVote(bob, 1, 1, 1, 1);

        advanceTimeForVotingPeriod();

        // Add logging statements
        (
            uint256 againstVotes,
            uint256 forVotes,
            uint256 abstainVotes
        ) = governorA.proposalVotes(proposalId2);
        console.log("For votes      :", forVotes);
        console.log("Against votes  :", againstVotes);
        console.log("Abstain votes  :", abstainVotes);
        console.log("Quorum         :", governorA.quorum(block.timestamp - 1));
        console.log(
            "Total supply   :",
            aSummerToken.getPastTotalSupply(block.timestamp - 1)
        );

        // This is the failing assertion
        assertEq(
            uint256(governorA.state(proposalId2)),
            uint256(IGovernor.ProposalState.Succeeded),
            "Proposal should be succeeded"
        );

        // Add assertions to verify vote counts and quorum
        assertEq(
            forVotes,
            aliceTokens + bobTokens + charlieTokens + davidTokens,
            "Incorrect number of 'for' votes"
        );
        assertEq(againstVotes, 0, "There should be no 'against' votes");
        assertEq(abstainVotes, 0, "There should be no 'abstain' votes");
        assertGe(
            forVotes,
            governorA.quorum(block.timestamp - 1),
            "For votes should meet or exceed quorum"
        );

        advanceTimeAndBlock();

        // Scenario 3: Majority against, quorum reached
        aliceTokens = aSummerToken.getVotes(alice);
        bobTokens = aSummerToken.getVotes(bob);
        charlieTokens = aSummerToken.getVotes(charlie);
        davidTokens = aSummerToken.getVotes(david);

        uint256 proposalId3 = createProposalAndVote(charlie, 0, 0, 1, 2);
        advanceTimeForVotingPeriod();
        (againstVotes, forVotes, abstainVotes) = governorA.proposalVotes(
            proposalId3
        );
        assertEq(aliceTokens + bobTokens, againstVotes, "Should be equal");
        assertEq(forVotes, charlieTokens, "For votes should be zero");
        assertEq(
            abstainVotes,
            davidTokens,
            "Against votes should be equal to David's votes"
        );
        assertEq(
            uint256(governorA.state(proposalId3)),
            uint256(IGovernor.ProposalState.Defeated),
            "Proposal should be defeated"
        );
    }

    function test_VotingPowerIncludesVestingWalletBalance() public {
        // Setup: Create a vesting wallet for Alice
        uint256 vestingAmount = 500000 * 10 ** 18;
        uint256 directAmount = 1000000 * 10 ** 18;
        console.log("Vesting amount :", vestingAmount);
        vm.startPrank(address(timelockA));
        aSummerToken.mint(address(timelockA), vestingAmount);
        vm.stopPrank();

        vm.startPrank(address(timelockA));
        aSummerToken.createVestingWallet(
            alice,
            vestingAmount,
            new uint256[](0),
            ISummerVestingWallet.VestingType.TeamVesting
        );
        aSummerToken.mint(alice, directAmount);
        vm.stopPrank();

        // Alice delegates to herself
        vm.prank(alice);
        aSummerToken.delegate(alice);

        advanceTimeAndBlock();

        // Check Alice's voting power
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        uint256 expectedVotingPower = vestingAmount + directAmount;

        assertEq(
            aliceVotingPower,
            expectedVotingPower,
            "Alice's voting power should include both locked and unlocked tokens"
        );

        // Create a proposal
        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        advanceTimeForVotingDelay();

        // Alice votes
        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        // Check proposal votes
        (, uint256 forVotes, ) = governorA.proposalVotes(proposalId);

        assertEq(
            forVotes,
            expectedVotingPower,
            "Proposal votes should reflect Alice's full voting power"
        );
    }

    function test_ProposalCreationOnWrongChain() public {
        uint32 governanceChainId = 1; // Ethereum mainnet
        uint32 currentChainId = 31337; // Anvil's default chain ID

        // Ensure we're on the expected test chain
        assertEq(
            block.chainid,
            currentChainId,
            "Test environment should be on chain 31337"
        );

        // Deploy the governorA with a different chain ID than the current one
        SummerGovernor.GovernorParams memory params = ISummerGovernor
            .GovernorParams({
                token: IVotes(address(aSummerToken)),
                timelock: timelockA,
                votingDelay: VOTING_DELAY,
                votingPeriod: VOTING_PERIOD,
                proposalThreshold: PROPOSAL_THRESHOLD,
                quorumFraction: QUORUM_FRACTION,
                initialWhitelistGuardian: whitelistGuardian,
                endpoint: address(endpoints[aEid]),
                proposalChainId: governanceChainId // Set to a different chain ID
            });

        ExposedSummerGovernor wrongChainGovernor = new ExposedSummerGovernor(
            params
        );

        vm.startPrank(address(timelockA));
        accessManagerA.revokeDecayControllerRole(address(governorA));
        accessManagerA.grantDecayControllerRole(address(wrongChainGovernor));
        vm.stopPrank();

        // Ensure Alice has enough tokens to meet the proposal threshold
        deal(
            address(aSummerToken),
            alice,
            wrongChainGovernor.proposalThreshold()
        );
        vm.prank(alice);
        aSummerToken.delegate(alice);

        advanceTimeAndBlock();

        // Prepare proposal parameters
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams(address(aSummerToken));

        // Attempt to create a proposal, expecting it to revert
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                SummerGovernorInvalidChain.selector,
                currentChainId,
                governanceChainId
            )
        );
        wrongChainGovernor.propose(targets, values, calldatas, description);

        // vm.prank(address(wrongChainGovernor));
        // aSummerToken.setDecayManager(address(governorA), true);
    }

    function test_ProposalFailsQuorumAfterDecay() public {
        // Setup: Mint tokens just above quorum threshold
        uint256 supply = 100000000 * 10 ** 18;
        uint256 quorumThreshold = getQuorumThreshold(supply);

        // Give multiple voters enough combined tokens to meet quorum
        uint256 aliceTokens = quorumThreshold / 2;
        uint256 bobTokens = quorumThreshold / 2;
        uint256 totalVotingPower = aliceTokens + bobTokens;

        vm.startPrank(address(timelockA));
        aSummerToken.mint(alice, aliceTokens);
        aSummerToken.mint(bob, bobTokens);
        aSummerToken.mint(charlie, supply - aliceTokens - bobTokens);
        vm.stopPrank();

        // Delegate voting power
        vm.prank(alice);
        aSummerToken.delegate(alice);
        vm.prank(bob);
        aSummerToken.delegate(bob);
        advanceTimeAndBlock();

        // Verify initial combined voting power meets quorum
        uint256 initialAliceVotes = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        uint256 initialBobVotes = governorA.getVotes(bob, block.timestamp - 1);
        uint256 initialTotalVotes = initialAliceVotes + initialBobVotes;
        uint256 initialQuorum = governorA.quorum(block.timestamp - 1);

        console.log("Initial Alice votes:", initialAliceVotes);
        console.log("Initial Bob votes:", initialBobVotes);
        console.log("Initial total votes:", initialTotalVotes);
        console.log("Initial quorum needed:", initialQuorum);

        assertTrue(
            initialTotalVotes >= initialQuorum,
            "Combined voting power should meet quorum initially"
        );

        advanceTimeForPeriod(aSummerToken.decayFreeWindow() + 30 days);

        // Check decayed voting power
        uint256 decayedAliceVotes = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        uint256 decayedBobVotes = governorA.getVotes(bob, block.timestamp - 1);
        uint256 decayedTotalVotes = decayedAliceVotes + decayedBobVotes;
        uint256 quorumAfterDecay = governorA.quorum(block.timestamp - 1);

        console.log("Decayed Alice votes:", decayedAliceVotes);
        console.log("Decayed Bob votes:", decayedBobVotes);
        console.log("Decayed total votes:", decayedTotalVotes);
        console.log("Quorum needed after decay:", quorumAfterDecay);

        assertTrue(
            decayedTotalVotes < quorumAfterDecay,
            "Combined voting power should be below quorum after decay"
        );

        // Now create proposal with decayed weights
        vm.prank(alice);
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams(address(aSummerToken));

        uint256 proposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        advanceTimeForVotingDelay();

        // Both voters vote in favor
        vm.prank(alice);
        governorA.castVote(proposalId, 1);
        vm.prank(bob);
        governorA.castVote(proposalId, 1);

        // Check final proposal votes
        (, uint256 finalForVotes, ) = governorA.proposalVotes(proposalId);
        uint256 finalQuorum = governorA.quorum(block.timestamp - 1);

        console.log("Final for votes:", finalForVotes);
        console.log("Final quorum needed:", finalQuorum);

        assertTrue(
            finalForVotes < finalQuorum,
            "Proposal should not meet quorum with decayed votes"
        );

        advanceTimeForVotingPeriod();

        assertEq(
            uint256(governorA.state(proposalId)),
            uint256(IGovernor.ProposalState.Defeated),
            "Proposal should be defeated due to insufficient quorum"
        );
    }

    function getQuorumThreshold(uint256 supply) public pure returns (uint256) {
        return (supply * QUORUM_FRACTION) / 100;
    }

    function createProposalAndVote(
        address proposer,
        uint8 aliceVote,
        uint8 bobVote,
        uint8 charlieVote,
        uint8 davidVote
    ) internal returns (uint256) {
        advanceTimeAndBlock();
        vm.prank(proposer);
        (uint256 proposalId, ) = createProposal();

        // Add a check here to ensure the proposal is created successfully
        require(proposalId != 0, "Proposal creation failed");

        advanceTimeForVotingDelay();

        vm.prank(alice);
        governorA.castVote(proposalId, aliceVote);
        vm.prank(bob);
        governorA.castVote(proposalId, bobVote);
        vm.prank(charlie);
        governorA.castVote(proposalId, charlieVote);
        vm.prank(david);
        governorA.castVote(proposalId, davidVote);

        return proposalId;
    }

    /*
     * @dev Creates a proposal for testing purposes.
     * @return proposalId The ID of the created proposal.
     * @return descriptionHash The hash of the proposal description.
     */
    function createProposal() internal returns (uint256, bytes32) {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams(address(aSummerToken));

        // Add a unique identifier to the description to ensure unique proposals
        description = string(
            abi.encodePacked(description, " - ", block.number)
        );

        uint256 proposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        return (proposalId, hashDescription(description));
    }

    /*
     * @dev Creates parameters for a proposal.
     * @return targets The target addresses for the proposal.
     * @return values The values to be sent with the proposal.
     * @return calldatas The function call data for the proposal.
     * @return description The description of the proposal.
     */
    function createProposalParams(
        address tokenAddress
    )
        internal
        view
        returns (
            address[] memory,
            uint256[] memory,
            bytes[] memory,
            string memory
        )
    {
        address[] memory targets = new address[](1);
        targets[0] = tokenAddress;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            bob,
            100
        );
        string memory description = "Transfer 100 tokens to Bob";

        return (targets, values, calldatas, description);
    }

    /*
     * @dev Hashes the description of a proposal.
     * @param description The description to hash.
     * @return The keccak256 hash of the description.
     */
    function hashDescription(
        string memory description
    ) internal pure returns (bytes32) {
        return keccak256(bytes(description));
    }

    function test_DecayUpdateOnPropose() public {
        // Setup
        vm.startPrank(address(timelockA));
        aSummerToken.mint(alice, governorA.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        // Verify decay update is called when proposing
        vm.expectCall(
            address(aSummerToken),
            abi.encodeWithSelector(
                ISummerToken.updateDecayFactor.selector,
                alice
            )
        );

        vm.prank(alice);
        createProposal();
    }

    function test_VestingWalletVotingPower() public {
        // Initial setup
        uint256 vestingAmount = 500000 * 10 ** 18;
        uint256 directAmount = 1000000 * 10 ** 18;
        uint256 additionalAmount = 100000 * 10 ** 18;
        address _bob = address(0xb0b);

        vm.prank(address(timelockA));
        aSummerToken.setDecayRatePerSecond(0);

        vm.prank(_bob);
        // Bob delegates to himself - even if he has no tokens yet, he will have voting power after Cas 5 test is
        // finished
        aSummerToken.delegate(_bob);
        advanceTimeAndBlock();

        // Mint initial tokens to timelockA
        vm.startPrank(address(timelockA));
        aSummerToken.mint(address(timelockA), vestingAmount * 2); // Extra for additional tests
        vm.stopPrank();

        // Case 1: Create vesting wallet and transfer initial tokens
        vm.startPrank(address(timelockA));
        aSummerToken.createVestingWallet(
            alice,
            vestingAmount,
            new uint256[](0),
            ISummerVestingWallet.VestingType.TeamVesting
        );

        aSummerToken.mint(alice, directAmount);
        vm.stopPrank();

        address vestingWalletAddress = aSummerToken.vestingWallets(alice);
        SummerVestingWallet vestingWallet = SummerVestingWallet(
            payable(vestingWalletAddress)
        );

        // Need to initialize decay account for vesting wallet to read votes
        governorA.forceUpdateDecay(vestingWalletAddress);

        // Alice delegates to herself
        vm.prank(alice);
        aSummerToken.delegate(alice);

        advanceTimeAndBlock();

        // Check initial state
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        uint256 vestingWalletVotingPower = governorA.getVotes(
            vestingWalletAddress,
            block.timestamp - 1
        );
        assertEq(
            vestingWalletVotingPower,
            0,
            "Vesting wallet should have 0 voting power"
        );
        assertEq(
            aliceVotingPower,
            vestingAmount + directAmount,
            "Alice should have voting power from both direct and vesting tokens"
        );

        // Case 2: Transfer from Alice to vesting wallet (should not change voting power)
        vm.startPrank(alice);
        aSummerToken.transfer(vestingWalletAddress, 100000 * 10 ** 18);
        advanceTimeAndBlock();

        uint256 newAliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        assertEq(
            newAliceVotingPower,
            aliceVotingPower,
            "Alice's voting power should not change when transferring to own vesting wallet"
        );

        // Case 3: Transfer from another address to vesting wallet
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(vestingWalletAddress, additionalAmount);
        advanceTimeAndBlock();

        uint256 updatedAliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        assertEq(
            updatedAliceVotingPower,
            newAliceVotingPower + additionalAmount,
            "Alice's voting power should increase when vesting wallet receives tokens from others"
        );

        // Case 4: Transfer from vesting wallet to beneficiary (Alice)
        // First, let's make the tokens vestable
        vm.warp(block.timestamp + 365 days);
        uint256 vestableAmount = vestingWallet.vestedAmount(
            address(aSummerToken),
            SafeCast.toUint64(block.timestamp)
        );
        vm.startPrank(alice);
        vestingWallet.release(address(aSummerToken));
        advanceTimeAndBlock();

        uint256 afterClaimVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        assertEq(
            afterClaimVotingPower,
            updatedAliceVotingPower,
            "Alice's voting power should be less than the updated amount because of decay"
        );

        // Case 5: Transfer from vesting wallet to third party (Bob)
        vm.startPrank(vestingWalletAddress);
        uint256 transferAmount = 25000 * 10 ** 18;
        aSummerToken.transfer(_bob, transferAmount);
        advanceTimeAndBlock();

        uint256 finalAliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        uint256 bobVotingPower = governorA.getVotes(_bob, block.timestamp - 1);
        assertEq(
            finalAliceVotingPower,
            afterClaimVotingPower - transferAmount,
            "Alice's voting power should decrease when vesting wallet transfers to third party"
        );
        assertEq(
            bobVotingPower,
            transferAmount,
            "Bob should receive voting power from vesting wallet transfer"
        );
    }

    function test_DecayUpdateOnVote() public {
        // Setup proposal
        vm.startPrank(address(timelockA));
        aSummerToken.mint(alice, governorA.proposalThreshold());
        aSummerToken.mint(bob, governorA.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        vm.prank(bob);
        aSummerToken.delegate(bob);
        advanceTimeAndBlock();

        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        // Move to voting period
        advanceTimeForVotingDelay();

        // Verify decay update is called when voting
        vm.expectCall(
            address(aSummerToken),
            abi.encodeWithSelector(ISummerToken.updateDecayFactor.selector, bob)
        );

        vm.prank(bob);
        governorA.castVote(proposalId, 1);
    }

    function test_DecayUpdateOnExecute() public {
        // Setup with sufficient balance for execution
        uint256 initialBalance = governorA.proposalThreshold() * 2;
        vm.startPrank(address(timelockA));
        aSummerToken.mint(alice, initialBalance);
        aSummerToken.mint(address(timelockA), 1000); // Add balance for transfer
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        vm.prank(alice);
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams(address(aSummerToken));

        uint256 proposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        advanceTimeForVotingDelay();

        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        advanceTimeForVotingPeriod();

        governorA.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        advanceTimeForTimelockMinDelay();

        // Verify decay update is called when executing
        vm.expectCall(
            address(aSummerToken),
            abi.encodeWithSelector(ISummerToken.updateDecayFactor.selector, bob)
        );

        vm.prank(bob);
        governorA.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );
    }

    function test_DecayUpdateOnCancel() public {
        // Setup and create proposal
        vm.startPrank(address(timelockA));
        aSummerToken.mint(alice, governorA.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        vm.startPrank(alice);
        (uint256 proposalId, bytes32 descriptionHash) = createProposal();
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,

        ) = createProposalParams(address(aSummerToken));

        // Verify decay update is called when cancelling
        vm.expectCall(
            address(aSummerToken),
            abi.encodeWithSelector(
                ISummerToken.updateDecayFactor.selector,
                alice
            )
        );

        governorA.cancel(targets, values, calldatas, descriptionHash);
        vm.stopPrank();
    }

    function test_DecayFactorUpdatesCorrectly() public {
        uint256 initialBalance = governorA.proposalThreshold() * 10;
        vm.startPrank(address(timelockA));
        aSummerToken.mint(alice, initialBalance);
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        // Get initial decay factor
        uint256 initialDecayFactor = aSummerToken.getDecayFactor(alice);

        // Create proposal
        vm.prank(alice);
        createProposal();

        advanceTimeForPeriod(VOTING_DELAY + 30 days);

        // Check decay factor after proposal
        uint256 decayFactorAfterProposal = aSummerToken.getDecayFactor(alice);

        assertLt(
            decayFactorAfterProposal,
            initialDecayFactor,
            "Decay factor should decrease after proposal creation"
        );

        console.log("Initial decay factor:", initialDecayFactor);
        console.log("Decay factor after proposal:", decayFactorAfterProposal);
    }

    // For immediate operations (propose, vote, etc)
    function advanceTimeAndBlock() internal {
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);
    }

    function advanceTimeForPeriod(uint256 extraTime) internal {
        vm.warp(block.timestamp + extraTime);
        vm.roll(block.number + 1);
    }

    function advanceTimeForTimelockMinDelay() internal {
        vm.warp(block.timestamp + timelockA.getMinDelay() + 1);
        vm.roll(block.number + 1);
    }

    function advanceTimeForVotingPeriod() internal {
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + 1);
    }

    function advanceTimeForVotingDelay() internal {
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + 1);
    }
}
