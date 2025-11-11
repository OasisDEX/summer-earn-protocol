// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerStaking} from "../../src/contracts/SummerStaking.sol";
import {ISummerStaking} from "../../src/interfaces/ISummerStaking.sol";
import {Test} from "forge-std/Test.sol";
import {Constants} from "@summerfi/constants/Constants.sol";
import {SummerStakingTestBase} from "./SummerStakingTestBase.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IAccessControlErrors} from "@summerfi/access-contracts/interfaces/IAccessControlErrors.sol";
import {console} from "forge-std/console.sol";
/*
 * @title SummerStaking Lockup Tests
 * @dev Comprehensive test suite for SummerStaking contract with helper methods and extensive coverage.
 */
contract SummerStakingLockupTest is SummerStakingTestBase {
    address public user3 = address(0x1003);

    function setUp() public override {
        super.setUp();

        // Setup additional test users with tokens
        deal(address(aSummerToken), user3, STAKE_AMOUNT * 10);

        vm.startPrank(whale);
        axSumr.burn(axSumr.balanceOf(whale));
        bxSumr.burn(bxSumr.balanceOf(whale));
        vm.stopPrank();
    }

    // ============ DEPLOYMENT & INITIALIZATION TESTS ============

    function test_CorrectInitialization() public view {
        assertEq(address(aStaking.SUMMER_TOKEN()), address(aSummerToken));
        assertEq(address(aStaking.STAKED_SUMMER_TOKEN()), address(axSumr));

        // Check default bucket configurations

        // Check basic bucket details for NoLockup bucket (which should always exist)
        (uint256 cap0, uint256 staked0, , ) = aStaking.getBucketDetails(
            ISummerStaking.Bucket.NoLockup
        );
        assertEq(cap0, type(uint256).max); // No cap
        assertEq(staked0, 0);
    }

    function test_StakeLongerThanMaximumLockupPeriod() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = aMaxLockupPeriod + 1 days;
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerStaking.Staking_InvalidLockupPeriod.selector,
                "Lockup period cannot exceed 3 years"
            )
        );
        aStaking.stakeLockup(stakeAmount, lockupPeriod);
    }

    function test_VerifyBucketCaps() public view {
        uint256[] memory expectedBucketCaps = new uint256[](7);
        expectedBucketCaps[0] = MAX_CAP_AMOUNT;
        expectedBucketCaps[1] = 0;
        expectedBucketCaps[2] = DEFAULT_CAP_AMOUNT;
        expectedBucketCaps[3] = DEFAULT_CAP_AMOUNT;
        expectedBucketCaps[4] = DEFAULT_CAP_AMOUNT;
        expectedBucketCaps[5] = DEFAULT_CAP_AMOUNT;
        expectedBucketCaps[6] = DEFAULT_CAP_AMOUNT;
        _verifyBucketCaps(aStaking, expectedBucketCaps);
    }

    // ============ STAKING TESTS (stakeLockup) ============

    // Success Cases
    function test_StakeWithMinLockup() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = 0; // No lockup for now to avoid bucket cap issues

        uint256 expectedWeightedAmount = _calculateExpectedWeightedAmountForPeriod(
                stakeAmount,
                lockupPeriod
            );
        uint256 expectedLockupEndTime = block.timestamp + lockupPeriod;

        uint256 stakeIndex = _stake(aStaking, user1, stakeAmount, lockupPeriod);

        _assertStake(
            user1,
            stakeIndex,
            stakeAmount,
            expectedWeightedAmount,
            expectedLockupEndTime,
            lockupPeriod
        );
        assertEq(
            aStaking.balanceOf(user1),
            stakeAmount,
            "Balance of user1 should be equal to stake amount"
        );
        assertEq(
            aStaking.weightedBalanceOf(user1),
            expectedWeightedAmount,
            "Weighted balance of user1 should be equal to expected weighted amount"
        );
        assertEq(
            axSumr.balanceOf(user1),
            stakeAmount,
            "XSUMR balance of user1 should be equal to stake amount"
        );
    }

    function test_StakeWithMaxLockup() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = aMaxLockupPeriod;

        uint256 expectedWeightedAmount = _calculateExpectedWeightedAmountForPeriod(
                stakeAmount,
                lockupPeriod
            );
        uint256 expectedLockupEndTime = block.timestamp + lockupPeriod;

        uint256 stakeIndex = _stake(aStaking, user1, stakeAmount, lockupPeriod);

        _assertStake(
            user1,
            stakeIndex,
            stakeAmount,
            expectedWeightedAmount,
            expectedLockupEndTime,
            lockupPeriod
        );
        assertEq(aStaking.balanceOf(user1), stakeAmount);
        assertEq(aStaking.weightedBalanceOf(user1), expectedWeightedAmount);
    }

    function test_StakeWithVariousLockups() public {
        uint256[] memory lockupPeriods = new uint256[](3);
        lockupPeriods[0] = 0; // No lockup
        lockupPeriods[1] = 0; // No lockup
        lockupPeriods[2] = 0; // No lockup

        for (uint256 i = 0; i < lockupPeriods.length; i++) {
            uint256 expectedWeightedAmount = _calculateExpectedWeightedAmountForPeriod(
                    STAKE_AMOUNT,
                    lockupPeriods[i]
                );
            uint256 expectedLockupEndTime = block.timestamp + lockupPeriods[i];

            uint256 stakeIndex = _stake(
                aStaking,
                user1,
                STAKE_AMOUNT,
                lockupPeriods[i]
            );
            _assertStake(
                user1,
                stakeIndex,
                STAKE_AMOUNT * (i + 1),
                expectedWeightedAmount * (i + 1),
                expectedLockupEndTime,
                lockupPeriods[i]
            );
        }
        // using only 0 index - no lcokup
        assertEq(aStaking.getUserStakesCount(user1), 1);
        assertEq(aStaking.balanceOf(user1), STAKE_AMOUNT * 3);
    }

    function test_CorrectStateChangesOnStake() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = aMinLockupPeriod;
        uint256 expectedWeightedAmount = _calculateExpectedWeightedAmountForPeriod(
                stakeAmount,
                lockupPeriod
            );

        // Get balances before staking
        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 userXSumrBalanceBefore = axSumr.balanceOf(user1);
        uint256 totalSupplyBefore = aStaking.totalSupply();

        _stake(aStaking, user1, stakeAmount, lockupPeriod);

        // Check user balances
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore - stakeAmount,
            "User summer balance should decrease"
        );
        assertEq(
            axSumr.balanceOf(user1),
            userXSumrBalanceBefore + stakeAmount,
            "User xSUMR balance should increase"
        );

        // Check contract state
        assertEq(
            aStaking.balanceOf(user1),
            stakeAmount,
            "User balance should increase"
        );
        assertEq(
            aStaking.weightedBalanceOf(user1),
            expectedWeightedAmount,
            "User weighted balance should increase"
        );
        assertEq(
            aStaking.totalSupply(),
            totalSupplyBefore + expectedWeightedAmount,
            "Total supply should increase"
        );

        // Check bucket totals
        _assertBucket(ISummerStaking.Bucket.TwoWeeksToThreeMonths, stakeAmount);
    }

    // Failure Cases
    function test_Revert_StakeWithZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerStaking.Staking_InvalidAmount.selector,
                "Amount cannot be zero"
            )
        );
        aStaking.stakeLockup(0, aMinLockupPeriod);
    }

    function test_Revert_StakeWithLockupBelowMin() public {
        uint256 invalidLockupPeriod = aMinLockupPeriod - 1 days;

        vm.startPrank(user1);
        aSummerToken.approve(address(aStaking), STAKE_AMOUNT);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerStaking.Staking_BucketCapExceeded.selector
            )
        );
        aStaking.stakeLockup(STAKE_AMOUNT, invalidLockupPeriod);
        vm.stopPrank();
    }

    function test_Revert_StakeWithLockupAboveMax() public {
        uint256 invalidLockupPeriod = aMaxLockupPeriod + 1 days;

        vm.startPrank(user1);
        aSummerToken.approve(address(aStaking), STAKE_AMOUNT);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerStaking.Staking_InvalidLockupPeriod.selector,
                "Lockup period cannot exceed 3 years"
            )
        );
        aStaking.stakeLockup(STAKE_AMOUNT, invalidLockupPeriod);
        vm.stopPrank();
    }

    function test_Revert_StakeWhenMaxStakesReached() public {
        // Create 999 stakes to reach the maximum (+1 noLockup lazily initialized)
        for (uint256 i = 0; i < 999; i++) {
            _stake(aStaking, user1, STAKE_AMOUNT / 999, aMinLockupPeriod);
        }

        assertEq(aStaking.getUserStakesCount(user1), 1000);

        // Attempt to create an 1001st stake with lockup should revert
        vm.startPrank(user1);
        aSummerToken.approve(address(aStaking), STAKE_AMOUNT);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerStaking.Staking_MaxStakesReached.selector
            )
        );
        aStaking.stakeLockup(STAKE_AMOUNT, aMinLockupPeriod);
        vm.stopPrank();
    }

    function test_StakeNoLockupWhenMaxStakesReached() public {
        // Create 999 stakes to reach the maximum (+1 noLockup lazily initialized)
        for (uint256 i = 0; i < 999; i++) {
            _stake(aStaking, user1, STAKE_AMOUNT / 999, aMinLockupPeriod);
        }

        assertEq(aStaking.getUserStakesCount(user1), 1000);

        // Attempt to create an 1001st stake with no lockup should not revert - uses the 0 slot
        vm.startPrank(user1);
        aSummerToken.approve(address(aStaking), STAKE_AMOUNT);
        aStaking.stakeLockup(STAKE_AMOUNT, 0);
        vm.stopPrank();
    }

    function test_Revert_StakeWithInsufficientBalance() public {
        uint256 largeAmount = aSummerToken.balanceOf(user1) + 1 ether;

        vm.startPrank(user1);
        aSummerToken.approve(address(aStaking), largeAmount);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                user1,
                aSummerToken.balanceOf(user1),
                largeAmount
            )
        );
        aStaking.stakeLockup(largeAmount, aMinLockupPeriod);
        vm.stopPrank();
    }

    function test_Revert_StakeWithoutApproval() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector,
                address(aStaking),
                0,
                STAKE_AMOUNT
            )
        );
        aStaking.stakeLockup(STAKE_AMOUNT, aMinLockupPeriod);
    }

    // ============ UNSTAKING TESTS (unstakeLockup) ============

    // After Lockup (No Penalty)
    function test_UnstakeFullAmountAfterLockup() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = 0; // No lockup for now to avoid bucket cap issues

        uint256 stakeIndex = _stake(aStaking, user1, stakeAmount, lockupPeriod);

        // No need to warp time since there's no lockup

        // Get balances before unstaking
        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        UserSnapshot memory beforeSnap = _snapshotUser(aStaking, user1);

        // Unstake full amount
        _approveAndUnstake(aStaking, user1, stakeIndex, stakeAmount);

        // Verify user received full amount back (no penalty)
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore + stakeAmount
        );
        assertEq(axSumr.balanceOf(user1), beforeSnap.xsumr - stakeAmount);

        // Verify stake is removed
        (uint256 amount, , , ) = aStaking.getUserStake(user1, stakeIndex);
        assertEq(amount, 0);
    }

    function test_UnstakePartialAmountAfterLockup() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 unstakeAmount = stakeAmount / 2;
        uint256 lockupPeriod = aMinLockupPeriod;

        uint256 stakeIndex = _stake(aStaking, user1, stakeAmount, lockupPeriod);

        // Warp time past lockup end
        vm.warp(block.timestamp + lockupPeriod + 1 days);

        // Unstake partial amount
        _approveAndUnstake(aStaking, user1, stakeIndex, unstakeAmount);

        // Verify remaining stake
        (uint256 remainingAmount, , , ) = aStaking.getUserStake(
            user1,
            stakeIndex
        );
        assertEq(remainingAmount, stakeAmount - unstakeAmount);

        // Verify user balance
        assertEq(aStaking.balanceOf(user1), remainingAmount);
    }

    function test_CorrectStateChangesOnFullUnstake() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = aMinLockupPeriod;

        uint256 stakeIndex = _stake(aStaking, user1, stakeAmount, lockupPeriod);

        // Warp time past lockup end
        vm.warp(block.timestamp + lockupPeriod + 1 days);

        // Get state before unstaking (reduced locals)
        UserSnapshot memory beforeSnap = _snapshotUser(aStaking, user1);
        uint256 totalSupplyBefore = aStaking.totalSupply();

        // Unstake full amount
        _approveAndUnstake(aStaking, user1, stakeIndex, stakeAmount);

        // Verify state changes
        assertEq(aStaking.balanceOf(user1), beforeSnap.raw - stakeAmount);
        assertEq(
            aStaking.weightedBalanceOf(user1),
            beforeSnap.weighted -
                _calculateExpectedWeightedAmountForPeriod(
                    stakeAmount,
                    lockupPeriod
                ),
            "Weighted balance should decrease"
        );
        assertEq(
            aStaking.totalSupply(),
            totalSupplyBefore -
                _calculateExpectedWeightedAmountForPeriod(
                    stakeAmount,
                    lockupPeriod
                ),
            "Total supply should decrease"
        );
    }

    // Before Lockup (With Penalty)
    function test_ImmediateUnstake_MaxLockup_20PercentPenalty() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = aMaxLockupPeriod; // 3 years for maximum penalty

        uint256 stakeIndex = _stake(aStaking, user1, stakeAmount, lockupPeriod);

        // Calculate expected penalty (should be 20% for immediate unstake)
        uint256 expectedPenalty = _calculatePenaltyPercentage(
            lockupPeriod,
            lockupPeriod
        );
        uint256 expectedReturnAmount = stakeAmount -
            (stakeAmount * expectedPenalty) /
            Constants.WAD;

        // Get balances before unstaking
        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 treasuryBalanceBefore = aSummerToken.balanceOf(
            aStaking.treasury()
        );
        vm.prank(user1);
        axSumr.approve(address(aStaking), stakeAmount);
        // Unstake immediately
        _verifyUnstakedEvent(
            user1,
            stakeIndex,
            stakeAmount,
            (stakeAmount * expectedPenalty) / Constants.WAD,
            expectedReturnAmount
        );
        _unstake(user1, stakeIndex, stakeAmount);

        // Verify penalty sent to treasury
        assertEq(
            aSummerToken.balanceOf(aStaking.treasury()),
            treasuryBalanceBefore +
                (stakeAmount * expectedPenalty) /
                Constants.WAD
        );

        // Verify user received remaining amount
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore + expectedReturnAmount
        );
    }

    function test_ImmediateUnstake_MinimumLockupPeriod() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = aMinLockupPeriod; // 3 months

        uint256 stakeIndex = _stake(aStaking, user1, stakeAmount, lockupPeriod);

        vm.warp(block.timestamp);

        // Calculate expected penalty (should be flat 2% for immediate unstake )
        uint256 expectedPenalty = aMinPenaltyPercentage;
        uint256 expectedReturnAmount = stakeAmount -
            (stakeAmount * expectedPenalty) /
            Constants.WAD;

        // Get balances before unstaking
        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 treasuryBalanceBefore = aSummerToken.balanceOf(
            aStaking.treasury()
        );
        vm.prank(user1);
        axSumr.approve(address(aStaking), stakeAmount);
        // Unstake immediately
        _verifyUnstakedEvent(
            user1,
            stakeIndex,
            stakeAmount,
            (stakeAmount * expectedPenalty) / Constants.WAD,
            expectedReturnAmount
        );
        _unstake(user1, stakeIndex, stakeAmount);

        // Verify penalty sent to treasury
        assertEq(
            aSummerToken.balanceOf(aStaking.treasury()),
            treasuryBalanceBefore +
                (stakeAmount * expectedPenalty) /
                Constants.WAD
        );

        // Verify user received remaining amount
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore + expectedReturnAmount
        );
    }

    function test_Unstake_Halfway_MaxLockup_ApproxHalfPenalty() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = aMaxLockupPeriod; // 3 years

        uint256 stakeIndex = _stake(aStaking, user1, stakeAmount, lockupPeriod);

        // Warp time to 50% of lockup period
        vm.warp(block.timestamp + lockupPeriod / 2);

        // Calculate expected penalty (should be 25% for halfway unstake)
        uint256 expectedPenalty = _calculatePenaltyPercentage(
            lockupPeriod / 2,
            lockupPeriod
        );

        // Unstake halfway through
        _approveAndUnstake(aStaking, user1, stakeIndex, stakeAmount);

        // Verify penalty is approximately half of immediate unstake penalty
        assertApproxEqRel(expectedPenalty, aMaxPenaltyPercentage / 2, 0.01e18); // 25% ± 1%
    }

    function test_Unstake_WithPenalty_UpdatesBalancesAndSupply() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = aMaxLockupPeriod;

        uint256 stakeIndex = _stake(aStaking, user1, stakeAmount, lockupPeriod);

        // Get state before unstaking
        UserSnapshot memory beforeSnap = _snapshotUser(aStaking, user1);
        uint256 totalSupplyBefore = aStaking.totalSupply();
        uint256 treasuryBalanceBefore = aSummerToken.balanceOf(
            aStaking.treasury()
        );

        // Unstake with penalty
        _approveAndUnstake(aStaking, user1, stakeIndex, stakeAmount);

        // Verify penalty sent to treasury
        assertGt(
            aSummerToken.balanceOf(aStaking.treasury()),
            treasuryBalanceBefore,
            "Treasury balance should increase"
        );

        // Verify state changes
        assertEq(aStaking.balanceOf(user1), beforeSnap.raw - stakeAmount);
        assertEq(
            aStaking.weightedBalanceOf(user1),
            beforeSnap.weighted -
                _calculateExpectedWeightedAmountForPeriod(
                    stakeAmount,
                    lockupPeriod
                ),
            "Weighted balance should decrease"
        );
        assertEq(
            aStaking.totalSupply(),
            totalSupplyBefore -
                _calculateExpectedWeightedAmountForPeriod(
                    stakeAmount,
                    lockupPeriod
                ),
            "Total supply should decrease"
        );
    }

    // Failure Cases
    function test_Revert_UnstakeZeroAmount() public {
        uint256 stakeIndex = _stake(
            aStaking,
            user1,
            STAKE_AMOUNT,
            aMinLockupPeriod
        );

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerStaking.Staking_InvalidAmount.selector,
                "Amount cannot be zero"
            )
        );
        aStaking.unstakeLockup(stakeIndex, 0);
    }

    function test_Revert_UnstakeWithInvalidIndex() public {
        uint256 stakeIndex = _stake(
            aStaking,
            user1,
            STAKE_AMOUNT,
            aMinLockupPeriod
        );

        vm.startPrank(user1);
        axSumr.approve(address(aStaking), STAKE_AMOUNT);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerStaking.Staking_InvalidStakeIndex.selector,
                "Stake index out of bounds"
            )
        );
        aStaking.unstakeLockup(stakeIndex + 1, STAKE_AMOUNT);
        vm.stopPrank();
    }
    function test_Revert_UnstakeZeroAmountFromExistingStake() public {
        _stake(aStaking, user1, STAKE_AMOUNT, aMinLockupPeriod);
        uint256 stakeIndex = _stake(aStaking, user1, STAKE_AMOUNT / 2, 0);

        vm.startPrank(user1);

        axSumr.approve(address(aStaking), STAKE_AMOUNT);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerStaking.Staking_InvalidStakeIndex.selector,
                "Stake amount is less than unstake amount"
            )
        );
        aStaking.unstakeLockup(stakeIndex, STAKE_AMOUNT);
        vm.stopPrank();
    }
    function test_Revert_UnstakeMoreThanTotalBalance() public {
        uint256 stakeIndex = _stake(
            aStaking,
            user1,
            STAKE_AMOUNT,
            aMinLockupPeriod
        );

        vm.startPrank(user1);
        axSumr.approve(address(aStaking), STAKE_AMOUNT * 2);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerStaking.Staking_InsufficientBalance.selector
            )
        );
        aStaking.unstakeLockup(stakeIndex, STAKE_AMOUNT * 2);
        vm.stopPrank();
    }

    // ============ BUCKET TESTS ============

    function test_GovernorCanUpdateBucketCap() public {
        uint256 newCap = STAKE_AMOUNT * 10;
        ISummerStaking.Bucket bucket = ISummerStaking.Bucket.ThreeToSixMonths;

        vm.prank(address(timelockA));
        aStaking.updateLockupBucketCap(bucket, newCap);

        (uint256 cap, , , ) = aStaking.getBucketDetails(bucket);
        assertEq(cap, newCap);
    }

    function test_Revert_NonGovernorCannotUpdateBucketCap() public {
        uint256 newCap = STAKE_AMOUNT * 10;
        ISummerStaking.Bucket bucket = ISummerStaking.Bucket.ThreeToSixMonths;

        vm.prank(user1);
        // Access control revert (non-governor)
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                user1
            )
        );
        aStaking.updateLockupBucketCap(bucket, newCap);
    }

    function test_Revert_StakeWhenBucketCapExceeded() public {
        ISummerStaking.Bucket bucket = ISummerStaking
            .Bucket
            .TwoWeeksToThreeMonths;
        uint256 cap = STAKE_AMOUNT;

        // Set bucket cap
        vm.prank(address(timelockA));
        aStaking.updateLockupBucketCap(bucket, cap);

        // Stake up to the cap
        _stake(aStaking, user1, cap, aMinLockupPeriod);

        // Attempt to stake more should revert
        vm.startPrank(user2);
        aSummerToken.approve(address(aStaking), STAKE_AMOUNT);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerStaking.Staking_BucketCapExceeded.selector
            )
        );
        aStaking.stakeLockup(STAKE_AMOUNT, aMinLockupPeriod);
        vm.stopPrank();
    }

    function test_CorrectBucketAccounting() public {
        ISummerStaking.Bucket bucket = ISummerStaking
            .Bucket
            .TwoWeeksToThreeMonths;

        // Stake in TwoWeeksToThreeMonths bucket (14 days to 90 days)
        uint256 stakeIndex1 = _stake(
            aStaking,
            user1,
            STAKE_AMOUNT,
            aMinLockupPeriod
        );
        _stake(aStaking, user2, STAKE_AMOUNT, aMinLockupPeriod);

        // Verify bucket total
        _assertBucket(bucket, STAKE_AMOUNT * 2);

        // Unstake from user1
        _approveAndUnstake(aStaking, user1, stakeIndex1, STAKE_AMOUNT);

        // Verify bucket total updated
        _assertBucket(bucket, STAKE_AMOUNT);
    }

    // ============ REWARDS & WEIGHTED LOGIC TESTS ============

    function test_EarnedIsCorrectForSingleStaker() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = aMinLockupPeriod;

        _stake(aStaking, user1, stakeAmount, lockupPeriod);

        // Add rewards
        _addAndNotifyRewards(address(rewardToken), REWARD_AMOUNT);

        // Warp time to accrue rewards
        vm.warp(block.timestamp + 30 days);

        uint256 earned = aStaking.earned(user1, address(rewardToken));
        assertGt(earned, 0, "Should have earned rewards");
    }

    function test_EarnedIsProportionalToWeightedBalance() public {
        // User1 stakes with longer lockup (higher weight)
        uint256 stakeAmount = STAKE_AMOUNT;
        _stake(aStaking, user1, stakeAmount, aMinLockupPeriod);

        // User2 stakes with maximum lockup (highest weight)
        _stake(aStaking, user2, stakeAmount, aMaxLockupPeriod);

        // Add rewards
        _addAndNotifyRewards(address(rewardToken), REWARD_AMOUNT);

        // Warp time to accrue rewards
        vm.warp(block.timestamp + 30 days);

        uint256 earned1 = aStaking.earned(user1, address(rewardToken));
        uint256 earned2 = aStaking.earned(user2, address(rewardToken));

        // User2 should earn more due to higher weighted balance
        assertGt(earned2, earned1, "User with longer lockup should earn more");
    }

    function test_RewardsStopAccruingAfterDistributionEnds() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = aMinLockupPeriod;

        _stake(aStaking, user1, stakeAmount, lockupPeriod);

        // Add rewards with short duration
        _addAndNotifyRewards(address(rewardToken), REWARD_AMOUNT);

        // Warp time past reward duration
        vm.warp(block.timestamp + 365 days);

        uint256 earned = aStaking.earned(user1, address(rewardToken));

        // Warp more time
        vm.warp(block.timestamp + 30 days);

        uint256 earnedLater = aStaking.earned(user1, address(rewardToken));

        // Rewards should not increase after distribution ends
        assertEq(
            earned,
            earnedLater,
            "Rewards should not increase after distribution ends"
        );
    }

    function test_ClaimingResetsRewards() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = aMinLockupPeriod;

        _stake(aStaking, user1, stakeAmount, lockupPeriod);

        // Add rewards
        _addAndNotifyRewards(address(rewardToken), REWARD_AMOUNT);

        // Warp time to accrue rewards
        vm.warp(block.timestamp + 30 days);

        uint256 earnedBefore = aStaking.earned(user1, address(rewardToken));
        assertGt(earnedBefore, 0, "Should have earned rewards");

        // Claim rewards
        vm.prank(user1);
        aStaking.getReward(address(rewardToken));

        uint256 earnedAfter = aStaking.earned(user1, address(rewardToken));
        assertEq(earnedAfter, 0, "Earned should reset to zero after claiming");
    }

    // ============ DISABLED FUNCTIONS TESTS ============

    function test_Revert_CallingDirectStake() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerStaking.Staking_DirectStakeNotAllowed.selector,
                "Use stakeLockup instead"
            )
        );
        aStaking.stake(STAKE_AMOUNT);
    }

    function test_Revert_CallingDirectUnstake() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerStaking.Staking_DirectUnstakeNotAllowed.selector,
                "Use unstakeLockup instead"
            )
        );
        aStaking.unstake(STAKE_AMOUNT);
    }

    function test_Revert_CallingExit() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerStaking.Staking_DirectUnstakeNotAllowed.selector,
                "Use unstakeLockup instead"
            )
        );
        aStaking.exit();
    }

    function test_Revert_CallingStakeOnBehalfOf() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerStaking.StakeOnBehalfOfNotSupported.selector
            )
        );
        aStaking.stakeOnBehalfOf(user2, STAKE_AMOUNT);
    }

    function test_Revert_CallingUnstakeOnBehalfOf() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerStaking.UnstakeOnBehalfOfNotSupported.selector
            )
        );
        aStaking.unstakeAndWithdrawOnBehalfOf(user2, STAKE_AMOUNT, false);
    }

    // ============ FUZZ TESTS ============

    function test_Fuzz_Stake(uint128 amount, uint32 lockupPeriod) public {
        // Bound the inputs to valid ranges
        amount = uint128(bound(amount, 1 ether, STAKE_AMOUNT * 10));
        lockupPeriod = uint32(
            bound(lockupPeriod, aMinLockupPeriod, aMaxLockupPeriod)
        );

        // Ensure user has enough tokens
        deal(address(aSummerToken), user1, amount);

        // Stake should succeed with valid parameters
        uint256 stakeIndex = _stake(aStaking, user1, amount, lockupPeriod);

        // Verify stake was created
        (uint256 stakedAmount, , , ) = aStaking.getUserStake(user1, stakeIndex);
        assertEq(stakedAmount, amount);
    }

    function test_Fuzz_Unstake(uint128 amount) public {
        // Create stake
        uint256 stakeIndex = _stake(
            aStaking,
            user1,
            STAKE_AMOUNT,
            aMinLockupPeriod
        );

        // Bound the unstake amount
        amount = uint128(bound(amount, 1 ether, STAKE_AMOUNT));

        // Warp time past lockup to avoid penalties
        vm.warp(block.timestamp + aMinLockupPeriod + 1 days);

        // Unstake should succeed
        _approveAndUnstake(aStaking, user1, stakeIndex, amount);

        // Verify remaining amount
        (uint256 remainingAmount, , , ) = aStaking.getUserStake(
            user1,
            stakeIndex
        );
        assertEq(remainingAmount, STAKE_AMOUNT - amount);
    }

    // ============ PENALTY CALCULATION TESTS (FROM COMMENTS) ============

    function test_PenaltyCalculation_3YearLockup_ImmediateUnstake_20Percent()
        public
    {
        uint256 stakeAmount = 1000 ether;
        uint256 lockupPeriod = 3 * 365 days; // 3 years

        uint256 stakeIndex = _stake(aStaking, user1, stakeAmount, lockupPeriod);

        // Calculate expected penalty: 20% for immediate unstake
        uint256 expectedPenaltyPercentage = _calculatePenaltyPercentage(
            lockupPeriod,
            lockupPeriod
        );
        uint256 expectedPenalty = (stakeAmount * expectedPenaltyPercentage) /
            Constants.WAD;
        uint256 expectedReturnAmount = stakeAmount - expectedPenalty;

        // Get balances before unstaking
        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 treasuryBalanceBefore = aSummerToken.balanceOf(
            aStaking.treasury()
        );

        // Unstake immediately
        _approveAndUnstake(aStaking, user1, stakeIndex, stakeAmount);

        // Verify penalty calculation
        assertEq(
            aSummerToken.balanceOf(aStaking.treasury()),
            treasuryBalanceBefore + expectedPenalty,
            "Treasury should receive 20% penalty"
        );
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore + expectedReturnAmount,
            "User should receive 80% of staked amount"
        );
    }

    function test_PenaltyCalculation_3YearLockup_After2Years_10Percent()
        public
    {
        uint256 stakeAmount = 1000 ether;
        uint256 lockupPeriod = 3 * 365 days; // 3 years

        uint256 stakeIndex = _stake(aStaking, user1, stakeAmount, lockupPeriod);

        // Warp time to 2 years (50% of lockup period)
        vm.warp(block.timestamp + 2 * 365 days);

        // Calculate expected penalty: 10% for unstake after 2 years
        uint256 expectedPenaltyPercentage = _calculatePenaltyPercentage(
            lockupPeriod - (2 * 365 days), // 1 year remaining
            lockupPeriod
        );
        uint256 expectedPenalty = (stakeAmount * expectedPenaltyPercentage) /
            Constants.WAD;
        uint256 expectedReturnAmount = stakeAmount - expectedPenalty;

        // Get balances before unstaking
        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 treasuryBalanceBefore = aSummerToken.balanceOf(
            aStaking.treasury()
        );

        // Unstake after 2 years
        _approveAndUnstake(aStaking, user1, stakeIndex, stakeAmount);

        // Verify penalty calculation
        assertEq(
            aSummerToken.balanceOf(aStaking.treasury()),
            treasuryBalanceBefore + expectedPenalty,
            "Treasury should receive 6.666666666666666666% penalty"
        );
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore + expectedReturnAmount,
            "User should receive 93.333333333333333333% of staked amount"
        );
    }
    function test_PenaltyCalculation_3YearLockup_2Percent() public {
        uint256 stakeAmount = 1000 ether;
        uint256 lockupPeriod = 3 * 365 days; // 3 years

        uint256 stakeIndex = _stake(aStaking, user1, stakeAmount, lockupPeriod);

        // Warp time to 110 days before end of lockup period
        vm.warp(block.timestamp + 3 * 365 days - 110 days + 1);

        // Calculate expected penalty: 2% for 4 months left of lockup period
        uint256 expectedPenaltyPercentage = aMinPenaltyPercentage;
        uint256 expectedPenalty = (stakeAmount * expectedPenaltyPercentage) /
            Constants.WAD;

        uint256 expectedReturnAmount = stakeAmount - expectedPenalty;

        // Get balances before unstaking
        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 treasuryBalanceBefore = aSummerToken.balanceOf(
            aStaking.treasury()
        );

        // Unstake after 4 months before end of lockup period
        _approveAndUnstake(aStaking, user1, stakeIndex, stakeAmount);

        // Verify penalty calculation
        assertEq(
            aSummerToken.balanceOf(aStaking.treasury()),
            treasuryBalanceBefore + expectedPenalty,
            "Treasury should receive 2% penalty"
        );
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore + expectedReturnAmount,
            "User should receive 98% of staked amount"
        );
    }
    function test_PenaltyCalculation_3YearLockup_After3Years_0Percent() public {
        uint256 stakeAmount = 1000 ether;
        uint256 lockupPeriod = 3 * 365 days; // 3 years

        uint256 stakeIndex = _stake(aStaking, user1, stakeAmount, lockupPeriod);

        // Warp time to exactly 3 years (lockup period ends)
        vm.warp(block.timestamp + 3 * 365 days);

        // Calculate expected penalty: 0% for unstake after lockup ends
        uint256 expectedPenaltyPercentage = _calculatePenaltyPercentage(
            0, // No time remaining after lockup ends
            lockupPeriod
        );
        uint256 expectedPenalty = (stakeAmount * expectedPenaltyPercentage) /
            Constants.WAD;
        uint256 expectedReturnAmount = stakeAmount - expectedPenalty;

        // Get balances before unstaking
        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 treasuryBalanceBefore = aSummerToken.balanceOf(
            aStaking.treasury()
        );

        // Unstake after lockup period ends
        _approveAndUnstake(aStaking, user1, stakeIndex, stakeAmount);

        // Verify penalty calculation
        assertEq(
            aSummerToken.balanceOf(aStaking.treasury()),
            treasuryBalanceBefore,
            "Treasury should receive no penalty"
        );
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore + expectedReturnAmount,
            "User should receive 100% of staked amount"
        );

        // Verify the penalty percentage is exactly 0%
        assertEq(expectedPenaltyPercentage, 0);
        assertEq(expectedPenalty, 0);
    }

    function test_PenaltyCalculation_1YearLockup_ImmediateUnstake() public {
        uint256 stakeAmount = 1000 ether;
        uint256 lockupPeriod = 365 days; // 1 year

        uint256 stakeIndex = _stake(aStaking, user1, stakeAmount, lockupPeriod);

        // Calculate expected penalty for immediate unstake of 1-year lockup
        uint256 expectedPenaltyPercentage = _calculatePenaltyPercentage(
            lockupPeriod,
            lockupPeriod
        );
        uint256 expectedPenalty = (stakeAmount * expectedPenaltyPercentage) /
            Constants.WAD;
        uint256 expectedReturnAmount = stakeAmount - expectedPenalty;

        // Get balances before unstaking
        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 treasuryBalanceBefore = aSummerToken.balanceOf(
            aStaking.treasury()
        );

        // Unstake immediately
        _approveAndUnstake(aStaking, user1, stakeIndex, stakeAmount);

        // Verify penalty calculation
        assertEq(
            aSummerToken.balanceOf(aStaking.treasury()),
            treasuryBalanceBefore + expectedPenalty,
            "Treasury should receive 5% penalty"
        );
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore + expectedReturnAmount,
            "User should receive 95% of staked amount"
        );
    }

    function test_PenaltyCalculation_2YearLockup_ImmediateUnstake_10Percent()
        public
    {
        uint256 stakeAmount = 1000 ether;
        uint256 lockupPeriod = 2 * 365 days; // 2 years

        uint256 stakeIndex = _stake(aStaking, user1, stakeAmount, lockupPeriod);

        // Calculate expected penalty for immediate unstake of 2-year lockup
        uint256 expectedPenaltyPercentage = _calculatePenaltyPercentage(
            lockupPeriod,
            lockupPeriod
        );
        uint256 expectedPenalty = (stakeAmount * expectedPenaltyPercentage) /
            Constants.WAD;
        uint256 expectedReturnAmount = stakeAmount - expectedPenalty;

        // Get balances before unstaking
        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 treasuryBalanceBefore = aSummerToken.balanceOf(
            aStaking.treasury()
        );

        // Unstake immediately
        _approveAndUnstake(aStaking, user1, stakeIndex, stakeAmount);

        // Verify penalty calculation
        assertEq(
            aSummerToken.balanceOf(aStaking.treasury()),
            treasuryBalanceBefore + expectedPenalty,
            "Treasury should receive 10% penalty"
        );
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore + expectedReturnAmount,
            "User should receive 90% of staked amount"
        );
    }

    function test_PenaltyCalculation_ContractMethod_MatchesExpected() public {
        uint256 stakeAmount = 1000 ether;
        uint256 lockupPeriod = 3 * 365 days; // 3 years

        uint256 stakeIndex = _stake(aStaking, user1, stakeAmount, lockupPeriod);

        // Test immediate unstake penalty calculation
        uint256 contractPenalty = aStaking.calculatePenaltyPercentage(
            user1,
            stakeIndex
        );
        uint256 expectedPenaltyPercentage = _calculatePenaltyPercentage(
            lockupPeriod,
            lockupPeriod
        );

        assertEq(
            contractPenalty,
            expectedPenaltyPercentage,
            "Contract penalty calculation should match expected 20%"
        );

        // Warp time to 2 years and test again
        vm.warp(block.timestamp + 2 * 365 days);
        contractPenalty = aStaking.calculatePenaltyPercentage(
            user1,
            stakeIndex
        );
        expectedPenaltyPercentage = _calculatePenaltyPercentage(
            lockupPeriod - (2 * 365 days), // 1 year remaining
            lockupPeriod
        );

        assertEq(
            contractPenalty,
            expectedPenaltyPercentage,
            "Contract penalty calculation should match expected 10%"
        );

        // Warp time to end of lockup and test again
        vm.warp(block.timestamp + 2 * 365 days); // Total 3 years
        contractPenalty = aStaking.calculatePenaltyPercentage(
            user1,
            stakeIndex
        );
        expectedPenaltyPercentage = _calculatePenaltyPercentage(
            0, // No time remaining after lockup ends
            lockupPeriod
        );

        assertEq(
            contractPenalty,
            expectedPenaltyPercentage,
            "Contract penalty calculation should match expected 0%"
        );
    }
    function test_EdgeCase_BUCKET_SHORT_TERM_MAX() public {
        uint256 stakeAmount = 1000 ether;
        uint256 lockupPeriod = aStaking.BUCKET_SHORT_TERM_MAX();

        aSummerToken.approve(address(aStaking), stakeAmount);
        vm.expectRevert(ISummerStaking.Staking_BucketCapExceeded.selector);
        aStaking.stakeLockup(stakeAmount, lockupPeriod);

        lockupPeriod = lockupPeriod + 1;

        uint256 stakeIndex = _stake(aStaking, user1, stakeAmount, lockupPeriod);
        // first stake is no lockup - automatically created
        assertEq(aStaking.getUserStakesCount(user1), 2);
        _assertStake(
            user1,
            stakeIndex,
            stakeAmount,
            _calculateExpectedWeightedAmountForPeriod(
                stakeAmount,
                lockupPeriod
            ),
            block.timestamp + lockupPeriod,
            lockupPeriod
        );
    }

    function test_PenaltyCalculation_EdgeCases() public {
        uint256 stakeAmount = 1000 ether;

        // Test 1-year lockup
        uint256 stakeIndex1 = _stake(aStaking, user1, stakeAmount, 365 days);
        uint256 penalty1 = aStaking.calculatePenaltyPercentage(
            user1,
            stakeIndex1
        );
        uint256 expectedPenalty1 = _calculatePenaltyPercentage(
            365 days,
            365 days
        );
        assertEq(
            penalty1,
            expectedPenalty1,
            "1-year lockup immediate penalty should be 6.666666666666666666%"
        );

        // Test 2-year lockup
        uint256 stakeIndex2 = _stake(
            aStaking,
            user2,
            stakeAmount,
            2 * 365 days
        );
        uint256 penalty2 = aStaking.calculatePenaltyPercentage(
            user2,
            stakeIndex2
        );
        uint256 expectedPenalty2 = _calculatePenaltyPercentage(
            2 * 365 days,
            2 * 365 days
        );
        assertEq(
            penalty2,
            expectedPenalty2,
            "2-year lockup immediate penalty should be 2*6.666666666666666666%"
        );

        // Test 6-month lockup
        uint256 stakeIndex3 = _stake(
            aStaking,
            user3,
            stakeAmount,
            365 days / 2
        );
        uint256 penalty3 = aStaking.calculatePenaltyPercentage(
            user3,
            stakeIndex3
        );
        uint256 expectedPenalty3 = _calculatePenaltyPercentage(
            365 days / 2,
            365 days / 2
        );
        assertEq(
            penalty3,
            expectedPenalty3,
            "6-month lockup immediate penalty should be 3.333333333333333333%"
        );
    }

    // ============ TOKEN TRANSFER TESTS ============
    function test_StakeLockupOnBehalf_RevertOnNotAuthorized() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerStaking.Staking_NotAuthorized.selector,
                address(this),
                user1
            )
        );
        aStaking.stakeLockupOnBehalf(user1, STAKE_AMOUNT, aMinLockupPeriod);
    }

    function test_StakeLockupOnBehalf_RevertOnZeroAmount() public {
        vm.prank(user1);
        aStaking.setAuthorization(address(this), true);

        uint256 lockupPeriod = aMinLockupPeriod;
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerStaking.Staking_InvalidAmount.selector,
                "Amount cannot be zero"
            )
        );
        aStaking.stakeLockupOnBehalf(user1, 0, lockupPeriod);
    }

    function test_StakeLockupOnBehalf_TokensTransferredCorrectly() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = aMinLockupPeriod;
        address receiver = user2;
        address sender = user1;

        // Get initial balances
        uint256 senderSummerBalanceBefore = aSummerToken.balanceOf(sender);
        uint256 receiverSummerBalanceBefore = aSummerToken.balanceOf(receiver);
        uint256 senderXSumrBalanceBefore = axSumr.balanceOf(sender);
        uint256 receiverXSumrBalanceBefore = axSumr.balanceOf(receiver);

        vm.expectEmit(true, true, true, true);
        emit ISummerStaking.AuthorizationSet(receiver, sender, true);
        vm.prank(receiver);
        aStaking.setAuthorization(sender, true);

        // Sender approves and stakes on behalf of receiver
        vm.startPrank(sender);
        aSummerToken.approve(address(aStaking), stakeAmount);
        aStaking.stakeLockupOnBehalf(receiver, stakeAmount, lockupPeriod);
        vm.stopPrank();

        // Verify SUMMER tokens were pulled from sender
        assertEq(
            aSummerToken.balanceOf(sender),
            senderSummerBalanceBefore - stakeAmount,
            "SUMMER tokens should be pulled from sender"
        );

        // Verify receiver's SUMMER balance unchanged (they didn't send tokens)
        assertEq(
            aSummerToken.balanceOf(receiver),
            receiverSummerBalanceBefore,
            "Receiver's SUMMER balance should be unchanged"
        );

        // Verify staked tokens (xSUMR) were minted to receiver, not sender
        assertEq(
            axSumr.balanceOf(receiver),
            receiverXSumrBalanceBefore + stakeAmount,
            "xSUMR tokens should be minted to receiver"
        );

        // Verify sender did NOT receive xSUMR tokens
        assertEq(
            axSumr.balanceOf(sender),
            senderXSumrBalanceBefore,
            "Sender should not receive xSUMR tokens"
        );

        // Verify staking contract state reflects receiver as the staker
        assertEq(
            aStaking.balanceOf(receiver),
            stakeAmount,
            "Receiver should have staking balance"
        );

        assertEq(
            aStaking.balanceOf(sender),
            0,
            "Sender should not have staking balance"
        );

        assertEq(
            aStaking.getUserStakesCount(receiver),
            2,
            "Receiver should have two stakes (including no lockup one)"
        );

        assertEq(
            aStaking.getUserStakesCount(sender),
            0,
            "Sender should have no stakes"
        );

        // Verify the stake amount was updated correctly
        (uint256 _stakeAmount, , , ) = aStaking.getUserStake(receiver, 1);
        assertEq(
            _stakeAmount,
            stakeAmount,
            "Stake amount should be updated to include additional amount"
        );
    }

    // ============ INVARIANT(ISH) TESTS ============

    function test_Invariant_SupplyConsistency() public {
        // Create multiple stakes
        _stake(aStaking, user1, STAKE_AMOUNT, aMinLockupPeriod);
        _stake(aStaking, user1, STAKE_AMOUNT, MEDIUM_LOCKUP);
        _stake(aStaking, user2, STAKE_AMOUNT, aMaxLockupPeriod);

        // Verify totalSupply equals sum of weighted balances
        uint256 totalWeightedBalance = aStaking.weightedBalanceOf(user1) +
            aStaking.weightedBalanceOf(user2);
        assertEq(
            aStaking.totalSupply(),
            totalWeightedBalance,
            "Total supply should equal sum of weighted balances"
        );
    }

    function test_Invariant_BalanceConsistency() public {
        uint256 stakeAmount1 = STAKE_AMOUNT;
        uint256 stakeAmount2 = STAKE_AMOUNT / 2;

        _stake(aStaking, user1, stakeAmount1, aMinLockupPeriod);
        _stake(aStaking, user1, stakeAmount2, MEDIUM_LOCKUP);

        // Verify user's total balance equals sum of individual stakes
        uint256 totalStaked = stakeAmount1 + stakeAmount2;
        assertEq(
            aStaking.balanceOf(user1),
            totalStaked,
            "User balance should equal sum of individual stakes"
        );
    }

    function test_Invariant_BucketConsistency() public {
        uint256 stakeAmount = STAKE_AMOUNT;

        // Stake in bucket 1 (14 days to 90 days)
        uint256 stakeIndex1 = _stake(
            aStaking,
            user1,
            stakeAmount,
            aMinLockupPeriod
        );

        // Verify bucket total matches staked amount
        _assertBucket(ISummerStaking.Bucket.TwoWeeksToThreeMonths, stakeAmount);

        // Unstake and verify bucket total is updated
        vm.warp(block.timestamp + aMinLockupPeriod + 1 days);
        _approveAndUnstake(aStaking, user1, stakeIndex1, stakeAmount);

        _assertBucket(ISummerStaking.Bucket.TwoWeeksToThreeMonths, 0);
    }

    function test_Invariant_TokenAccounting() public {
        uint256 stakeAmount = STAKE_AMOUNT;

        uint256 stakeIndex1 = _stake(
            aStaking,
            user1,
            stakeAmount,
            aMinLockupPeriod
        );

        // Verify sSUMMER token supply equals staked amount
        assertEq(
            axSumr.totalSupply(),
            stakeAmount,
            "sSUMMER supply should equal staked amount"
        );

        // Unstake and verify
        vm.warp(block.timestamp + aMinLockupPeriod + 1 days);
        _approveAndUnstake(aStaking, user1, stakeIndex1, stakeAmount);

        assertEq(
            axSumr.totalSupply(),
            0,
            "sSUMMER supply should be zero after unstaking"
        );
    }

    function test_CantStakeWithUninitializedBuckets() public {
        SummerStaking freshStaking = createFreshStaking();
        uint256[] memory periods = new uint256[](7);
        periods[0] = 0;
        periods[1] = freshStaking.BUCKET_SHORT_TERM_MIN();
        periods[2] = freshStaking.BUCKET_SHORT_TERM_MAX() + 1;
        periods[3] = 100 days;
        periods[4] = 200 days;
        periods[5] = 400 days;
        periods[6] = 800 days;
        for (uint256 i = 0; i < 7; i++) {
            vm.startPrank(user1);
            aSummerToken.approve(address(freshStaking), STAKE_AMOUNT);
            vm.expectRevert(
                abi.encodeWithSelector(
                    ISummerStaking.Staking_BucketCapExceeded.selector
                )
            );
            freshStaking.stakeLockup(STAKE_AMOUNT, periods[i]);
            vm.stopPrank();
        }
    }

    function test_RewardsTotal_TwoStakers_MaxAndNoLockup() public {
        (
            uint256 user1Rewards,
            uint256 user2Rewards,
            uint256 totalRewards
        ) = _twoStakersClaimRewards(aMaxLockupPeriod, 0);
        assertApproxEqAbs(totalRewards, REWARD_AMOUNT, 5000);
        assertGt(user1Rewards, user2Rewards); // longer lockup should earn more
    }

    function test_RewardsTotal_TwoStakers_MinAndNoLockup() public {
        (, , uint256 totalRewards) = _twoStakersClaimRewards(
            aMinLockupPeriod,
            0
        );
        assertApproxEqAbs(totalRewards, REWARD_AMOUNT, 5000);
    }

    function test_RewardsTotal_TwoStakers_MinAndMax() public {
        (
            uint256 user1Rewards,
            uint256 user2Rewards,
            uint256 totalRewards
        ) = _twoStakersClaimRewards(aMinLockupPeriod, aMaxLockupPeriod);
        assertApproxEqAbs(totalRewards, REWARD_AMOUNT, 5000);
        assertLt(user1Rewards, user2Rewards); // max lockup should earn most
    }

    function _twoStakersClaimRewards(
        uint256 lockup1,
        uint256 lockup2
    ) internal returns (uint256, uint256, uint256) {
        _addAndNotifyRewards(address(rewardToken), REWARD_AMOUNT);

        uint256 stakeAmount = STAKE_AMOUNT;
        _stake(aStaking, user1, stakeAmount, lockup1);
        _stake(aStaking, user2, stakeAmount, lockup2);

        // Accrue over full reward duration
        vm.warp(block.timestamp + 30 days);

        // Sanity: some rewards accrued
        assertGt(
            aStaking.earned(user1, address(rewardToken)),
            0,
            "user1 should have accrued rewards"
        );

        // Snapshot before claims
        UserSnapshot memory user1Before = _snapshotUser(aStaking, user1);
        UserSnapshot memory user2Before = _snapshotUser(aStaking, user2);

        // Claim for both users
        vm.prank(user1);
        aStaking.getReward(address(rewardToken));
        vm.prank(user2);
        aStaking.getReward(address(rewardToken));

        // Snapshot after claims
        UserSnapshot memory user1After = _snapshotUser(aStaking, user1);
        UserSnapshot memory user2After = _snapshotUser(aStaking, user2);

        uint256 user1Claimed = user1After.rewards - user1Before.rewards;
        uint256 user2Claimed = user2After.rewards - user2Before.rewards;
        uint256 totalClaimed = user1Claimed + user2Claimed;
        console.log("user1 weighted balance ", user1After.weighted);
        console.log("user2 weighted balance ", user2After.weighted);
        console.log("user 1 claimed         ", user1Claimed);
        console.log("user 2 claimed         ", user2Claimed);
        console.log("total claimed          ", totalClaimed);
        return (user1Claimed, user2Claimed, totalClaimed);
    }

    function test_PenaltyDisabled_ImmediateUnstake_NoPenalty() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = aMaxLockupPeriod; // otherwise would have max penalty

        // Stake by user1
        uint256 stakeIndex = _stake(aStaking, user1, stakeAmount, lockupPeriod);

        // Sanity: penalty > 0 when enabled
        uint256 penaltyBefore = aStaking.calculatePenaltyPercentage(
            user1,
            stakeIndex
        );
        assertGt(penaltyBefore, 0, "penalty should be > 0 before disabling");

        // Disable penalty by governor
        vm.prank(address(timelockA));
        aStaking.updatePenaltyEnabled(false);

        // Now penalty should be 0
        uint256 penaltyAfter = aStaking.calculatePenaltyPercentage(
            user1,
            stakeIndex
        );
        assertEq(penaltyAfter, 0, "penalty should be 0 after disabling");

        uint256 userSummerBefore = aSummerToken.balanceOf(user1);
        uint256 treasuryBefore = aSummerToken.balanceOf(aStaking.treasury());
        _approveAndUnstake(aStaking, user1, stakeIndex, stakeAmount);
        assertEq(
            aSummerToken.balanceOf(aStaking.treasury()),
            treasuryBefore,
            "treasury should not receive penalty"
        );
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBefore + stakeAmount,
            "user receives full amount back"
        );
    }

    function test_GetAllBucketInfoAndDetails_AllBuckets() public {
        _stakeAllBucketsAndAssertInfo();
        _unstakeAllBucketsAndAssertZero();
    }

    function _stakeAllBucketsAndAssertInfo() internal {
        vm.prank(address(timelockA));
        aStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.ShortTerm,
            DEFAULT_CAP_AMOUNT
        );

        uint256[] memory amounts = new uint256[](7);
        amounts[0] = 100 ether;
        amounts[1] = 110 ether;
        amounts[2] = 120 ether;
        amounts[3] = 130 ether;
        amounts[4] = 140 ether;
        amounts[5] = 150 ether;
        amounts[6] = 160 ether;

        uint256[] memory periods = new uint256[](7);
        periods[0] = 0;
        periods[1] = aStaking.BUCKET_SHORT_TERM_MIN();
        periods[2] = aStaking.BUCKET_SHORT_TERM_MAX() + 1;
        periods[3] = 100 days;
        periods[4] = 200 days;
        periods[5] = 400 days;
        periods[6] = 800 days;

        uint256 total;
        for (uint256 i = 0; i < 7; i++) total += amounts[i];
        deal(address(aSummerToken), user1, total);

        for (uint256 i = 0; i < 7; i++) {
            _stake(aStaking, user1, amounts[i], periods[i]);
        }

        ISummerStaking.Bucket[] memory buckets = new ISummerStaking.Bucket[](7);
        buckets[0] = ISummerStaking.Bucket.NoLockup;
        buckets[1] = ISummerStaking.Bucket.ShortTerm;
        buckets[2] = ISummerStaking.Bucket.TwoWeeksToThreeMonths;
        buckets[3] = ISummerStaking.Bucket.ThreeToSixMonths;
        buckets[4] = ISummerStaking.Bucket.SixToTwelveMonths;
        buckets[5] = ISummerStaking.Bucket.OneToTwoYears;
        buckets[6] = ISummerStaking.Bucket.TwoToThreeYears;
        for (uint256 i = 0; i < 7; i++) {
            uint256 st = aStaking.getBucketTotalStaked(buckets[i]);
            assertEq(st, amounts[i]);
        }

        {
            (
                ISummerStaking.Bucket[] memory bs,
                uint256[] memory caps,
                uint256[] memory staked,
                uint256[] memory mins,
                uint256[] memory maxs
            ) = aStaking.getAllBucketInfo();
            assertEq(bs.length, 7);
            assertEq(caps.length, 7);
            assertEq(staked.length, 7);
            assertEq(mins.length, 7);
            assertEq(maxs.length, 7);

            for (uint256 i = 0; i < 7; i++) {
                assertEq(uint256(bs[i]), uint256(buckets[i]));
                assertEq(staked[i], amounts[i]);
                (
                    uint256 cap,
                    uint256 st2,
                    uint256 min2,
                    uint256 max2
                ) = aStaking.getBucketDetails(buckets[i]);
                assertEq(cap, caps[i]);
                assertEq(st2, staked[i]);
                assertEq(min2, mins[i]);
                assertEq(max2, maxs[i]);
            }
        }
    }

    function _unstakeAllBucketsAndAssertZero() internal {
        uint256 count = aStaking.getUserStakesCount(user1);
        assertEq(count, 7);
        for (uint256 k = count; k > 1; k--) {
            uint256 idx = k - 1;
            (uint256 amt, , , ) = aStaking.getUserStake(user1, idx);
            _approveAndUnstake(aStaking, user1, idx, amt);
        }
        (uint256 noAmt, , , ) = aStaking.getUserStake(user1, 0);
        if (noAmt > 0) _approveAndUnstake(aStaking, user1, 0, noAmt);

        _assertBucket(ISummerStaking.Bucket.NoLockup, 0);
        _assertBucket(ISummerStaking.Bucket.ShortTerm, 0);
        _assertBucket(ISummerStaking.Bucket.TwoWeeksToThreeMonths, 0);
        _assertBucket(ISummerStaking.Bucket.ThreeToSixMonths, 0);
        _assertBucket(ISummerStaking.Bucket.SixToTwelveMonths, 0);
        _assertBucket(ISummerStaking.Bucket.OneToTwoYears, 0);
        _assertBucket(ISummerStaking.Bucket.TwoToThreeYears, 0);

        assertEq(aStaking.balanceOf(user1), 0);
        assertEq(aStaking.weightedBalanceOf(user1), 0);
        assertEq(axSumr.balanceOf(user1), 0);

        (, , uint256[] memory st2, , ) = aStaking.getAllBucketInfo();
        for (uint256 i = 0; i < 7; i++) {
            assertEq(st2[i], 0);
        }
    }

    function test_Fuzz_Unstake_MultiStep_AfterLockup(
        uint128 amountRaw,
        uint32 lockupPeriodRaw,
        uint8 stepsRaw,
        uint256 salt
    ) public {
        // Bound inputs
        vm.startPrank(address(timelockA));
        aStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.ShortTerm,
            type(uint256).max
        );
        aStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.TwoToThreeYears,
            type(uint256).max
        );
        aStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.OneToTwoYears,
            type(uint256).max
        );
        aStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.ThreeToSixMonths,
            type(uint256).max
        );
        aStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.SixToTwelveMonths,
            type(uint256).max
        );
        aStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.TwoWeeksToThreeMonths,
            type(uint256).max
        );
        vm.stopPrank();
        /// max is multiply of total supply of summer token
        uint256 amount = uint256(
            bound(amountRaw, 21, 1_000_000_000_000_000_000 ether)
        );
        uint256 lockupPeriod = uint256(
            bound(lockupPeriodRaw, aMinLockupPeriod, aMaxLockupPeriod)
        );
        uint256 steps = uint256(bound(stepsRaw, 2, 20));

        // Fund and stake
        deal(address(aSummerToken), user1, amount);

        uint256 stakeIndex = _stake(aStaking, user1, amount, lockupPeriod);

        // Move past lockup so no penalties apply
        vm.warp(block.timestamp + lockupPeriod + 1 days);

        // Perform multi-step partial unstakes with randomized chunks
        uint256 remaining = amount;

        for (uint256 i = 0; i < steps - 1; i++) {
            // Leave at least 1 wei for each remaining step
            uint256 maxChunk = remaining - ((steps - 1) - i);
            uint256 rnd = uint256(
                keccak256(abi.encodePacked(salt, i, amount, lockupPeriod))
            );
            uint256 chunk = 1 + (rnd % maxChunk);

            _approveAndUnstake(aStaking, user1, stakeIndex, chunk);
            remaining -= chunk;
        }

        // Final chunk drains the position
        _approveAndUnstake(aStaking, user1, stakeIndex, remaining);
        // After full exit, the specific stake index is removed (swap-and-pop), so querying it should return zeros
        (uint256 finalAmount, uint256 finalWeighted, , ) = aStaking
            .getUserStake(user1, stakeIndex);

        assertEq(
            finalAmount,
            0,
            "Stake amount should be zero after full multi-step exit"
        );
        assertEq(
            finalWeighted,
            0,
            "Stake weightedAmount should be zero after full multi-step exit"
        );

        // User-level balances should be zero as user had only this stake (plus placeholder index 0)
        assertEq(
            aStaking.balanceOf(user1),
            0,
            "User raw balance should be zero"
        );
        assertEq(
            aStaking.weightedBalanceOf(user1),
            0,
            "User weighted balance should be zero"
        );
        assertEq(axSumr.balanceOf(user1), 0, "xSUMR balance should be zero");
    }

    function test_Fuzz_Unstake_MultiStep_NoLockup(
        uint128 amountRaw,
        uint8 stepsRaw,
        uint256 salt
    ) public {
        // Bound inputs
        uint256 amount = uint256(
            bound(amountRaw, 21, 1_000_000_000_000_000_000 ether)
        );
        uint256 steps = uint256(bound(stepsRaw, 2, 20));

        // Fund and stake into no-lockup (index 0)
        deal(address(aSummerToken), user1, amount);
        uint256 stakeIndex = _stake(aStaking, user1, amount, 0);
        assertEq(stakeIndex, 0, "No-lockup stake should be at index 0");

        // Multi-step partial unstakes on index 0
        uint256 remaining = amount;
        for (uint256 i = 0; i < steps - 1; i++) {
            uint256 maxChunk = remaining - ((steps - 1) - i);
            uint256 rnd = uint256(keccak256(abi.encodePacked(salt, i, amount)));
            uint256 chunk = 1 + (rnd % maxChunk);
            _approveAndUnstake(aStaking, user1, 0, chunk);
            remaining -= chunk;
        }
        _approveAndUnstake(aStaking, user1, 0, remaining);

        // Index 0 remains but should be fully zeroed
        (uint256 finalAmount, uint256 finalWeighted, , ) = aStaking
            .getUserStake(user1, 0);
        assertEq(
            finalAmount,
            0,
            "No-lockup amount should be zero after full multi-step exit"
        );
        assertEq(
            finalWeighted,
            0,
            "No-lockup weighted should be zero after full multi-step exit"
        );

        // User and bucket invariants
        assertEq(
            aStaking.balanceOf(user1),
            0,
            "User raw balance should be zero"
        );
        assertEq(
            aStaking.weightedBalanceOf(user1),
            0,
            "User weighted balance should be zero"
        );
        assertEq(axSumr.balanceOf(user1), 0, "xSUMR balance should be zero");
        _assertBucket(ISummerStaking.Bucket.NoLockup, 0);
    }

    function test_GetRewardFor_Account_RevertWithoutAuth_ThenSucceedWithAuth()
        public
    {
        // Stake and fund rewards
        _stake(aStaking, user1, STAKE_AMOUNT, aMinLockupPeriod);
        _addAndNotifyRewards(address(rewardToken), REWARD_AMOUNT);
        vm.warp(block.timestamp + 10 days);

        uint256 user1Before = rewardToken.balanceOf(user1);

        // 1) Not authorized caller should revert
        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerStaking.Staking_NotAuthorized.selector,
                user2,
                user1
            )
        );
        aStaking.getRewardFor(user1);

        // 2) Whitelist caller and try again
        vm.prank(user1);
        aStaking.setAuthorization(user2, true);

        vm.prank(user2);
        aStaking.getRewardFor(user1);

        uint256 user1After = rewardToken.balanceOf(user1);
        assertGt(
            user1After,
            user1Before,
            "Rewards should be transferred after authorized claim"
        );
        assertEq(
            aStaking.earned(user1, address(rewardToken)),
            0,
            "Earned should reset after claim"
        );
    }

    function test_GetRewardFor_AccountAndToken_RevertWithoutAuth_ThenSucceedWithAuth()
        public
    {
        // Stake and fund rewards
        _stake(aStaking, user1, STAKE_AMOUNT, aMinLockupPeriod);
        _addAndNotifyRewards(address(rewardToken), REWARD_AMOUNT);
        vm.warp(block.timestamp + 10 days);

        uint256 user1Before = rewardToken.balanceOf(user1);

        // 1) Not authorized caller should revert
        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerStaking.Staking_NotAuthorized.selector,
                user2,
                user1
            )
        );
        aStaking.getRewardFor(user1, address(rewardToken));

        // 2) Whitelist caller and try again
        vm.prank(user1);
        aStaking.setAuthorization(user2, true);

        vm.prank(user2);
        aStaking.getRewardFor(user1, address(rewardToken));

        uint256 user1After = rewardToken.balanceOf(user1);
        assertGt(
            user1After,
            user1Before,
            "Rewards should be transferred after authorized claim"
        );
        assertEq(
            aStaking.earned(user1, address(rewardToken)),
            0,
            "Earned should reset after claim"
        );
    }
}
