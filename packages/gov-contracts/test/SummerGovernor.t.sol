// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Origin, SummerGovernor} from "../src/contracts/SummerGovernor.sol";
import {ISummerGovernorErrors} from "../src/errors/ISummerGovernorErrors.sol";

import {ISummerGovernor} from "../src/interfaces/ISummerGovernor.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

import {SummerToken} from "../src/contracts/SummerToken.sol";
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
import {ExposedSummerGovernor, SummerGovernorTestBase} from "./SummerGovernorTestBase.sol";

/*
 * @title SummerGovernorTest
 * @dev Test contract for SummerGovernor functionality.
 */
contract SummerGovernorTest is SummerGovernorTestBase {
    function test_InitialSetup() public {
        address lzEndpointA = address(endpoints[aEid]);

        SummerGovernor.GovernorParams memory params = ISummerGovernor
            .GovernorParams({
                token: aSummerToken,
                timelock: timelockA,
                accessManager: accessManagerA,
                votingDelay: VOTING_DELAY,
                votingPeriod: VOTING_PERIOD,
                proposalThreshold: PROPOSAL_THRESHOLD,
                quorumFraction: QUORUM_FRACTION,
                endpoint: lzEndpointA,
                hubChainId: 31337,
                peerEndpointIds: new uint32[](0),
                peerAddresses: new address[](0)
            });
        vm.expectRevert(
            abi.encodeWithSignature(
                "SummerGovernorInvalidGuardian(address)",
                address(0)
            )
        );
        new SummerGovernor(params);

        assertEq(governorA.name(), "SummerGovernor");
        assertEq(governorA.votingDelay(), VOTING_DELAY);
        assertEq(governorA.votingPeriod(), VOTING_PERIOD);
        assertEq(governorA.proposalThreshold(), PROPOSAL_THRESHOLD);
        assertEq(governorA.quorumNumerator(), QUORUM_FRACTION);
    }

    /*
     * @dev Tests the proposal creation process.
     * Ensures that a proposal can be created successfully.
     */
    function test_ProposalCreation() public {
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(
            address(alice),
            governorA.quorum(block.timestamp - 1)
        );
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
        aSummerToken.transfer(alice, governorA.proposalThreshold());
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
        aSummerToken.transfer(alice, governorA.quorum(block.timestamp - 1));
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
     * @dev Tests the proposal cancellation process.
     * Ensures that a proposal can be canceled by the whitelist guardian.
     */
    function test_ProposalCancellation() public {
        // Setup initial tokens for proposal creation
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(
            address(alice),
            governorA.proposalThreshold() * 2
        );
        vm.stopPrank();

        vm.startPrank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        // Create a regular proposal (e.g., to transfer tokens)
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

        // Cancel with guardian (should succeed)
        // Note: guardian is set up in the test base with the proper role
        vm.startPrank(guardian);
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

        // Verify guardian role through AccessManager
        assertTrue(
            accessManagerA.hasRole(accessManagerA.GUARDIAN_ROLE(), guardian),
            "Guardian should have guardian role in AccessManager"
        );
    }

    /*
     * @dev Tests that a proposal creation fails when the proposer is below threshold and not whitelisted.
     */
    function test_ProposalCreationBelowThresholdAndNotWhitelisted() public {
        // Ensure Charlie has some tokens, but below the proposal threshold
        uint256 belowThreshold = governorA.proposalThreshold() - 1;
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(charlie, belowThreshold);
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

        // Expect the transaction to revert with SummerGovernorProposerBelowThresholdAndNotGuardian error
        vm.expectRevert(
            abi.encodeWithSelector(
                SummerGovernorProposerBelowThresholdAndNotGuardian.selector,
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
        aSummerToken.transfer(alice, governorA.proposalThreshold());
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
                token: aSummerToken,
                timelock: timelockA,
                accessManager: accessManagerA,
                votingDelay: VOTING_DELAY,
                votingPeriod: VOTING_PERIOD,
                proposalThreshold: belowMin,
                quorumFraction: QUORUM_FRACTION,
                endpoint: lzEndpointA,
                hubChainId: 31337,
                peerEndpointIds: new uint32[](0),
                peerAddresses: new address[](0)
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
     * @dev Tests proposal creation by a guardian account.
     * Ensures a guardian account can create a proposal without meeting the threshold.
     */
    function test_ProposalCreationByGuardian() public {
        address guardian = address(0x1234);

        // Ensure Alice has enough voting power for governance
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.quorum(block.timestamp - 1));
        vm.stopPrank();

        vm.startPrank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();
        vm.stopPrank();

        // Create proposal to grant guardian role through AccessManager
        address[] memory targets = new address[](1);
        targets[0] = address(accessManagerA);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            IProtocolAccessManager.grantGuardianRole.selector,
            guardian
        );
        string memory description = "Grant guardian role";

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

        // Ensure the guardian has no voting power
        vm.prank(guardian);
        aSummerToken.delegate(address(0));

        // Verify that the account has the guardian role
        assertTrue(
            accessManagerA.hasRole(accessManagerA.GUARDIAN_ROLE(), guardian),
            "Account should have guardian role"
        );

        // Create a proposal as the guardian without meeting threshold
        vm.startPrank(guardian);
        (uint256 guardianProposalId, ) = createProposal();
        vm.stopPrank();

        // Verify that the proposal was created successfully
        assertTrue(
            guardianProposalId > 0,
            "Proposal should be created successfully"
        );
        assertEq(
            uint256(governorA.state(guardianProposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "Proposal should be in Pending state"
        );

        // Verify guardian can create proposal without meeting threshold
        uint256 guardianVotes = governorA.getVotes(
            guardian,
            block.timestamp - 1
        );
        assertTrue(
            guardianVotes < governorA.proposalThreshold(),
            "Guardian should have less votes than threshold"
        );
    }

    /*
     * @dev Tests cancellation of a proposal by the whitelist guardian.
     * Verifies that the guardian can cancel a proposal.
     */
    function test_CancelProposalByGuardian() public {
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.proposalThreshold());
        vm.stopPrank();
        vm.prank(alice);
        aSummerToken.delegate(alice);

        advanceTimeAndBlock();

        vm.prank(alice);
        (uint256 proposalId, bytes32 descriptionHash) = createProposal();

        address guardian = address(0x5678);

        // Create and execute a proposal to set the guardian
        address[] memory targets = new address[](1);
        targets[0] = address(governorA);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            IProtocolAccessManager.grantGuardianRole.selector,
            guardian
        );
        string memory description = "Grant guardian role";

        vm.prank(alice);
        uint256 guardianProposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        // Give Alice more tokens so we exceed the quorum threshold
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.quorum(block.timestamp - 1));
        vm.stopPrank();

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
        aSummerToken.transfer(alice, governorA.proposalThreshold());
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
        aSummerToken.transfer(charlie, quorumThreshold / 2);
        aSummerToken.transfer(alice, supply - quorumThreshold / 2);
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

    function test_ProposalWithMajorityInFavor() public {
        // Mint tokens to voters
        uint256 aliceTokens = 38000000e18;
        uint256 bobTokens = 3000000e18;
        uint256 charlieTokens = 2000000e18;
        uint256 davidTokens = 2000000e18;

        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, aliceTokens);
        aSummerToken.transfer(bob, bobTokens);
        aSummerToken.transfer(charlie, charlieTokens);
        aSummerToken.transfer(david, davidTokens);
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

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams(address(aSummerToken));

        vm.prank(alice);
        uint256 proposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        advanceTimeForVotingDelay();

        // Cast votes
        vm.prank(alice);
        governorA.castVote(proposalId, 1); // For
        vm.prank(bob);
        governorA.castVote(proposalId, 1); // For
        vm.prank(charlie);
        governorA.castVote(proposalId, 0); // Against
        vm.prank(david);
        governorA.castVote(proposalId, 2); // Abstain

        advanceTimeForVotingPeriod();

        assertEq(
            uint256(governorA.state(proposalId)),
            uint256(IGovernor.ProposalState.Succeeded)
        );

        // Queue and execute the proposal
        bytes32 descriptionHash = keccak256(bytes(description));
        governorA.queue(targets, values, calldatas, descriptionHash);

        advanceTimeForTimelockMinDelay();

        governorA.execute(targets, values, calldatas, descriptionHash);

        assertEq(
            uint256(governorA.state(proposalId)),
            uint256(IGovernor.ProposalState.Executed)
        );
    }

    function test_ProposalWithUnanimousSupport() public {
        // Mint tokens to voters
        uint256 aliceTokens = 20000000e18;
        uint256 bobTokens = 3000000e18;
        uint256 charlieTokens = 2000000e18;
        uint256 davidTokens = 20000000e18;

        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, aliceTokens);
        aSummerToken.transfer(bob, bobTokens);
        aSummerToken.transfer(charlie, charlieTokens);
        aSummerToken.transfer(david, davidTokens);
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

        uint256 proposalId = createProposalAndVote(bob, 1, 1, 1, 1);

        advanceTimeForVotingPeriod();

        // Get vote counts
        (
            uint256 againstVotes,
            uint256 forVotes,
            uint256 abstainVotes
        ) = governorA.proposalVotes(proposalId);

        // Verify quorum was met
        assertTrue(
            forVotes + againstVotes + abstainVotes >=
                governorA.quorum(block.timestamp - 1),
            "Failed to meet quorum"
        );

        // Verify unanimous support
        assertTrue(forVotes > againstVotes, "Failed to achieve majority");
        assertEq(againstVotes, 0, "Should have no votes against");
        assertEq(abstainVotes, 0, "Should have no abstentions");

        assertEq(
            uint256(governorA.state(proposalId)),
            uint256(IGovernor.ProposalState.Succeeded),
            "Proposal should be succeeded"
        );
    }

    function test_ProposalWithMajorityAgainst() public {
        // Mint tokens to voters
        uint256 aliceTokens = 38000000e18;
        uint256 bobTokens = 3000000e18;
        uint256 charlieTokens = 2000000e18;
        uint256 davidTokens = 2000000e18;

        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, aliceTokens);
        aSummerToken.transfer(bob, bobTokens);
        aSummerToken.transfer(charlie, charlieTokens);
        aSummerToken.transfer(david, davidTokens);
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

        uint256 proposalId = createProposalAndVote(charlie, 0, 0, 1, 2);

        advanceTimeForVotingPeriod();

        (
            uint256 againstVotes,
            uint256 forVotes,
            uint256 abstainVotes
        ) = governorA.proposalVotes(proposalId);

        assertEq(
            againstVotes,
            aliceTokens + bobTokens,
            "Incorrect against votes"
        );
        assertEq(forVotes, charlieTokens, "Incorrect for votes");
        assertEq(abstainVotes, davidTokens, "Incorrect abstain votes");

        assertEq(
            uint256(governorA.state(proposalId)),
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
        aSummerToken.approve(address(vestingWalletFactoryA), vestingAmount);
        vestingWalletFactoryA.createVestingWallet(
            alice,
            vestingAmount,
            new uint256[](0),
            ISummerVestingWallet.VestingType.TeamVesting
        );
        aSummerToken.transfer(alice, directAmount);
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
                token: aSummerToken,
                timelock: timelockA,
                accessManager: accessManagerA,
                votingDelay: VOTING_DELAY,
                votingPeriod: VOTING_PERIOD,
                proposalThreshold: PROPOSAL_THRESHOLD,
                quorumFraction: QUORUM_FRACTION,
                endpoint: address(endpoints[aEid]),
                hubChainId: governanceChainId,
                peerEndpointIds: new uint32[](0),
                peerAddresses: new address[](0)
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
                SummerGovernorNotHubChain.selector,
                currentChainId,
                governanceChainId
            )
        );
        wrongChainGovernor.propose(targets, values, calldatas, description);
    }

    function test_ProposalFailsQuorumAfterDecay() public {
        // Setup: Mint tokens just above quorum threshold
        uint256 supply = INITIAL_SUPPLY * 10 ** 18;
        uint256 quorumThreshold = getQuorumThreshold(supply);

        // Give multiple voters enough combined tokens to meet quorum
        uint256 aliceTokens = quorumThreshold / 2;
        uint256 bobTokens = quorumThreshold / 2;

        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, aliceTokens);
        aSummerToken.transfer(bob, bobTokens);
        aSummerToken.transfer(charlie, supply - aliceTokens - bobTokens);
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

        advanceTimeForPeriod(aSummerToken.getDecayFreeWindow() + 30 days);

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

    function test_DecayUpdateOnPropose() public {
        // Setup
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.proposalThreshold());
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

        // Case 1: Create vesting wallet and transfer initial tokens
        vm.startPrank(address(timelockA));
        aSummerToken.approve(address(vestingWalletFactoryA), vestingAmount);
        vestingWalletFactoryA.createVestingWallet(
            alice,
            vestingAmount,
            new uint256[](0),
            ISummerVestingWallet.VestingType.TeamVesting
        );

        aSummerToken.transfer(alice, directAmount);
        vm.stopPrank();

        address vestingWalletAddress = vestingWalletFactoryA.vestingWallets(
            alice
        );
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
        vestingWallet.vestedAmount(
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
        aSummerToken.transfer(alice, governorA.proposalThreshold());
        aSummerToken.transfer(bob, governorA.proposalThreshold());
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
        uint256 initialBalance = governorA.quorum(block.timestamp - 1);
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, initialBalance);
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
        aSummerToken.transfer(alice, governorA.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        vm.startPrank(alice);
        (, bytes32 descriptionHash) = createProposal();
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
        aSummerToken.transfer(alice, initialBalance);
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

    function test_GetGuardianExpiration() public {
        // Give Alice enough tokens to meet quorum
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.quorum(block.timestamp - 1));
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        address guardian = address(0x1234);
        uint256 expiration = block.timestamp + 10 days;

        // Set up guardian through governance
        address[] memory targets = new address[](1);
        targets[0] = address(governorA);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            IProtocolAccessManager.setGuardianExpiration.selector,
            guardian,
            expiration
        );
        string memory description = "Set guardian expiration";

        // Create proposal
        vm.prank(alice);
        uint256 proposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        // Vote on proposal
        advanceTimeForVotingDelay();
        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        // Wait for voting period to end
        advanceTimeForVotingPeriod();

        // Queue the proposal
        bytes32 descriptionHash = keccak256(bytes(description));
        governorA.queue(targets, values, calldatas, descriptionHash);

        // Wait for timelock delay
        advanceTimeForTimelockMinDelay();

        // Execute the proposal
        governorA.execute(targets, values, calldatas, descriptionHash);

        // Verify guardian expiration
        uint256 guardianExpiration = accessManagerA.getGuardianExpiration(
            guardian
        );
        assertEq(
            guardianExpiration,
            expiration,
            "Guardian expiration should match set value"
        );
    }

    /*
     * @dev Tests the guardian role assignment through a governance proposal.
     * Verifies that an account can be granted the guardian role via a proposal.
     */
    function test_GuardianRoleAssignment() public {
        address account = address(0x03);

        // Give Alice enough tokens to meet proposal threshold
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.proposalThreshold());
        vm.stopPrank();

        vm.startPrank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();
        vm.stopPrank();

        // Create proposal to grant guardian role through AccessManager
        address[] memory targets = new address[](1);
        targets[0] = address(accessManagerA);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            IProtocolAccessManager.grantGuardianRole.selector,
            account
        );
        string memory description = "Grant guardian role to account";

        vm.prank(alice);
        uint256 proposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        // Give Alice enough tokens to meet quorum
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.quorum(block.timestamp - 1));
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);

        advanceTimeForVotingDelay();

        // Vote on proposal
        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        advanceTimeForVotingPeriod();

        // Queue and execute the proposal
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

        // Verify the account has been granted the guardian role
        bool hasGuardianRole = accessManagerA.hasRole(
            accessManagerA.GUARDIAN_ROLE(),
            account
        );
        assertTrue(hasGuardianRole, "Account should have guardian role");

        // Verify the account can perform guardian actions
        vm.prank(account);
        (
            address[] memory cancelTargets,
            uint256[] memory cancelValues,
            bytes[] memory cancelCalldatas,
            string memory cancelDescription
        ) = createProposalParams(address(aSummerToken));

        uint256 newProposalId = governorA.propose(
            cancelTargets,
            cancelValues,
            cancelCalldatas,
            cancelDescription
        );

        // Guardian should be able to cancel the proposal
        vm.prank(account);
        governorA.cancel(
            cancelTargets,
            cancelValues,
            cancelCalldatas,
            keccak256(bytes(cancelDescription))
        );

        assertEq(
            uint256(governorA.state(newProposalId)),
            uint256(IGovernor.ProposalState.Canceled),
            "Proposal should be canceled by guardian"
        );
    }
}
