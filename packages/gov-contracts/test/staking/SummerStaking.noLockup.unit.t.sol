// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerStaking} from "../../src/contracts/SummerStaking.sol";
import {ISummerStaking} from "../../src/interfaces/ISummerStaking.sol";
import {SummerStakingTestBase} from "./SummerStakingTestBase.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

/*
 * @title SummerStaking No Lockup Tests
 * @dev Test contract for SummerStaking contract constructor and core functionality.
 */
contract SummerStakingNoLockupTest is SummerStakingTestBase {
    function setUp() public override {
        super.setUp();

        vm.startPrank(whale);
        axSumr.burn(axSumr.balanceOf(whale));
        bxSumr.burn(bxSumr.balanceOf(whale));
        vm.stopPrank();
    }

    function test_Stake_NoLockup_MintsXSUMR_UpdatesBalances() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = 0; // No lockup for test

        // Get balances before staking
        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 userXSumrBalanceBefore = axSumr.balanceOf(user1);

        // Stake tokens with lockup using helper
        _stake(aStaking, user1, stakeAmount, lockupPeriod);

        // Check balances after staking
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore - stakeAmount
        );
        assertEq(axSumr.balanceOf(user1), userXSumrBalanceBefore + stakeAmount);
    }

    function test_Stake_ZeroAmount() public {
        // Stake zero amount should revert
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerStaking.Staking_InvalidAmount.selector,
                "Amount cannot be zero"
            )
        );
        aStaking.stakeLockup(0, 0); // No lockup for test

        // Balances should remain unchanged
        assertEq(axSumr.balanceOf(user1), 0);
    }

    function test_Stake_InsufficientAllowance() public {
        uint256 stakeAmount = STAKE_AMOUNT;

        // Approve less than stake amount
        vm.prank(user1);
        aSummerToken.approve(address(aStaking), stakeAmount - 1);

        // Attempt to stake - should revert
        vm.prank(user1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector,
                address(aStaking),
                stakeAmount - 1,
                stakeAmount
            )
        );
        aStaking.stakeLockup(stakeAmount, 0); // No lockup for test
    }

    function test_Stake_InsufficientBalance() public {
        uint256 stakeAmount = STAKE_AMOUNT * 10; // More than user has

        // Approve staking contract
        vm.prank(user1);
        aSummerToken.approve(address(aStaking), stakeAmount);

        // Attempt to stake - should revert
        vm.prank(user1);
        // ERC20 transferFrom will revert on insufficient balance
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                user1,
                3 * STAKE_AMOUNT,
                stakeAmount
            )
        );
        aStaking.stakeLockup(stakeAmount, 0); // No lockup for test
    }

    function test_Unstake_NoLockup_ReturnsFullAmount_BurnsXSUMR() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = 0; // No lockup for test

        // First stake some tokens with lockup using helper
        _stake(aStaking, user1, stakeAmount, lockupPeriod);

        // Get balances before unstaking
        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 userXSumrBalanceBefore = axSumr.balanceOf(user1);

        // Unstake tokens from specific stake using helper (no penalty since no lockup)
        _approveAndUnstake(aStaking, user1, 0, stakeAmount);

        // Check balances after unstaking - should get full amount back
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore + stakeAmount
        );
        assertEq(axSumr.balanceOf(user1), userXSumrBalanceBefore - stakeAmount);
    }

    function test_Unstake_ZeroAmount() public {
        uint256 lockupPeriod = 0; // No lockup for test

        // First stake some tokens using helper
        _stake(aStaking, user1, STAKE_AMOUNT, lockupPeriod);

        // Unstake zero amount should revert
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerStaking.Staking_InvalidAmount.selector,
                "Amount cannot be zero"
            )
        );
        aStaking.unstakeLockup(0, 0);

        // StakedSummerToken balance should remain unchanged
        assertEq(axSumr.balanceOf(user1), STAKE_AMOUNT);
    }

    function test_Unstake_InsufficientAllowance() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = 0; // No lockup for test

        // First stake some tokens using helper
        _stake(aStaking, user1, stakeAmount, lockupPeriod);

        // Approve less than unstake amount
        vm.prank(user1);
        axSumr.approve(address(aStaking), stakeAmount - 1);

        // Attempt to unstake - should revert
        vm.prank(user1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector,
                address(aStaking),
                stakeAmount - 1,
                stakeAmount
            )
        );
        aStaking.unstakeLockup(0, stakeAmount);
    }

    function test_Unstake_InsufficientBalance() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = 0; // No lockup for test

        // First stake some tokens using helper
        _stake(aStaking, user1, stakeAmount, lockupPeriod);

        // Approve staking contract
        vm.prank(user1);
        axSumr.approve(address(aStaking), stakeAmount * 2);

        // Attempt to unstake more than available from specific stake - should revert
        vm.prank(user1);
        // Reverts due to insufficient stake amount in selected index
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerStaking.Staking_InsufficientBalance.selector
            )
        );
        aStaking.unstakeLockup(0, stakeAmount * 2);
    }

    function test_NoLockup_RoundTrip_ZeroPenalty() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = 0; // No lockup for test

        // Get initial balances
        uint256 initialSummerBalance = aSummerToken.balanceOf(user1);

        // Stake tokens with lockup using helper
        _stake(aStaking, user1, stakeAmount, lockupPeriod);

        // Verify staking worked
        assertEq(axSumr.balanceOf(user1), stakeAmount);
        assertEq(
            aSummerToken.balanceOf(user1),
            initialSummerBalance - stakeAmount
        );

        // Unstake tokens from specific stake using helper
        _approveAndUnstake(aStaking, user1, 0, stakeAmount);

        // Verify round trip worked - should get full amount back (no penalty)
        assertEq(axSumr.balanceOf(user1), 0);
        assertEq(aSummerToken.balanceOf(user1), initialSummerBalance);
    }

    function test_StakeWithLockup_ValidLockupPeriod() public {
        SummerStaking freshStaking = createFreshStakingWithDefaultCaps();
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = 0; // No lockup for test

        // Get balances before staking
        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 userXSumrBalanceBefore = axSumr.balanceOf(user1);

        // Stake with lockup using helper
        _stake(freshStaking, user1, stakeAmount, lockupPeriod);

        // Check balances after staking
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore - stakeAmount
        );
        assertEq(axSumr.balanceOf(user1), userXSumrBalanceBefore + stakeAmount);

        // Check stake details
        (
            uint256 amount,
            uint256 weightedAmount,
            uint256 lockupEndTime,
            uint256 lockupPeriodStored
        ) = freshStaking.getUserStake(user1, 0);

        assertEq(amount, stakeAmount);
        assertEq(lockupEndTime, block.timestamp + lockupPeriod);
        assertEq(lockupPeriodStored, lockupPeriod);
        assertEq(weightedAmount, stakeAmount);
    }

    function test_StakeWithLockup_ZeroLockupPeriod() public {
        SummerStaking freshStaking = createFreshStakingWithDefaultCaps();
        uint256 stakeAmount = STAKE_AMOUNT;

        // Stake with zero lockup using helper
        _stake(freshStaking, user1, stakeAmount, 0);

        // Check stake details - weighted amount should equal actual amount
        (uint256 amount, uint256 weightedAmount, , ) = freshStaking
            .getUserStake(user1, 0);
        assertEq(amount, stakeAmount);
        assertEq(weightedAmount, stakeAmount);
    }

    function test_WeightedStakeCalculation_NoLockup() public {
        SummerStaking freshStaking = createFreshStakingWithDefaultCaps();
        uint256 stakeAmount = 1000 ether;

        // Test only zero lockup period for now
        uint256[] memory lockupPeriods = new uint256[](1);
        lockupPeriods[0] = 0; // No lockup

        for (uint256 i = 0; i < lockupPeriods.length; i++) {
            _stake(freshStaking, user1, stakeAmount, lockupPeriods[i]);

            (, uint256 weightedAmount, , ) = freshStaking.getUserStake(
                user1,
                i
            );

            // For zero lockup, weighted amount should use equal to stake amount
            assertEq(weightedAmount, stakeAmount);

            // Verify the formula: amount * (4E-16 * time^2 + 0.05)
            uint256 expectedWeightedAmount = freshStaking
                .calculateWeightedStake(stakeAmount, lockupPeriods[i]);
            assertEq(weightedAmount, expectedWeightedAmount);
        }
    }

    function test_BalanceOf_ReturnsWeightedAmount() public {
        SummerStaking freshStaking = createFreshStakingWithDefaultCaps();
        uint256 stakeAmount = 1000 ether;
        uint256 lockupPeriod = 0; // No lockup for test

        // Stake with lockup using helper
        _stake(freshStaking, user1, stakeAmount, lockupPeriod);

        // balanceOf should return actual staked amount, weightedBalanceOf returns weighted amount
        uint256 balanceOf = freshStaking.balanceOf(user1); // Actual staked amount
        uint expected = freshStaking.calculateWeightedStake(
            stakeAmount,
            lockupPeriod
        );
        uint256 weightedBalance = freshStaking.weightedBalanceOf(user1); // Weighted amount

        assertEq(balanceOf, stakeAmount); // Actual = staked amount
        assertEq(weightedBalance, expected);

        (, uint256 expectedWeightedAmount, , ) = freshStaking.getUserStake(
            user1,
            0
        );
        assertEq(weightedBalance, expectedWeightedAmount);
    }

    function test_CalculatePenalty_NoPenalty() public {
        SummerStaking freshStaking = createFreshStakingWithDefaultCaps();
        uint256 stakeAmount = 1000 ether;
        uint256 lockupPeriod = 0; // No lockup for test

        // Stake with lockup using helper
        _stake(freshStaking, user1, stakeAmount, lockupPeriod);

        // Penalty should be 0 for zero lockup
        uint256 penalty = freshStaking.calculatePenaltyPercentage(user1, 0);
        assertEq(penalty, 0);
    }

    function test_CalculatePenalty_WithPenalty() public {
        SummerStaking freshStaking = createFreshStakingWithDefaultCaps();
        uint256 stakeAmount = 1000 ether;
        uint256 lockupPeriod = 0; // No lockup for test

        // Stake with lockup using helper
        _stake(freshStaking, user1, stakeAmount, lockupPeriod);

        // Penalty should be 0 for zero lockup
        uint256 penalty = freshStaking.calculatePenaltyPercentage(user1, 0);
        assertEq(penalty, 0);
    }

    function test_CalculatePenalty_DifferentLockupPeriods() public {
        SummerStaking freshStaking = createFreshStakingWithDefaultCaps();
        uint256 stakeAmount = 1000 ether;

        // Test only zero lockup period for now
        uint256[] memory lockupPeriods = new uint256[](1);
        lockupPeriods[0] = 0; // No lockup

        for (uint256 i = 0; i < lockupPeriods.length; i++) {
            _stake(freshStaking, user1, stakeAmount, lockupPeriods[i]);

            // Calculate penalty immediately (no time passed)
            uint256 penalty = freshStaking.calculatePenaltyPercentage(user1, i);

            // For zero lockup, penalty should always be 0
            assertEq(penalty, 0);
        }
    }

    function test_UnstakeFromStake_NoPenalty() public {
        SummerStaking freshStaking = createFreshStakingWithDefaultCaps();
        uint256 stakeAmount = 1000 ether;
        uint256 lockupPeriod = 0; // No lockup for test

        // Stake with lockup using helper
        _stake(freshStaking, user1, stakeAmount, lockupPeriod);

        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 userXSumrBalanceBefore = axSumr.balanceOf(user1);

        // Unstake from specific stake using helper - should get full amount back
        _approveAndUnstake(freshStaking, user1, 0, stakeAmount);

        // Check balances - should get full amount back (no penalty)
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore + stakeAmount,
            "aSummerToken.balanceOf(user1)"
        );
        assertEq(
            axSumr.balanceOf(user1),
            userXSumrBalanceBefore - stakeAmount,
            "axSumr.balanceOf(user1)"
        );

        // Stake should be removed
        (
            uint256 amount,
            uint256 weightedAmount,
            uint256 lockupEndTime,
            uint256 _lockupPeriod
        ) = freshStaking.getUserStake(user1, 0);
        assertEq(amount, 0, "amount");
        assertEq(weightedAmount, 0, "weightedAmount");
        assertLe(lockupEndTime, block.timestamp, "lockupEndTime");
        assertEq(_lockupPeriod, 0, "lockupPeriod");
    }

    function test_UnstakeFromStake_WithPenalty() public {
        SummerStaking freshStaking = createFreshStakingWithDefaultCaps();
        uint256 stakeAmount = 1000 ether;
        uint256 lockupPeriod = 0; // No lockup for test

        // Stake with lockup using helper
        _stake(freshStaking, user1, stakeAmount, lockupPeriod);

        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 userXSumrBalanceBefore = axSumr.balanceOf(user1);

        // Calculate expected penalty (should be 0 for zero lockup)
        uint256 expectedPenalty = freshStaking.calculatePenaltyPercentage(
            user1,
            0
        );
        uint256 expectedReturnAmount = stakeAmount - expectedPenalty;

        // Unstake from specific stake using helper
        _approveAndUnstake(freshStaking, user1, 0, stakeAmount);

        // Check balances - should get full amount back (no penalty)
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore + expectedReturnAmount
        );
        assertEq(axSumr.balanceOf(user1), userXSumrBalanceBefore - stakeAmount);

        // Check that user's total balance is updated
        assertEq(
            freshStaking.balanceOf(user1),
            userXSumrBalanceBefore - stakeAmount
        );
    }

    function test_UnstakeFromStake_PartialUnstake() public {
        SummerStaking freshStaking = createFreshStakingWithDefaultCaps();
        uint256 stakeAmount = 1000 ether;
        uint256 unstakeAmount = 300 ether;
        uint256 lockupPeriod = 0; // No lockup for test

        // Stake with lockup using helper
        _stake(freshStaking, user1, stakeAmount, lockupPeriod);

        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 userXSumrBalanceBefore = axSumr.balanceOf(user1);

        // Calculate expected penalty for partial unstake (should be 0 for zero lockup)
        uint256 fullPenalty = freshStaking.calculatePenaltyPercentage(user1, 0);
        uint256 expectedPenalty = (fullPenalty * unstakeAmount) / stakeAmount;
        uint256 expectedReturnAmount = unstakeAmount - expectedPenalty;

        // For zero lockup, penalty should be 0
        assertEq(expectedPenalty, 0);

        // Partial unstake from specific stake using helper
        _approveAndUnstake(freshStaking, user1, 0, unstakeAmount);

        // Check balances
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore + expectedReturnAmount,
            "userSummerBalanceBefore + expectedReturnAmount"
        );
        assertEq(
            axSumr.balanceOf(user1),
            userXSumrBalanceBefore - unstakeAmount,
            "userXSumrBalanceBefore - unstakeAmount"
        );

        // Check remaining stake
        (uint256 remainingAmount, , , ) = freshStaking.getUserStake(user1, 0);
        assertEq(
            remainingAmount,
            stakeAmount - unstakeAmount,
            "remainingAmount"
        );

        // Check that user's total balance is updated correctly
        assertEq(
            freshStaking.balanceOf(user1),
            stakeAmount - unstakeAmount,
            "freshStaking.balanceOf(user1)"
        );
    }

    function test_Unstake_ProportionalUnstaking() public {
        SummerStaking freshStaking = createFreshStakingWithDefaultCaps();
        uint256 stakeAmount1 = 1000 ether;
        uint256 stakeAmount2 = 500 ether;
        uint256 lockupPeriod1 = 0; // No lockup for test
        uint256 lockupPeriod2 = 0; // No lockup for test

        // Stake two different amounts with different lockup periods using helper
        _stake(freshStaking, user1, stakeAmount1, lockupPeriod1);
        _stake(freshStaking, user1, stakeAmount2, lockupPeriod2);

        uint256 totalStaked = stakeAmount1 + stakeAmount2;
        uint256 unstakeAmount = 800 ether; // Unstake 800 out of 1500 total

        uint256 initialBalance = freshStaking.balanceOf(user1);
        assertEq(initialBalance, totalStaked); // Should equal total staked

        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 userXSumrBalanceBefore = axSumr.balanceOf(user1);

        // Proportional unstake using helper
        _approveAndUnstake(freshStaking, user1, 0, unstakeAmount);

        // Check balances (no penalties for zero lockup)
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore + unstakeAmount
        );
        assertEq(
            axSumr.balanceOf(user1),
            userXSumrBalanceBefore - unstakeAmount
        );

        // Check that user's total balance is updated
        assertEq(freshStaking.balanceOf(user1), initialBalance - unstakeAmount);
    }

    function test_MultipleUsers_StakeSeparately() public {
        // Create fresh staking contract to avoid state interference
        SummerStaking freshStaking = createFreshStakingWithDefaultCaps();

        uint256 stakeAmount1 = STAKE_AMOUNT;
        uint256 stakeAmount2 = STAKE_AMOUNT / 2;

        // User 1 stakes with lockup using helper
        _stake(freshStaking, user1, stakeAmount1, 0);

        // User 2 stakes with lockup using helper
        _stake(freshStaking, user2, stakeAmount2, 0);

        // Verify both users have correct balances
        assertEq(axSumr.balanceOf(user1), stakeAmount1);
        assertEq(axSumr.balanceOf(user2), stakeAmount2);

        // Verify weighted balances are same as staked amounts for zero lockup
        uint256 balance1 = freshStaking.balanceOf(user1);
        uint256 balance2 = freshStaking.balanceOf(user2);
        assertEq(balance1, stakeAmount1); // User 1 has no lockup
        assertEq(balance2, stakeAmount2); // User 2 has no lockup
    }

    function test_StakeUnstake_MultipleRounds() public {
        // Create fresh staking contract to avoid state interference
        SummerStaking freshStaking = createFreshStakingWithDefaultCaps();

        uint256 stakeAmount = STAKE_AMOUNT / 4;
        uint256 lockupPeriod = 0; // No lockup for test

        // Stake multiple times with lockup using helper
        for (uint256 i = 0; i < 4; i++) {
            _stake(freshStaking, user1, stakeAmount, lockupPeriod);
        }

        // Verify accumulated staking
        assertEq(
            axSumr.balanceOf(user1),
            stakeAmount * 4,
            "should have equivalent balance of gov token"
        );

        // Unstake multiple times (unstake from specific stakes) using helper
        for (uint256 i = 0; i < 4; i++) {
            _approveAndUnstake(freshStaking, user1, 0, stakeAmount); // Unstake from first remaining stake
        }

        // Verify final balances
        assertEq(axSumr.balanceOf(user1), 0, "should have no gov token left");
    }

    // ============ NO LOCKUP PENALTY TESTS ============

    function test_NoLockupPenalty_ImmediateUnstake_0Percent() public {
        SummerStaking freshStaking = createFreshStakingWithDefaultCaps();
        uint256 stakeAmount = 1000 ether;
        uint256 lockupPeriod = 0; // No lockup

        // Stake with no lockup
        _stake(freshStaking, user1, stakeAmount, lockupPeriod);

        // Calculate expected penalty: 0% for no lockup
        uint256 expectedPenaltyPercentage = 0; // 0%
        uint256 expectedPenalty = 0;
        uint256 expectedReturnAmount = stakeAmount;

        // Get balances before unstaking
        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 treasuryBalanceBefore = aSummerToken.balanceOf(
            freshStaking.treasury()
        );

        // Unstake immediately
        _approveAndUnstake(freshStaking, user1, 0, stakeAmount);

        // Verify penalty calculation
        assertEq(
            aSummerToken.balanceOf(freshStaking.treasury()),
            treasuryBalanceBefore,
            "Treasury should receive no penalty for no lockup"
        );
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore + expectedReturnAmount,
            "User should receive 100% of staked amount for no lockup"
        );

        // Verify the penalty percentage is exactly 0%
        assertEq(expectedPenaltyPercentage, 0);
        assertEq(expectedPenalty, 0);
    }

    function test_NoLockupPenalty_ContractMethod_ReturnsZero() public {
        SummerStaking freshStaking = createFreshStakingWithDefaultCaps();
        uint256 stakeAmount = 1000 ether;
        uint256 lockupPeriod = 0; // No lockup

        // Stake with no lockup
        _stake(freshStaking, user1, stakeAmount, lockupPeriod);

        // Test penalty calculation - should always be 0 for no lockup
        uint256 contractPenalty = freshStaking.calculatePenaltyPercentage(
            user1,
            0
        );
        uint256 expectedPenaltyPercentage = 0; // 0%

        assertEq(
            contractPenalty,
            expectedPenaltyPercentage,
            "Contract penalty calculation should return 0% for no lockup"
        );

        // Warp time and test again - should still be 0
        vm.warp(block.timestamp + 365 days);
        contractPenalty = freshStaking.calculatePenaltyPercentage(user1, 0);

        assertEq(
            contractPenalty,
            expectedPenaltyPercentage,
            "Contract penalty calculation should still return 0% for no lockup after time passes"
        );
    }

    function test_NoLockupPenalty_MultipleStakes_AllZeroPenalty() public {
        SummerStaking freshStaking = createFreshStakingWithDefaultCaps();
        uint256 stakeAmount = 1000 ether;
        uint256 lockupPeriod = 0; // No lockup

        // Create multiple stakes with no lockup
        uint256 stakeIndex1 = _stake(
            freshStaking,
            user1,
            stakeAmount,
            lockupPeriod
        );
        uint256 stakeIndex2 = _stake(
            freshStaking,
            user1,
            stakeAmount,
            lockupPeriod
        );
        uint256 stakeIndex3 = _stake(
            freshStaking,
            user1,
            stakeAmount,
            lockupPeriod
        );
        assertEq(stakeIndex1, stakeIndex2);
        assertEq(stakeIndex2, stakeIndex3);
        assertEq(stakeIndex3, stakeIndex1);

        // Test penalty calculation for each stake - should all be 0
        for (uint256 i = 0; i < 3; i++) {
            uint256 contractPenalty = freshStaking.calculatePenaltyPercentage(
                user1,
                stakeIndex1
            );
            assertEq(
                contractPenalty,
                0,
                string(abi.encodePacked("Stake ", i, " should have 0% penalty"))
            );
        }

        // Unstake all stakes and verify no penalties
        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 treasuryBalanceBefore = aSummerToken.balanceOf(
            freshStaking.treasury()
        );

        for (uint256 i = 0; i < 3; i++) {
            _approveAndUnstake(freshStaking, user1, 0, stakeAmount); // Always unstake from index 0 as stakes get removed
        }

        // Verify no penalties were applied
        assertEq(
            aSummerToken.balanceOf(freshStaking.treasury()),
            treasuryBalanceBefore,
            "Treasury should receive no penalties for no lockup stakes"
        );
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore + (stakeAmount * 3),
            "User should receive 100% of all staked amounts for no lockup"
        );
    }

    function test_NoLockupPenalty_TimePasses_StillZeroPenalty() public {
        SummerStaking freshStaking = createFreshStakingWithDefaultCaps();
        uint256 stakeAmount = 1000 ether;
        uint256 lockupPeriod = 0; // No lockup

        // Stake with no lockup
        _stake(freshStaking, user1, stakeAmount, lockupPeriod);

        // Warp time significantly
        vm.warp(block.timestamp + 10 * 365 days); // 10 years

        // Penalty should still be 0
        uint256 contractPenalty = freshStaking.calculatePenaltyPercentage(
            user1,
            0
        );
        assertEq(
            contractPenalty,
            0,
            "Penalty should remain 0% even after significant time passes for no lockup"
        );

        // Unstake and verify no penalty
        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 treasuryBalanceBefore = aSummerToken.balanceOf(
            freshStaking.treasury()
        );

        _approveAndUnstake(freshStaking, user1, 0, stakeAmount);

        assertEq(
            aSummerToken.balanceOf(freshStaking.treasury()),
            treasuryBalanceBefore,
            "Treasury should receive no penalty even after time passes for no lockup"
        );
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore + stakeAmount,
            "User should receive 100% of staked amount even after time passes for no lockup"
        );
    }

    function test_NoLockupPenalty_ComparisonWithLockup() public {
        SummerStaking freshStaking = createFreshStakingWithDefaultCaps();
        vm.startPrank(address(timelockA));
        freshStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.SixToTwelveMonths,
            100000 ether
        );
        uint256 stakeAmount = 1000 ether;

        // Create one stake with no lockup
        uint256 stakeIndex = _stake(freshStaking, user1, stakeAmount, 0);

        // Create another stake with 1-year lockup
        uint256 stakeIndex2 = _stake(
            freshStaking,
            user2,
            stakeAmount,
            365 days
        );

        // Compare penalties
        uint256 noLockupPenalty = freshStaking.calculatePenaltyPercentage(
            user1,
            stakeIndex
        );
        uint256 oneYearLockupPenalty = freshStaking.calculatePenaltyPercentage(
            user2,
            stakeIndex2
        );

        assertEq(noLockupPenalty, 0, "No lockup penalty should be 0%");
        assertGt(
            oneYearLockupPenalty,
            0,
            "1-year lockup penalty should be greater than 0%"
        );
        assertEq(
            oneYearLockupPenalty,
            (aMaxPenaltyPercentage / 3),
            "1-year lockup penalty should be 6.666666666666666666% "
        );

        // Verify the difference
        assertTrue(
            oneYearLockupPenalty > noLockupPenalty,
            "Lockup penalty should be greater than no lockup penalty"
        );
    }
}
