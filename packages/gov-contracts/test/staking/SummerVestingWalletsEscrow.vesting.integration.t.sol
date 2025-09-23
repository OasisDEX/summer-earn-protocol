// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Origin, SummerGovernorV2} from "../../src/contracts/SummerGovernorV2.sol";
import {ISummerGovernorErrors} from "../../src/errors/ISummerGovernorErrors.sol";

import {ISummerVestingWallet} from "../../src/interfaces/ISummerVestingWallet.sol";
import {ISummerVestingWalletV2} from "../../src/interfaces/ISummerVestingWalletV2.sol";
import {SummerVestingWallet} from "../../src/contracts/SummerVestingWallet.sol";
import {Test} from "forge-std/Test.sol";
import {SummerVestingWalletsEscrowTestBase} from "../staking/SummerVestingWalletsEscrowTestBase.sol";

import {ISummerVestingWalletsEscrow} from "../../src/interfaces/ISummerVestingWalletsEscrow.sol";
/*
 * @title SummerGovernorTest
 * @dev Test contract for SummerGovernorV2 functionality.
 */
contract SummerGovernorV2VestingTest is SummerVestingWalletsEscrowTestBase {
    // ========================================
    // VESTING GOVERNANCE TESTS
    // ========================================

    function test_VestingWalletVoting_UserHasVestingWallets_ReleasedTokens()
        public
    {
        uint256 directAmount = USER_1_DIRECT_AMOUNT;
        uint256 maliciousAmount = 1 ether;

        // Setup vesting wallets using helper function (don't transfer ownership yet)
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                vestingAmount: USER_1_VESTING_1_AMOUNT,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: _createPerformanceGoals(0, "V1 Test goal"),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false,
                stakeVesting: false
            })
        );

        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: true,
                vestingAmount: USER_1_VESTING_1_AMOUNT,
                cliffAmount: USER_1_VESTING_1_CLIFF_AMOUNT,
                cliffPeriodDays: CLIFF_PERIOD_DAYS,
                performanceGoals: _createPerformanceGoals(
                    USER_1_VESTING_1_PERFORMANCE_GOAL_AMOUNT,
                    "V2 Test goal"
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false,
                stakeVesting: false
            })
        );

        stakeAndGetXSumr(alice, directAmount, true);

        address payable vestingWalletV1 = payable(
            factoryVesting.vestingWallets(alice)
        );
        address payable vestingWalletV2 = payable(
            factoryVestingV2.vestingWallets(alice)
        );

        uint256 vestingWalletV2BalanceBefore = aSummerToken.balanceOf(
            vestingWalletV2
        );

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Check Alice's voting power - should only include direct staking since vesting wallets aren't staked yet
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        uint256 expectedVotingPower = directAmount; // Only direct staking initially

        assertEq(
            aliceVotingPower,
            expectedVotingPower,
            "Alice's voting power should only include direct tokens when vesting wallets are not staked"
        );

        vm.startPrank(alice);
        SummerVestingWallet(vestingWalletV1).transferOwnership(
            address(aStaking)
        );
        SummerVestingWallet(vestingWalletV2).transferOwnership(
            address(aStaking)
        );
        aStaking.stakeVesting(vestingFactories);
        vm.stopPrank();

        // Check Alice and escrow balances before release
        uint aliceBalanceBeforeRelease = aSummerToken.balanceOf(alice);
        uint256 escrowBalanceBeforeRelease = aSummerToken.balanceOf(
            address(aStaking)
        );

        // fast forward past cliff for vesting wallet v2
        vm.warp(block.timestamp + CLIFF_PERIOD_DAYS + 1);

        SummerVestingWallet(vestingWalletV2).release(address(aSummerToken));
        uint256 escrowBalanceAfterRelease = aSummerToken.balanceOf(
            address(aStaking)
        );
        uint256 releasedAmount = escrowBalanceAfterRelease -
            escrowBalanceBeforeRelease;

        // Malicious actor dusts the vesting wallet V2 to try to influence staking/unstaking
        vm.prank(address(timelockA));
        aSummerToken.transfer(vestingWalletV2, maliciousAmount);

        // Check that escrow received the Alice's released cliff amount
        assertEq(
            releasedAmount,
            USER_1_VESTING_1_CLIFF_AMOUNT,
            "Escrow should receive the cliff amount after release"
        );

        // Check that vesting wallets still have their remaining balances
        uint256 vestingWallets1Balance = aSummerToken.balanceOf(
            vestingWalletV1
        );
        uint256 vestingWallets2Balance = aSummerToken.balanceOf(
            vestingWalletV2
        );

        // V2 should have: total (= cliff + vesting + performance goal) - cliff + malicious transfer
        // V1 should have unchanged balance
        assertEq(
            vestingWallets1Balance,
            USER_1_VESTING_1_AMOUNT,
            "V1 vesting wallet should still have its full amount"
        );
        assertEq(
            vestingWallets2Balance,
            USER_1_VESTING_1_AMOUNT +
                USER_1_VESTING_1_PERFORMANCE_GOAL_AMOUNT +
                maliciousAmount,
            "V2 vesting wallet should have total amount + performance goals + malicious transfer"
        );

        vm.startPrank(alice);
        // Approve the total amount of xSUMR to burn (including the previously released cliff amount)
        axSumr.approve(
            address(aStaking),
            USER_1_VESTING_1_AMOUNT +
                USER_1_VESTING_1_AMOUNT +
                USER_1_VESTING_1_PERFORMANCE_GOAL_AMOUNT +
                USER_1_VESTING_1_CLIFF_AMOUNT
        );
        aStaking.unstakeVesting(vestingFactories);
        vm.stopPrank();

        assertEq(
            axSumr.allowance(alice, address(aStaking)),
            0,
            "Alice should have no allowance after unstaking"
        );
        assertEq(
            aSummerToken.balanceOf(alice),
            aliceBalanceBeforeRelease + releasedAmount,
            "Alice should have the released amount of SUMR after unstaking"
        );
        assertEq(
            aSummerToken.balanceOf(address(aStaking)),
            0,
            "Escrow should have no tokens after unstaking"
        );
        assertEq(
            axSumr.balanceOf(alice),
            directAmount,
            "Alice should have only 'direct amount' of xSUMR after unstaking"
        );
        uint vestingWalletV2BalanceAfter = aSummerToken.balanceOf(
            vestingWalletV2
        );
        assertEq(
            vestingWalletV2BalanceBefore -
                SummerVestingWallet(vestingWalletV2).vestedAmount(
                    uint64(block.timestamp)
                ),
            vestingWalletV2BalanceAfter - maliciousAmount,
            "V2 vesting wallet accounting should be correct after unstaking"
        );

        // =============================
        // Re-stake after dusting scenario
        // =============================
        // At this point, dust remains in V2 wallet. Re-staking should mint more xSUMR
        // equal to current vesting wallet balances (including dust), but immediate
        // unstake should not transfer the dust since nothing is or can be released while staked (except vesting schedule).

        // Snapshot balances before re-stake
        uint256 aliceXSumrBeforeRestake = axSumr.balanceOf(alice); // expected to equal directAmount
        assertEq(
            aliceXSumrBeforeRestake,
            directAmount,
            "Alice should have direct amount of xSUMR before re-stake"
        );
        uint256 aliceSumrBeforeRestake = aSummerToken.balanceOf(alice);
        assertEq(
            aliceSumrBeforeRestake,
            aliceBalanceBeforeRelease + releasedAmount,
            "Alice should have the released amount of SUMR before re-stake"
        );

        // Transfer ownership of both wallets back to escrow and stake again
        vm.startPrank(alice);
        SummerVestingWallet(vestingWalletV1).transferOwnership(
            address(aStaking)
        );
        SummerVestingWallet(vestingWalletV2).transferOwnership(
            address(aStaking)
        );
        aStaking.stakeVesting(vestingFactories);
        vm.stopPrank();

        // Verify additional xSUMR minted equals current vesting wallet balances (includes malicious dust)
        uint256 v1CurrentBalance = aSummerToken.balanceOf(vestingWalletV1);
        uint256 v2CurrentBalance = aSummerToken.balanceOf(vestingWalletV2);
        uint256 mintedOnRestake = axSumr.balanceOf(alice) -
            aliceXSumrBeforeRestake;
        uint256 expectedMintOnRestake = v1CurrentBalance + v2CurrentBalance;
        assertEq(
            mintedOnRestake,
            expectedMintOnRestake,
            "Restake should mint xSUMR equal to current vesting wallet balances, including dust"
        );

        // Immediate unstake: should not transfer dust since nothing was released while staked
        vm.startPrank(alice);
        axSumr.approve(address(aStaking), mintedOnRestake);
        aStaking.unstakeVesting(vestingFactories);
        vm.stopPrank();

        // No additional SUMR should be received by Alice on immediate unstake
        assertEq(
            aSummerToken.balanceOf(alice),
            aliceSumrBeforeRestake,
            "Immediate unstake after restake should not transfer unreleased (dusted) SUMR"
        );
        // xSUMR should return to direct-only amount
        assertEq(
            axSumr.balanceOf(alice),
            directAmount,
            "After immediate restake+unstake, Alice should only hold direct xSUMR again"
        );
        // Escrow should again hold no SUMR
        assertEq(
            aSummerToken.balanceOf(address(aStaking)),
            0,
            "Escrow should hold no SUMR after immediate restake+unstake"
        );
    }

    function test_VestingWalletVoting_UserHasVestingWallets() public {
        // Setup: Create vesting wallets for Alice
        uint256 vestingAmount = USER_1_VESTING_1_AMOUNT;
        uint256 directAmount = USER_1_DIRECT_AMOUNT;

        // Setup vesting wallets using helper functions
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                vestingAmount: vestingAmount,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: new ISummerVestingWalletV2.PerformanceGoal[](
                    0
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false,
                stakeVesting: false
            })
        );

        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: true,
                vestingAmount: vestingAmount,
                cliffAmount: USER_1_VESTING_1_CLIFF_AMOUNT,
                cliffPeriodDays: CLIFF_PERIOD_DAYS,
                performanceGoals: _createPerformanceGoals(
                    USER_1_VESTING_1_PERFORMANCE_GOAL_AMOUNT,
                    "Test goal"
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false,
                stakeVesting: false
            })
        );

        stakeAndGetXSumr(alice, directAmount, true);

        address payable vestingWalletV1 = payable(
            factoryVesting.vestingWallets(alice)
        );
        address payable vestingWalletV2 = payable(
            factoryVestingV2.vestingWallets(alice)
        );

        vm.startPrank(alice);
        SummerVestingWallet(vestingWalletV1).transferOwnership(
            address(aStaking)
        );
        SummerVestingWallet(vestingWalletV2).transferOwnership(
            address(aStaking)
        );
        aStaking.stakeVesting(vestingFactories);
        vm.stopPrank();

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Check Alice's voting power includes vesting balances
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        uint256 expectedVotingPower = vestingAmount + // V1 wallet
            vestingAmount + // V2 total vesting
            USER_1_VESTING_1_CLIFF_AMOUNT + // V2 cliff
            USER_1_VESTING_1_PERFORMANCE_GOAL_AMOUNT + // V2 performance goal
            directAmount;

        assertEq(
            aliceVotingPower,
            expectedVotingPower,
            "Alice's voting power should include vesting wallet balances"
        );
    }
    function test_VestingWalletVoting_UserHasOneVestingWallet() public {
        // Setup: Create only one vesting wallet for Alice
        uint256 vestingAmount = USER_1_VESTING_1_AMOUNT;
        uint256 directAmount = USER_1_DIRECT_AMOUNT;

        // Setup vesting wallet using helper function
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                vestingAmount: vestingAmount,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: new ISummerVestingWalletV2.PerformanceGoal[](
                    0
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false,
                stakeVesting: false
            })
        );

        stakeAndGetXSumr(alice, directAmount, true);

        address payable vestingWalletV1 = payable(
            factoryVesting.vestingWallets(alice)
        );

        vm.startPrank(alice);
        SummerVestingWallet(vestingWalletV1).transferOwnership(
            address(aStaking)
        );
        aStaking.stakeVesting(onlyV1VestingFactory);
        vm.stopPrank();

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Check Alice's voting power includes vesting balance
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        uint256 expectedVotingPower = vestingAmount + directAmount;

        assertEq(
            aliceVotingPower,
            expectedVotingPower,
            "Alice's voting power should include single vesting wallet balance"
        );
    }

    function test_VestingWalletVoting_UserHasNoVestingWallets() public {
        uint256 directAmount = USER_1_DIRECT_AMOUNT;
        stakeAndGetXSumr(alice, directAmount, true);

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Check Alice's voting power without vesting wallets
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        assertEq(
            aliceVotingPower,
            directAmount,
            "Alice's voting power should only include direct tokens when no vesting wallets"
        );
    }

    function test_VestingWalletVoting_UserHasEmptyVestingWallets() public {
        // Setup: Create empty vesting wallets for Alice
        uint256 directAmount = USER_1_DIRECT_AMOUNT;

        // Create empty vesting wallet using helper function
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                vestingAmount: 0,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: new ISummerVestingWalletV2.PerformanceGoal[](
                    0
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false,
                stakeVesting: false
            })
        );

        stakeAndGetXSumr(alice, directAmount, true);

        address payable vestingWalletV1 = payable(
            factoryVesting.vestingWallets(alice)
        );

        vm.startPrank(alice);
        SummerVestingWallet(vestingWalletV1).transferOwnership(
            address(aStaking)
        );
        // Note: stakeVesting would revert for empty wallets, but let's test the governor behavior
        vm.stopPrank();

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Check Alice's voting power with empty vesting wallets
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        assertEq(
            aliceVotingPower,
            directAmount,
            "Alice's voting power should only include direct tokens when vesting wallets are empty"
        );
    }

    function test_VestingWalletVoting_MultipleCalls() public {
        // Setup: Create vesting wallets for Alice
        uint256 vestingAmount = USER_1_VESTING_1_AMOUNT;
        uint256 directAmount = USER_1_DIRECT_AMOUNT;

        // Setup vesting wallet using helper function
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                vestingAmount: vestingAmount,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: new ISummerVestingWalletV2.PerformanceGoal[](
                    0
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false,
                stakeVesting: false
            })
        );

        stakeAndGetXSumr(alice, directAmount, true);

        address payable vestingWalletV1 = payable(
            factoryVesting.vestingWallets(alice)
        );

        vm.startPrank(alice);
        SummerVestingWallet(vestingWalletV1).transferOwnership(
            address(aStaking)
        );
        aStaking.stakeVesting(onlyV1VestingFactory);
        vm.stopPrank();

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Check initial voting power
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        uint256 expectedVotingPower = vestingAmount + directAmount;

        assertEq(
            aliceVotingPower,
            expectedVotingPower,
            "Alice's voting power should include vesting wallet balance"
        );

        // Second call to stakeVesting should not add more voting power
        vm.prank(alice);
        vm.expectRevert(
            ISummerVestingWalletsEscrow.Staking_FactoryAlreadyStaked.selector
        );
        aStaking.stakeVesting(onlyV1VestingFactory);

        // Voting power should remain the same
        uint256 aliceVotingPowerAfter = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        assertEq(
            aliceVotingPowerAfter,
            expectedVotingPower,
            "Alice's voting power should remain the same after second staking call"
        );
    }

    function test_VestingWalletVoting_VestingWalletNotOwnedByStaking() public {
        // Setup: Create vesting wallet but don't transfer ownership to staking
        uint256 vestingAmount = USER_1_VESTING_1_AMOUNT;
        uint256 directAmount = USER_1_DIRECT_AMOUNT;

        // Setup vesting wallet using helper function but don't transfer to staking
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                vestingAmount: vestingAmount,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: new ISummerVestingWalletV2.PerformanceGoal[](
                    0
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false,
                stakeVesting: false
            })
        );

        stakeAndGetXSumr(alice, directAmount, true);

        // Don't transfer ownership to staking - keep it with alice
        // Try to stake with vesting - should revert due to ownership
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerVestingWalletsEscrow.Staking_InvalidOwner.selector,
                "Vesting wallet not owned by escrow"
            )
        );
        aStaking.stakeVesting(onlyV1VestingFactory);

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Check Alice's voting power without staked vesting
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        assertEq(
            aliceVotingPower,
            directAmount,
            "Alice's voting power should only include direct tokens when vesting wallet not owned by escrow"
        );
    }

    function test_VestingWalletVoting_MixedOwnedAndUnownedWallets() public {
        // Setup: Create two vesting wallets but only transfer ownership of one to staking
        uint256 vestingAmount1 = USER_1_VESTING_1_AMOUNT;
        uint256 vestingAmount2 = USER_1_VESTING_2_AMOUNT;
        uint256 directAmount = USER_1_DIRECT_AMOUNT;

        // Setup vesting wallets using helper functions - only transfer first to staking
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                vestingAmount: vestingAmount1,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: new ISummerVestingWalletV2.PerformanceGoal[](
                    0
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false,
                stakeVesting: false
            })
        );

        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: true,
                vestingAmount: vestingAmount2,
                cliffAmount: USER_1_VESTING_2_CLIFF_AMOUNT,
                cliffPeriodDays: CLIFF_PERIOD_DAYS,
                performanceGoals: _createPerformanceGoals(
                    USER_1_VESTING_2_PERFORMANCE_GOAL_AMOUNT,
                    "Test goal"
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false,
                stakeVesting: false
            })
        );

        stakeAndGetXSumr(alice, directAmount, true);

        address payable vestingWalletV1 = payable(
            factoryVesting.vestingWallets(alice)
        );

        // Only transfer ownership of the first wallet to staking, leave second wallet unowned
        vm.startPrank(alice);
        SummerVestingWallet(vestingWalletV1).transferOwnership(
            address(aStaking)
        );
        // Note: vestingWalletV2 remains owned by alice, not staking

        // Try to stake with vesting - should revert due to unowned wallet
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_InvalidOwner(string)",
                "Vesting wallet not owned by escrow"
            )
        );
        aStaking.stakeVesting(vestingFactories);
        vm.stopPrank();

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Check Alice's voting power - should only include direct tokens (no vesting wallets staked)
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        assertEq(
            aliceVotingPower,
            directAmount,
            "Alice's voting power should only include direct tokens when vesting wallets are not owned by escrow"
        );
    }

    function test_VestingWalletVoting_ProposalThresholdWithVesting() public {
        // Test that users with vesting wallets can meet proposal thresholds
        uint256 vestingAmount = PROPOSAL_THRESHOLD_TEST_AMOUNT; // Above minimum threshold
        uint256 directAmount = BELOW_THRESHOLD_DIRECT_AMOUNT;

        // Setup vesting wallet using helper function
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                vestingAmount: vestingAmount,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: new ISummerVestingWalletV2.PerformanceGoal[](
                    0
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false,
                stakeVesting: false
            })
        );

        stakeAndGetXSumr(alice, directAmount, true);

        address payable vestingWalletV1 = payable(
            factoryVesting.vestingWallets(alice)
        );

        vm.startPrank(alice);
        SummerVestingWallet(vestingWalletV1).transferOwnership(
            address(aStaking)
        );
        aStaking.stakeVesting(onlyV1VestingFactory);
        vm.stopPrank();

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Check Alice's voting power meets proposal threshold
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        assertGe(
            aliceVotingPower,
            governorA.proposalThreshold(),
            "Alice's voting power should meet proposal threshold with vesting wallets"
        );

        // Alice should be able to create a proposal
        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        assertGt(
            proposalId,
            0,
            "Alice should be able to create a proposal with vesting wallet voting power"
        );
    }

    function test_VestingWalletVoting_BelowProposalThreshold() public {
        // Test that users below proposal threshold cannot create proposals even with vesting
        uint256 vestingAmount = BELOW_THRESHOLD_VESTING_AMOUNT; // Below minimum threshold
        uint256 directAmount = BELOW_THRESHOLD_DIRECT_AMOUNT;

        // Setup vesting wallet using helper function
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                vestingAmount: vestingAmount,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: new ISummerVestingWalletV2.PerformanceGoal[](
                    0
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false,
                stakeVesting: false
            })
        );

        stakeAndGetXSumr(alice, directAmount, true);

        address payable vestingWalletV1 = payable(
            factoryVesting.vestingWallets(alice)
        );

        vm.startPrank(alice);
        SummerVestingWallet(vestingWalletV1).transferOwnership(
            address(aStaking)
        );
        aStaking.stakeVesting(onlyV1VestingFactory);
        vm.stopPrank();

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Check Alice's voting power is below proposal threshold
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        assertLt(
            aliceVotingPower,
            governorA.proposalThreshold(),
            "Alice's voting power should be below proposal threshold"
        );

        // Alice should NOT be able to create a proposal
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSignature(
                "SummerGovernorProposerBelowThresholdAndNotGuardian(address,uint256,uint256)",
                alice,
                aliceVotingPower,
                governorA.proposalThreshold()
            )
        );
        createProposal();
        vm.stopPrank();
    }

    // ========================================
    // VESTING UNSTAKING TESTS
    // ========================================

    function test_UnstakeVesting_VestingWalletNotOwnedByStaking() public {
        // Setup: Create vesting wallet for Alice
        uint256 vestingAmount = USER_1_VESTING_1_AMOUNT;
        uint256 directAmount = USER_1_DIRECT_AMOUNT;

        // Setup vesting wallet using helper function
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                vestingAmount: vestingAmount,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: new ISummerVestingWalletV2.PerformanceGoal[](
                    0
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false,
                stakeVesting: false
            })
        );

        stakeAndGetXSumr(alice, directAmount, true);

        address payable vestingWalletV1 = payable(
            factoryVesting.vestingWallets(alice)
        );

        vm.startPrank(alice);
        SummerVestingWallet(vestingWalletV1).transferOwnership(
            address(aStaking)
        );
        aStaking.stakeVesting(onlyV1VestingFactory);
        vm.stopPrank();

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Check initial voting power includes vesting
        uint256 aliceVotingPowerBefore = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        uint256 expectedVotingPower = vestingAmount + directAmount;
        assertEq(aliceVotingPowerBefore, expectedVotingPower);

        // Change ownership of vesting wallet to someone else (simulating an issue)
        vm.prank(address(aStaking));
        SummerVestingWallet(vestingWalletV1).transferOwnership(bob);

        // Attempt to unstake vesting - should revert due to ownership
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_InvalidOwner(string)",
                "Vesting wallet not owned by escrow"
            )
        );
        aStaking.unstakeVesting(onlyV1VestingFactory);

        // Voting power should remain the same since unstaking failed
        uint256 aliceVotingPowerAfter = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        assertEq(
            aliceVotingPowerAfter,
            expectedVotingPower,
            "Voting power should remain unchanged when unstaking fails"
        );
    }

    function test_UnstakeVesting_MixedOwnedAndUnownedWallets2() public {
        // Setup: Create two vesting wallets for Alice
        uint256 vestingAmount1 = USER_1_VESTING_1_AMOUNT;
        uint256 vestingAmount2 = USER_1_VESTING_2_AMOUNT;
        uint256 directAmount = USER_1_DIRECT_AMOUNT;

        // Setup vesting wallets using helper functions - transfer both to staking
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                vestingAmount: vestingAmount1,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: new ISummerVestingWalletV2.PerformanceGoal[](
                    0
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false,
                stakeVesting: false
            })
        );

        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: true,
                vestingAmount: vestingAmount2,
                cliffAmount: USER_1_VESTING_2_CLIFF_AMOUNT,
                cliffPeriodDays: CLIFF_PERIOD_DAYS,
                performanceGoals: _createPerformanceGoals(
                    USER_1_VESTING_2_PERFORMANCE_GOAL_AMOUNT,
                    "Test goal"
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false,
                stakeVesting: false
            })
        );

        stakeAndGetXSumr(alice, directAmount, true);

        address payable vestingWalletV1 = payable(
            factoryVesting.vestingWallets(alice)
        );
        address payable vestingWalletV2 = payable(
            factoryVestingV2.vestingWallets(alice)
        );

        // Transfer ownership of both wallets to staking and stake
        vm.startPrank(alice);
        SummerVestingWallet(vestingWalletV1).transferOwnership(
            address(aStaking)
        );
        SummerVestingWallet(vestingWalletV2).transferOwnership(
            address(aStaking)
        );
        aStaking.stakeVesting(vestingFactories);
        vm.stopPrank();

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Check initial voting power includes both vesting wallets
        uint256 aliceVotingPowerBefore = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        uint256 expectedVotingPower = vestingAmount1 + // V1 wallet
            vestingAmount2 + // V2 total vesting
            USER_1_VESTING_2_CLIFF_AMOUNT + // V2 cliff
            USER_1_VESTING_2_PERFORMANCE_GOAL_AMOUNT + // V2 performance goal
            directAmount;
        assertEq(aliceVotingPowerBefore, expectedVotingPower);

        // Change ownership of one vesting wallet to someone else (mixed ownership)
        vm.prank(address(aStaking));
        SummerVestingWallet(vestingWalletV1).transferOwnership(bob);

        // Attempt to unstake vesting - should revert due to mixed ownership
        vm.startPrank(alice);
        axSumr.approve(address(aStaking), expectedVotingPower);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerVestingWalletsEscrow.Staking_InvalidOwner.selector,
                "Vesting wallet not owned by escrow"
            )
        );
        aStaking.unstakeVesting(vestingFactories);
        vm.stopPrank();
        // Voting power should remain the same since unstaking failed
        uint256 aliceVotingPowerAfter = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        assertEq(
            aliceVotingPowerAfter,
            expectedVotingPower,
            "Voting power should remain unchanged when unstaking fails due to mixed ownership"
        );
    }

    function test_UnstakeVesting_SuccessfulUnstaking() public {
        // Setup: Create vesting wallet for Alice
        uint256 vestingAmount = USER_1_VESTING_1_AMOUNT;
        uint256 directAmount = USER_1_DIRECT_AMOUNT;

        // Setup vesting wallet using helper function
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                vestingAmount: vestingAmount,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: new ISummerVestingWalletV2.PerformanceGoal[](
                    0
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false,
                stakeVesting: false
            })
        );

        stakeAndGetXSumr(alice, directAmount, true);

        address payable vestingWalletV1 = payable(
            factoryVesting.vestingWallets(alice)
        );

        vm.startPrank(alice);
        SummerVestingWallet(vestingWalletV1).transferOwnership(
            address(aStaking)
        );
        aStaking.stakeVesting(onlyV1VestingFactory);
        vm.stopPrank();

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Check initial voting power includes vesting
        uint256 aliceVotingPowerBefore = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        uint256 expectedVotingPower = vestingAmount + directAmount;
        assertEq(aliceVotingPowerBefore, expectedVotingPower);

        // Successfully unstake vesting
        vm.startPrank(alice);
        axSumr.approve(address(aStaking), expectedVotingPower);
        aStaking.unstakeVesting(onlyV1VestingFactory);
        vm.stopPrank();

        advanceTimeAndBlock();

        // Check voting power after unstaking - should only include direct tokens
        uint256 aliceVotingPowerAfter = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        assertEq(
            aliceVotingPowerAfter,
            directAmount,
            "Voting power should only include direct tokens after unstaking"
        );

        // Verify vesting wallet ownership was transferred back to Alice
        assertEq(
            SummerVestingWallet(vestingWalletV1).owner(),
            alice,
            "Vesting wallet ownership should be transferred back to Alice"
        );
    }

    function test_UnstakeVesting_ValidateVestingFactoryMapping() public {
        // Setup: Create vesting wallets for Alice using both factories
        uint256 vestingAmount1 = USER_1_VESTING_1_AMOUNT;
        uint256 vestingAmount2 = USER_1_VESTING_2_AMOUNT;
        uint256 directAmount = USER_1_DIRECT_AMOUNT;

        // Setup vesting wallets using helper functions - transfer both to staking
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                vestingAmount: vestingAmount1,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: new ISummerVestingWalletV2.PerformanceGoal[](
                    0
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false,
                stakeVesting: false
            })
        );

        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: true,
                vestingAmount: vestingAmount2,
                cliffAmount: USER_1_VESTING_2_CLIFF_AMOUNT,
                cliffPeriodDays: CLIFF_PERIOD_DAYS,
                performanceGoals: _createPerformanceGoals(
                    USER_1_VESTING_2_PERFORMANCE_GOAL_AMOUNT,
                    "Test goal"
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false,
                stakeVesting: false
            })
        );

        stakeAndGetXSumr(alice, directAmount, true);

        address payable vestingWalletV1 = payable(
            factoryVesting.vestingWallets(alice)
        );
        address payable vestingWalletV2 = payable(
            factoryVestingV2.vestingWallets(alice)
        );

        // Transfer ownership and stake
        vm.startPrank(alice);
        SummerVestingWallet(vestingWalletV1).transferOwnership(
            address(aStaking)
        );
        SummerVestingWallet(vestingWalletV2).transferOwnership(
            address(aStaking)
        );
        aStaking.stakeVesting(vestingFactories);
        vm.stopPrank();

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Verify both vesting wallets are owned by staking
        assertEq(
            SummerVestingWallet(vestingWalletV1).owner(),
            address(aStaking),
            "Vesting wallet V1 should be owned by staking after staking"
        );
        assertEq(
            SummerVestingWallet(vestingWalletV2).owner(),
            address(aStaking),
            "Vesting wallet V2 should be owned by staking after staking"
        );
        assertEq(
            aStaking.userStakedVestingFactories(alice).length,
            2,
            "Alice should have 2 staked vesting factories"
        );
        assertEq(
            aStaking.userStakedVestingFactories(alice)[1],
            address(factoryVesting),
            "Alice should have factory V1 in staked vesting factories"
        );
        assertEq(
            aStaking.userStakedVestingFactories(alice)[0],
            address(factoryVestingV2),
            "Alice should have factory V2 in staked vesting factories"
        );
        // Successfully unstake vesting
        vm.startPrank(alice);
        uint256 totalVestingAmount = vestingAmount1 + // V1 wallet
            vestingAmount2 + // V2 total vesting
            USER_1_VESTING_2_CLIFF_AMOUNT + // V2 cliff
            USER_1_VESTING_2_PERFORMANCE_GOAL_AMOUNT; // V2 performance goal
        axSumr.approve(address(aStaking), totalVestingAmount);
        aStaking.unstakeVesting(vestingFactories);
        vm.stopPrank();
        // Verify vesting wallet ownership was transferred back to Alice
        assertEq(
            SummerVestingWallet(vestingWalletV1).owner(),
            alice,
            "Vesting wallet V1 ownership should be transferred back to Alice after unstaking"
        );
        assertEq(
            SummerVestingWallet(vestingWalletV2).owner(),
            alice,
            "Vesting wallet V2 ownership should be transferred back to Alice after unstaking"
        );

        // Verify factory mappings are still correct
        assertEq(
            factoryVesting.vestingWallets(alice),
            vestingWalletV1,
            "Factory V1 should still map Alice to vesting wallet V1"
        );
        assertEq(
            factoryVestingV2.vestingWallets(alice),
            vestingWalletV2,
            "Factory V2 should still map Alice to vesting wallet V2"
        );
        assertEq(
            factoryVesting.vestingWalletOwners(vestingWalletV1),
            alice,
            "Factory V1 should map vesting wallet V1 back to Alice"
        );
        assertEq(
            factoryVestingV2.vestingWalletOwners(vestingWalletV2),
            alice,
            "Factory V2 should map vesting wallet V2 back to Alice"
        );
        assertEq(aStaking.userStakedVestingFactories(alice).length, 0);
    }

    function test_RescueWallet() public {
        // Create a vesting wallet and transfer ownership to staking
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                vestingAmount: USER_1_VESTING_1_AMOUNT,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: _createPerformanceGoals(0, "Rescue test"),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: true,
                stakeVesting: true
            })
        );

        address payable vestingWallet = payable(
            factoryVesting.vestingWallets(alice)
        );
        assertEq(
            SummerVestingWallet(vestingWallet).owner(),
            address(aStaking),
            "Precondition: staking must own vesting wallet"
        );

        // Rescue wallet to a new owner (bob) via governor
        vm.prank(address(timelockA));
        aStaking.rescueWallet(vestingWallet, bob);

        // Ownership transferred to bob
        assertEq(
            SummerVestingWallet(vestingWallet).owner(),
            bob,
            "Vesting wallet should be transferred to new owner"
        );
    }

    function test_RescueWallet_InvalidNewOwner() public {
        // Create a vesting wallet and transfer ownership to staking
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                vestingAmount: USER_1_VESTING_1_AMOUNT,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: _createPerformanceGoals(0, "Rescue test"),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: true,
                stakeVesting: true
            })
        );

        address payable vestingWallet = payable(
            factoryVesting.vestingWallets(alice)
        );

        // Expect revert on zero address new owner
        vm.prank(address(timelockA));
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_InvalidAddress(string)",
                "New owner cannot be zero address"
            )
        );
        aStaking.rescueWallet(vestingWallet, address(0));
    }

    function test_RescueToken() public {
        // Fund staking escrow with SUMMER tokens
        uint256 amount = 1_000 ether;
        vm.prank(address(timelockA));
        aSummerToken.transfer(address(aStaking), amount);
        assertEq(
            aSummerToken.balanceOf(address(aStaking)),
            amount,
            "Precondition: staking holds tokens"
        );

        // Rescue tokens to bob via governor
        vm.prank(address(timelockA));
        aStaking.rescueToken(address(aSummerToken), bob);

        // Entire balance moved from staking to bob
        assertEq(aSummerToken.balanceOf(address(aStaking)), 0);
        assertEq(aSummerToken.balanceOf(bob), amount);
    }

    function test_RescueToken_InvalidToken() public {
        // Expect revert when token address is zero
        vm.prank(address(timelockA));
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_InvalidAddress(string)",
                "Invalid token address"
            )
        );
        aStaking.rescueToken(address(0), bob);
    }

    function test_RescueToken_InvalidToAddress() public {
        // Expect revert when to address is zero
        vm.prank(address(timelockA));
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_InvalidAddress(string)",
                "Invalid to address"
            )
        );
        aStaking.rescueToken(address(aSummerToken), address(0));
    }
}
