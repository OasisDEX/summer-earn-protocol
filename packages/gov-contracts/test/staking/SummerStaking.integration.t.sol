// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {SummerStaking} from "../../src/contracts/SummerStaking.sol";
import {SummerGovernorV2TestBase} from "../governorV2/SummerGovernorV2TestBase.sol";
import {SummerStakingTestBase} from "./SummerStakingTestBase.sol";

/*
 * @title SummerStaking Integration Tests
 * @dev Test contract for SummerStaking integration with governance functionality.
 */
contract SummerStakingIntegrationTest is SummerStakingTestBase {
    // Test constants to eliminate magic numbers
    uint256 constant USER_1_STAKE_AMOUNT = 500000 * 10 ** 18;
    uint256 constant USER_2_STAKE_AMOUNT = 300000 * 10 ** 18;
    uint256 constant USER_3_STAKE_AMOUNT = 100000 * 10 ** 18;
    uint256 constant PROPOSAL_THRESHOLD_TEST_AMOUNT = 2000000 * 10 ** 18;
    uint256 constant BELOW_THRESHOLD_AMOUNT = 500 * 10 ** 18;

    function setUp() public override {
        super.setUp();

        // Setup test users with tokens
        deal(address(aSummerToken), alice, USER_1_STAKE_AMOUNT * 2);
        deal(address(aSummerToken), bob, USER_2_STAKE_AMOUNT * 2);
        deal(address(aSummerToken), charlie, USER_3_STAKE_AMOUNT * 2);
        deal(address(aSummerToken), david, PROPOSAL_THRESHOLD_TEST_AMOUNT * 2);
        deal(address(aSummerToken), whale, BELOW_THRESHOLD_AMOUNT * 2);
    }

    // ========================================
    // STAKING GOVERNANCE INTEGRATION TESTS
    // ========================================

    function test_Staking_VotingPower_IncludesStakedTokens() public {
        uint256 stakeAmount = USER_1_STAKE_AMOUNT;

        // Stake tokens and delegate
        stakeAndDelegate(alice, stakeAmount, true);

        advanceTimeAndBlock();

        // Check Alice's voting power
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        assertEq(
            aliceVotingPower,
            stakeAmount,
            "Alice's voting power should equal her staked amount"
        );

        // Create a proposal
        vm.prank(alice);
        (uint256 proposalId, ) = createStakingProposal();

        advanceTimeForVotingDelay();

        // Alice votes
        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        // Check proposal votes
        (, uint256 forVotes, ) = governorA.proposalVotes(proposalId);

        assertEq(
            forVotes,
            stakeAmount,
            "Proposal votes should reflect Alice's full voting power"
        );
    }

    function test_Staking_VotingPower_MultipleUsers() public {
        uint256 stakeAmount1 = USER_1_STAKE_AMOUNT;
        uint256 stakeAmount2 = USER_2_STAKE_AMOUNT;

        // Both users stake and delegate
        stakeAndDelegate(alice, stakeAmount1, true);
        stakeAndDelegate(bob, stakeAmount2, true);

        advanceTimeAndBlock();

        // Check voting powers
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        uint256 bobVotingPower = governorA.getVotes(bob, block.timestamp - 1);

        assertEq(
            aliceVotingPower,
            stakeAmount1,
            "Alice's voting power should equal her stake"
        );
        assertEq(
            bobVotingPower,
            stakeAmount2,
            "Bob's voting power should equal his stake"
        );

        // Create a proposal
        vm.prank(alice);
        (uint256 proposalId, ) = createStakingProposal();

        advanceTimeForVotingDelay();

        // Both users vote
        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        vm.prank(bob);
        governorA.castVote(proposalId, 1);

        // Check proposal votes
        (, uint256 forVotes, ) = governorA.proposalVotes(proposalId);

        assertEq(
            forVotes,
            stakeAmount1 + stakeAmount2,
            "Proposal votes should reflect both users' voting power"
        );
    }

    function test_Staking_VotingPower_Delegation() public {
        uint256 stakeAmount = USER_1_STAKE_AMOUNT;

        // Alice stakes tokens
        stakeAndDelegate(alice, stakeAmount, true);

        // Bob delegates to Alice
        vm.prank(bob);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Check voting powers
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        uint256 bobVotingPower = governorA.getVotes(bob, block.timestamp - 1);

        assertEq(
            aliceVotingPower,
            stakeAmount,
            "Alice should have her staked voting power"
        );
        assertEq(
            bobVotingPower,
            0,
            "Bob should have no voting power (delegated away)"
        );

        // Create a proposal
        vm.prank(alice);
        (uint256 proposalId, ) = createStakingProposal();

        advanceTimeForVotingDelay();

        // Alice votes (representing both her stake and Bob's delegation)
        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        // Check proposal votes
        (, uint256 forVotes, ) = governorA.proposalVotes(proposalId);

        assertEq(
            forVotes,
            stakeAmount,
            "Proposal votes should reflect Alice's voting power (including delegation)"
        );
    }

    function test_Staking_VotingPower_Undelegation() public {
        uint256 stakeAmount = USER_1_STAKE_AMOUNT;

        // Alice stakes and delegates to herself
        stakeAndDelegate(alice, stakeAmount, true);

        advanceTimeAndBlock();

        // Alice undelegates (delegates to address(0))
        vm.prank(alice);
        axSumr.delegate(address(0));

        advanceTimeAndBlock();

        uint256 afterUndelegationVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        assertEq(
            afterUndelegationVotingPower,
            0,
            "Alice should have no voting power after undelegating"
        );
    }

    function test_Staking_VotingPower_ProposalThreshold() public {
        uint256 aboveThresholdAmount = PROPOSAL_THRESHOLD_TEST_AMOUNT;
        uint256 belowThresholdAmount = BELOW_THRESHOLD_AMOUNT;
        deal(address(aSummerToken), alice, aboveThresholdAmount);
        deal(address(aSummerToken), bob, belowThresholdAmount);

        // Alice stakes above threshold
        stakeAndDelegate(alice, aboveThresholdAmount, true);

        // Bob stakes below threshold
        stakeAndDelegate(bob, belowThresholdAmount, true);

        advanceTimeAndBlock();

        // Check threshold status
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        uint256 bobVotingPower = governorA.getVotes(bob, block.timestamp - 1);
        uint256 proposalThreshold = governorA.proposalThreshold();

        assertGe(
            aliceVotingPower,
            proposalThreshold,
            "Alice should meet proposal threshold"
        );

        assertLt(
            bobVotingPower,
            proposalThreshold,
            "Bob should be below proposal threshold"
        );

        // Alice should be able to create a proposal
        vm.prank(alice);
        (uint256 proposalId, ) = createStakingProposal();

        assertGt(
            proposalId,
            0,
            "Alice should be able to create a proposal with sufficient voting power"
        );

        // Bob should NOT be able to create a proposal
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSignature(
                "SummerGovernorProposerBelowThresholdAndNotGuardian(address,uint256,uint256)",
                bob,
                bobVotingPower,
                proposalThreshold
            )
        );
        createStakingProposal();
        vm.stopPrank();
    }

    function test_Staking_Unstake_EffectsOnVotingPower() public {
        uint256 stakeAmount = USER_1_STAKE_AMOUNT;

        // Alice stakes and delegates
        stakeAndDelegate(alice, stakeAmount, true);

        advanceTimeAndBlock();

        uint256 votingPowerBeforeUnstake = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        // Alice unstakes
        _approveAndUnstake(aStaking, alice, 0, stakeAmount);

        advanceTimeAndBlock();

        uint256 votingPowerAfterUnstake = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        assertEq(
            votingPowerBeforeUnstake,
            stakeAmount,
            "Voting power before unstake should equal stake amount"
        );

        assertEq(
            votingPowerAfterUnstake,
            0,
            "Voting power after unstake should be zero"
        );
    }

    function test_Staking_PartialUnstake_EffectsOnVotingPower() public {
        uint256 stakeAmount = USER_1_STAKE_AMOUNT;
        uint256 unstakeAmount = stakeAmount / 2;

        // Alice stakes and delegates
        stakeAndDelegate(alice, stakeAmount, true);

        advanceTimeAndBlock();

        uint256 votingPowerBeforeUnstake = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        // Alice partially unstakes
        _approveAndUnstake(aStaking, alice, 0, unstakeAmount);

        advanceTimeAndBlock();

        uint256 votingPowerAfterUnstake = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        assertEq(
            votingPowerBeforeUnstake,
            stakeAmount,
            "Voting power before unstake should equal full stake amount"
        );

        assertEq(
            votingPowerAfterUnstake,
            stakeAmount - unstakeAmount,
            "Voting power after partial unstake should equal remaining stake"
        );
    }

    function test_Staking_MultipleStakeUnstake_RoundTrip() public {
        uint256 stakeAmount1 = USER_1_STAKE_AMOUNT;
        uint256 stakeAmount2 = USER_2_STAKE_AMOUNT;

        // Alice stakes twice
        stakeAndDelegate(alice, stakeAmount1, false);
        stakeAndDelegate(alice, stakeAmount2, true);

        advanceTimeAndBlock();

        uint256 votingPowerAfterDoubleStake = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        assertEq(
            votingPowerAfterDoubleStake,
            stakeAmount1 + stakeAmount2,
            "Voting power should equal sum of both stakes"
        );

        // Alice unstakes partially
        uint256 partialUnstakeAmount = stakeAmount1 / 2;
        _approveAndUnstake(aStaking, alice, 0, partialUnstakeAmount);

        advanceTimeAndBlock();

        uint256 votingPowerAfterPartialUnstake = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        assertEq(
            votingPowerAfterPartialUnstake,
            stakeAmount1 + stakeAmount2 - partialUnstakeAmount,
            "Voting power should reflect partial unstake"
        );

        // Alice unstakes remaining amount
        uint256 remainingAmount = stakeAmount1 +
            stakeAmount2 -
            partialUnstakeAmount;
        _approveAndUnstake(aStaking, alice, 0, remainingAmount);

        advanceTimeAndBlock();

        uint256 votingPowerAfterFullUnstake = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        assertEq(
            votingPowerAfterFullUnstake,
            0,
            "Voting power should be zero after full unstake"
        );
    }

    function test_Staking_VotingPower_ZeroStake() public {
        // Alice has no stake
        advanceTimeAndBlock();

        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        assertEq(
            aliceVotingPower,
            0,
            "Alice should have zero voting power with no stake"
        );

        // Alice should NOT be able to create a proposal
        uint256 proposalThreshold = governorA.proposalThreshold();

        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSignature(
                "SummerGovernorProposerBelowThresholdAndNotGuardian(address,uint256,uint256)",
                alice,
                0,
                proposalThreshold
            )
        );
        createStakingProposal();
        vm.stopPrank();
    }

    function test_Staking_VotingPower_InsufficientBalance() public {
        uint256 stakeAmount = USER_1_STAKE_AMOUNT;
        deal(address(aSummerToken), alice, stakeAmount);
        // Alice tries to stake more than she has
        vm.startPrank(alice);
        aSummerToken.approve(address(aStaking), stakeAmount * 2);

        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientBalance(address,uint256,uint256)",
                alice,
                stakeAmount,
                stakeAmount * 2
            )
        );
        aStaking.stakeLockup(stakeAmount * 2, 0);
        vm.stopPrank();

        // Check that voting power is still zero
        advanceTimeAndBlock();

        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        assertEq(
            aliceVotingPower,
            0,
            "Alice should have zero voting power when staking fails"
        );
    }

    function test_Staking_VotingPower_ConcurrentOperations() public {
        uint256 stakeAmount1 = USER_1_STAKE_AMOUNT;
        uint256 stakeAmount2 = USER_2_STAKE_AMOUNT;
        uint256 stakeAmount3 = USER_3_STAKE_AMOUNT;

        // Multiple users stake concurrently
        stakeAndDelegate(alice, stakeAmount1, true);
        stakeAndDelegate(bob, stakeAmount2, true);
        stakeAndDelegate(charlie, stakeAmount3, true);

        advanceTimeAndBlock();

        // Check all voting powers
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        uint256 bobVotingPower = governorA.getVotes(bob, block.timestamp - 1);
        uint256 charlieVotingPower = governorA.getVotes(
            charlie,
            block.timestamp - 1
        );

        assertEq(
            aliceVotingPower,
            stakeAmount1,
            "Alice should have correct voting power"
        );
        assertEq(
            bobVotingPower,
            stakeAmount2,
            "Bob should have correct voting power"
        );
        assertEq(
            charlieVotingPower,
            stakeAmount3,
            "Charlie should have correct voting power"
        );

        // Create proposal and have all vote
        vm.prank(alice);
        (uint256 proposalId, ) = createStakingProposal();

        advanceTimeForVotingDelay();

        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        vm.prank(bob);
        governorA.castVote(proposalId, 1);

        vm.prank(charlie);
        governorA.castVote(proposalId, 1);

        // Check total votes
        (, uint256 forVotes, ) = governorA.proposalVotes(proposalId);

        assertEq(
            forVotes,
            stakeAmount1 + stakeAmount2 + stakeAmount3,
            "Total votes should equal sum of all voting powers"
        );
    }

    function test_Staking_VotingPower_TimeBasedVoting() public {
        uint256 stakeAmount = USER_1_STAKE_AMOUNT;

        // Alice stakes and delegates
        stakeAndDelegate(alice, stakeAmount, true);

        // Record voting power at different times
        advanceTimeAndBlock();
        uint256 votingPowerT1 = governorA.getVotes(alice, block.timestamp - 1);

        // Advance time significantly
        vm.warp(block.timestamp + 100 days);
        advanceTimeAndBlock();
        uint256 votingPowerT2 = governorA.getVotes(alice, block.timestamp - 1);

        // Voting power should remain the same (no decay in this implementation)
        assertEq(
            votingPowerT1,
            votingPowerT2,
            "Voting power should remain constant over time"
        );

        // Test historical voting power
        uint256 historicalVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 50 days
        );

        assertEq(
            historicalVotingPower,
            stakeAmount,
            "Historical voting power should match staked amount"
        );
    }

    function test_Staking_VotingPower_ProposalLifecycle() public {
        uint256 stakeAmount = governorA.quorum(block.timestamp - 1);
        deal(address(aSummerToken), alice, stakeAmount);

        // Alice stakes enough to meet threshold
        stakeAndDelegate(alice, stakeAmount, true);

        advanceTimeAndBlock();

        // Create proposal
        vm.prank(alice);
        (uint256 proposalId, ) = createStakingProposal();

        advanceTimeForVotingDelay();

        // Vote on proposal
        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        advanceTimeForVotingPeriod();

        // Check proposal state
        IGovernor.ProposalState state = governorA.state(proposalId);
        assertEq(
            uint256(state),
            uint256(IGovernor.ProposalState.Succeeded),
            "Proposal should succeed with Alice's vote"
        );

        // Execute proposal
        vm.prank(alice);
        // Note: Using the stored targets, values, and calldatas from createStakingProposal
        address[] memory targets = new address[](1);
        targets[0] = address(testToken);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            bob,
            1000
        );
        bytes32 descriptionHash = keccak256(
            bytes("Test proposal for staking integration")
        );
        governorA.queue(targets, values, calldatas, descriptionHash);

        advanceTimeForTimelockMinDelay();
        governorA.execute(targets, values, calldatas, descriptionHash);

        // Check final proposal state
        IGovernor.ProposalState finalState = governorA.state(proposalId);
        assertEq(
            uint256(finalState),
            uint256(IGovernor.ProposalState.Executed),
            "Proposal should be executed"
        );
    }

    function test_Staking_VotingPower_QuorumRequirements() public {
        uint256 stakeAmount = USER_1_STAKE_AMOUNT;

        // Alice stakes and creates proposal
        stakeAndDelegate(alice, stakeAmount, true);

        advanceTimeAndBlock();

        vm.prank(alice);
        (uint256 proposalId, ) = createStakingProposal();

        advanceTimeForVotingDelay();

        // Check quorum before voting
        uint256 quorum = governorA.quorum(block.timestamp - 1);
        uint256 aliceVotes = governorA.getVotes(alice, block.timestamp - 1);

        // If Alice's votes meet quorum, proposal can succeed with just her vote
        if (aliceVotes >= quorum) {
            vm.prank(alice);
            governorA.castVote(proposalId, 1);

            advanceTimeForVotingPeriod();

            IGovernor.ProposalState state = governorA.state(proposalId);
            assertEq(
                uint256(state),
                uint256(IGovernor.ProposalState.Succeeded),
                "Proposal should succeed if Alice's votes meet quorum"
            );
        }
    }
}
