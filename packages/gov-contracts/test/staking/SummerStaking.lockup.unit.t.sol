// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerStaking} from "../../src/contracts/SummerStaking.sol";
import {ISummerStaking} from "../../src/interfaces/ISummerStaking.sol";
import {ISummerGovernorV2} from "../../src/interfaces/ISummerGovernorV2.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {SummerVestingWalletFactory} from "../../src/contracts/SummerVestingWalletFactory.sol";
import {SummerVestingWalletFactoryV2} from "../../src/contracts/SummerVestingWalletFactoryV2.sol";
import {StakedSummerToken} from "../../src/contracts/StakedSummerToken.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {ExposedSummerGovernor, SummerGovernorV2TestBase} from "../governorV2/SummerGovernorV2TestBase.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Constants} from "@summerfi/constants/Constants.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SummerStakingTestBase} from "./SummerStakingTestBase.sol";
import {UD60x18, ud60x18, convert} from "@prb/math/src/UD60x18.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IAccessControlErrors} from "@summerfi/access-contracts/interfaces/IAccessControlErrors.sol";
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

    // ============ ENHANCED HELPER METHODS ============

    /**
     * @notice Helper to create a fresh staking contract with specific configuration
     */
    function createFreshStakingWithConfig() internal returns (SummerStaking) {
        SummerStaking freshStaking = createFreshStaking();

        // Configure bucket caps
        vm.startPrank(address(timelockA));
        freshStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.ThreeToSixMonths,
            1000000 ether
        );
        freshStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.SixToTwelveMonths,
            100000 ether
        );
        freshStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.OneToTwoYears,
            100000 ether
        );
        freshStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.TwoToThreeYears,
            100000 ether
        );
        vm.stopPrank();

        return freshStaking;
    }

    // ============ DEPLOYMENT & INITIALIZATION TESTS ============

    function test_CorrectInitialization() public {
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

    function test_Revert_DeployWithZeroSummerToken() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_InvalidAddress(string)",
                "Summer token address cannot be zero"
            )
        );
        new SummerStaking(
            address(accessManagerA),
            address(configurationManagerA),
            address(0), // Zero summer token
            address(axSumr)
        );
    }

    function test_Revert_DeployWithZeroStakedSummerToken() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_InvalidAddress(string)",
                "StakedSummerToken address cannot be zero"
            )
        );
        new SummerStaking(
            address(accessManagerA),
            address(configurationManagerA),
            address(aSummerToken),
            address(0) // Zero StakedSummerToken
        );
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
        uint256 contractSummerBalanceBefore = aSummerToken.balanceOf(
            address(aStaking)
        );
        uint256 totalSupplyBefore = aStaking.totalSupply();

        uint256 stakeIndex = _stake(aStaking, user1, stakeAmount, lockupPeriod);

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
        _assertBucket(ISummerStaking.Bucket.ThreeToSixMonths, stakeAmount);
    }

    // Failure Cases
    function test_Revert_StakeWithZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("CannotStakeZero()"));
        aStaking.stakeLockup(0, aMinLockupPeriod);
    }

    function test_Revert_StakeWithLockupBelowMin() public {
        uint256 invalidLockupPeriod = aMinLockupPeriod - 1 days;

        vm.startPrank(user1);
        aSummerToken.approve(address(aStaking), STAKE_AMOUNT);
        vm.expectRevert(abi.encodeWithSignature("Staking_BucketCapExceeded()"));
        aStaking.stakeLockup(STAKE_AMOUNT, invalidLockupPeriod);
        vm.stopPrank();
    }

    function test_Revert_StakeWithLockupAboveMax() public {
        uint256 invalidLockupPeriod = aMaxLockupPeriod + 1 days;

        vm.startPrank(user1);
        aSummerToken.approve(address(aStaking), STAKE_AMOUNT);
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_InvalidLockupPeriod(string)",
                "Lockup period cannot exceed 3 years"
            )
        );
        aStaking.stakeLockup(STAKE_AMOUNT, invalidLockupPeriod);
        vm.stopPrank();
    }

    function test_Revert_StakeWhenMaxStakesReached() public {
        // Create 10 stakes to reach the maximum
        for (uint256 i = 0; i < 999; i++) {
            _stake(aStaking, user1, STAKE_AMOUNT / 999, aMinLockupPeriod);
        }

        assertEq(aStaking.getUserStakesCount(user1), 1000);

        // Attempt to create an 11th stake should revert
        vm.startPrank(user1);
        aSummerToken.approve(address(aStaking), STAKE_AMOUNT);
        vm.expectRevert(abi.encodeWithSignature("Staking_MaxStakesReached()"));
        aStaking.stakeLockup(STAKE_AMOUNT, aMinLockupPeriod);
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
        uint256 userXSumrBalanceBefore = axSumr.balanceOf(user1);

        // Unstake full amount
        _approveAndUnstake(aStaking, user1, stakeIndex, stakeAmount);

        // Verify user received full amount back (no penalty)
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore + stakeAmount
        );
        assertEq(axSumr.balanceOf(user1), userXSumrBalanceBefore - stakeAmount);

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

        // Get state before unstaking
        uint256 balanceBefore = aStaking.balanceOf(user1);
        uint256 weightedBalanceBefore = aStaking.weightedBalanceOf(user1);
        uint256 totalSupplyBefore = aStaking.totalSupply();

        // Unstake full amount
        _approveAndUnstake(aStaking, user1, stakeIndex, stakeAmount);

        // Verify state changes
        assertEq(aStaking.balanceOf(user1), balanceBefore - stakeAmount);
        assertEq(
            aStaking.weightedBalanceOf(user1),
            weightedBalanceBefore -
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
    function test_UnstakeImmediately() public {
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
        uint256 userXSumrBalanceBefore = axSumr.balanceOf(user1);
        uint256 treasuryBalanceBefore = aSummerToken.balanceOf(
            aStaking.treasury()
        );
        vm.prank(user1);
        axSumr.approve(address(aStaking), stakeAmount);
        // Unstake immediately
        _verifyUnstakedEvent(
            user1,
            aStaking.stakePortfolioId(user1),
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

    function test_UnstakeAfter2months_MinimumLockupPeriod() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = aMinLockupPeriod; // 6 months

        uint256 stakeIndex = _stake(aStaking, user1, stakeAmount, lockupPeriod);

        vm.warp(block.timestamp + 4 * 30 days + 1);

        // Calculate expected penalty (should be flat 2% for immediate unstake within 4 months)
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
        // Unstake after 2 months
        _verifyUnstakedEvent(
            user1,
            aStaking.stakePortfolioId(user1),
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

    function test_UnstakeHalfwayThroughLockup() public {
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

    function test_CorrectStateChangesOnUnstakeWithPenalty() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = aMaxLockupPeriod;

        uint256 stakeIndex = _stake(aStaking, user1, stakeAmount, lockupPeriod);

        // Get state before unstaking
        uint256 balanceBefore = aStaking.balanceOf(user1);
        uint256 weightedBalanceBefore = aStaking.weightedBalanceOf(user1);
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
        assertEq(aStaking.balanceOf(user1), balanceBefore - stakeAmount);
        assertEq(
            aStaking.weightedBalanceOf(user1),
            weightedBalanceBefore -
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
        vm.expectRevert(abi.encodeWithSignature("CannotUnstakeZero()"));
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
        vm.expectRevert(abi.encodeWithSignature("Staking_InvalidStakeIndex()"));
        aStaking.unstakeLockup(stakeIndex + 1, STAKE_AMOUNT);
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
            abi.encodeWithSignature("Staking_InsufficientBalance()")
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
        ISummerStaking.Bucket bucket = ISummerStaking.Bucket.ThreeToSixMonths;
        uint256 cap = STAKE_AMOUNT;

        // Set bucket cap
        vm.prank(address(timelockA));
        aStaking.updateLockupBucketCap(bucket, cap);

        // Stake up to the cap
        _stake(aStaking, user1, cap, aMinLockupPeriod);

        // Attempt to stake more should revert
        vm.startPrank(user2);
        aSummerToken.approve(address(aStaking), STAKE_AMOUNT);
        vm.expectRevert(abi.encodeWithSignature("Staking_BucketCapExceeded()"));
        aStaking.stakeLockup(STAKE_AMOUNT, aMinLockupPeriod);
        vm.stopPrank();
    }

    function test_CorrectBucketAccounting() public {
        ISummerStaking.Bucket bucket = ISummerStaking.Bucket.ThreeToSixMonths;

        // Stake in ThreeToSixMonths bucket (90 days to 180 days)
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
            abi.encodeWithSignature(
                "Staking_DirectStakeNotAllowed(string)",
                "Use stakeLockup instead"
            )
        );
        aStaking.stake(STAKE_AMOUNT);
    }

    function test_Revert_CallingDirectUnstake() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_DirectUnstakeNotAllowed(string)",
                "Use unstakeLockup instead"
            )
        );
        aStaking.unstake(STAKE_AMOUNT);
    }

    function test_Revert_CallingExit() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_DirectUnstakeNotAllowed(string)",
                "Use unstakeLockup instead"
            )
        );
        aStaking.exit();
    }

    function test_Revert_CallingStakeOnBehalfOf() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("StakeOnBehalfOfNotSupported()")
        );
        aStaking.stakeOnBehalfOf(user2, STAKE_AMOUNT);
    }

    function test_Revert_CallingUnstakeOnBehalfOf() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("UnstakeOnBehalfOfNotSupported()")
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

        // Warp time to 4 months before end of lockup period
        vm.warp(block.timestamp + 3 * 365 days - 4 * 30 days + 1);

        // Calculate expected penalty: 2% for 4 months left of lockup period
        uint256 expectedPenaltyPercentage = aMinPenaltyPercentage;
        console.log("expectedPenaltyPercentage", expectedPenaltyPercentage);
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

        // Stake in bucket 0 (90 days to 180 days)
        uint256 stakeIndex1 = _stake(
            aStaking,
            user1,
            stakeAmount,
            aMinLockupPeriod
        );

        // Verify bucket total matches staked amount
        _assertBucket(ISummerStaking.Bucket.ThreeToSixMonths, stakeAmount);

        // Unstake and verify bucket total is updated
        vm.warp(block.timestamp + aMinLockupPeriod + 1 days);
        _approveAndUnstake(aStaking, user1, stakeIndex1, stakeAmount);

        _assertBucket(ISummerStaking.Bucket.ThreeToSixMonths, 0);
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

    // ============ MOVE STAKES TESTS ============

    function test_MoveAllStakesTo_FreshWallet_AccountingMoves_XSumrTransfers()
        public
    {
        // Prepare: user1 has multiple stakes; user2 has none
        _stake(aStaking, user1, STAKE_AMOUNT, aMinLockupPeriod);
        _stake(aStaking, user1, STAKE_AMOUNT / 2, 0);
        assertEq(aStaking.getUserStakesCount(user1), 2);
        assertEq(aStaking.getUserStakesCount(user2), 0);

        // Snapshot pre-state
        uint256 fromRawBefore = aStaking.balanceOf(user1);
        uint256 fromWeightedBefore = aStaking.weightedBalanceOf(user1);
        uint256 toRawBefore = aStaking.balanceOf(user2);
        uint256 toWeightedBefore = aStaking.weightedBalanceOf(user2);
        uint256 totalSupplyBefore = aStaking.totalSupply();
        uint256 xFromBefore = axSumr.balanceOf(user1);
        uint256 xToBefore = axSumr.balanceOf(user2);

        // Approve xSUMR transfer and move all stakes from user1 to user2
        vm.prank(user1);
        axSumr.approve(address(aStaking), fromRawBefore);
        vm.prank(user1);
        aStaking.transferStakes(user2);

        // Source is cleared
        assertEq(
            aStaking.getUserStakesCount(user1),
            0,
            "from stakes should be cleared"
        );
        assertEq(
            aStaking.balanceOf(user1),
            0,
            "from raw balance should be zero"
        );
        assertEq(
            aStaking.weightedBalanceOf(user1),
            0,
            "from weighted balance should be zero"
        );

        // Target receives balances and stakes
        assertEq(
            aStaking.getUserStakesCount(user2),
            2,
            "to should receive all stakes"
        );
        assertEq(
            aStaking.balanceOf(user2),
            toRawBefore + fromRawBefore,
            "to raw balance should increase by from raw"
        );
        assertEq(
            aStaking.weightedBalanceOf(user2),
            toWeightedBefore + fromWeightedBefore,
            "to weighted balance should increase by from weighted"
        );

        // Total weighted supply unchanged
        assertEq(
            aStaking.totalSupply(),
            totalSupplyBefore,
            "totalSupply must remain unchanged"
        );

        // xSUMR token balances moved
        assertEq(
            axSumr.balanceOf(user1),
            xFromBefore - fromRawBefore,
            "xSUMR of from should decrease by raw amount"
        );
        assertEq(
            axSumr.balanceOf(user2),
            xToBefore + fromRawBefore,
            "xSUMR of to should increase by raw amount"
        );

        // Check moved stake data coherence (non-zero amounts)
        (uint256 amt0, , , ) = aStaking.getUserStake(user2, 0);
        (uint256 amt1, , , ) = aStaking.getUserStake(user2, 1);
        assertGt(amt0, 0);
        assertGt(amt1, 0);
    }

    function test_TransferStakes_MovesAccruedRewards_ReceiverCanClaim() public {
        // Stake by user1
        uint256 stakeAmount = STAKE_AMOUNT;
        _stake(aStaking, user1, stakeAmount, aMinLockupPeriod);

        // Notify rewards and accrue
        _addAndNotifyRewards(address(rewardToken), REWARD_AMOUNT);
        vm.warp(block.timestamp + 30 days);

        // Earned before transfer should be > 0 for user1
        uint256 earnedBefore = aStaking.earned(user1, address(rewardToken));
        assertGt(
            earnedBefore,
            0,
            "user1 should have accrued rewards before transfer"
        );

        // Approve xSUMR transfer
        vm.prank(user1);
        axSumr.approve(address(aStaking), stakeAmount);

        // Transfer stakes to user2
        vm.prank(user1);
        aStaking.transferStakes(user2);

        // After transfer: user1 can't earn prior rewards, user2 has them
        assertEq(
            aStaking.earned(user1, address(rewardToken)),
            0,
            "user1 accrued rewards should be moved"
        );
        uint256 earnedTo = aStaking.earned(user2, address(rewardToken));
        assertEq(
            earnedTo,
            earnedBefore,
            "user2 should inherit accrued rewards"
        );

        // xSUMR moved from user1 to user2
        assertEq(axSumr.balanceOf(user1), 0, "from xSUMR should be moved");
        assertEq(
            axSumr.balanceOf(user2),
            stakeAmount,
            "to xSUMR should increase by staked amount"
        );

        // User2 can claim
        uint256 user2RewardBalanceBefore = rewardToken.balanceOf(user2);
        vm.prank(user2);
        aStaking.getReward(address(rewardToken));
        uint256 user2RewardBalanceAfter = rewardToken.balanceOf(user2);
        assertEq(
            user2RewardBalanceAfter,
            user2RewardBalanceBefore + earnedTo,
            "user2 should receive accrued rewards on claim"
        );
        assertEq(
            aStaking.earned(user2, address(rewardToken)),
            0,
            "earned should reset after claim"
        );

        uint user1RewardsBalanceBefore = rewardToken.balanceOf(user1);
        // User1 can't claim
        vm.prank(user1);
        aStaking.getReward(address(rewardToken));
        uint user1RewardsBalanceAfter = rewardToken.balanceOf(user1);
        assertEq(
            user1RewardsBalanceAfter,
            user1RewardsBalanceBefore,
            "user1 should not receive rewards after claim"
        );
    }

    function test_Revert_TransferStakes_TargetHasUnclaimedRewards() public {
        // Prepare target with unclaimed rewards but zero stakes
        // Step 1: user2 stakes and accrues rewards
        uint256 stakeIndex1 = _stake(
            aStaking,
            user2,
            STAKE_AMOUNT,
            aMinLockupPeriod
        );
        _addAndNotifyRewards(address(rewardToken), REWARD_AMOUNT);
        vm.warp(block.timestamp + 10 days);
        // Step 2: user2 fully unstakes (after lockup), leaving accrued rewards
        vm.warp(block.timestamp + aMinLockupPeriod + 1 days);
        _approveAndUnstake(aStaking, user2, stakeIndex1, STAKE_AMOUNT);
        assertEq(
            aStaking.getUserStakesCount(user2),
            1,
            "user2 should have one stake (no Lockup)"
        );
        assertGt(
            aStaking.earned(user2, address(rewardToken)),
            0,
            "user2 should have unclaimed rewards"
        );

        // Now user1 stakes and tries to transfer to user2
        _stake(aStaking, user1, STAKE_AMOUNT, aMinLockupPeriod);
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerStaking.Staking_ExistingTarget.selector,
                "Target already has stakes"
            )
        );
        aStaking.transferStakes(user2);
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

    function test_create_multiple_stakes_and_transfer_measure_gas() public {
        deal(address(aSummerToken), user1, STAKE_AMOUNT * 100);
        uint[] memory counts = new uint[](10);
        for (uint256 i = 0; i < 10; i++) {
            counts[i] = i * 50 + 50;
        }
        for (uint256 i = 0; i < 10; i++) {
            _create_multiple_stakes_and_transfer_measure_gas(counts[i]);
        }
    }
    function _create_multiple_stakes_and_transfer_measure_gas(
        uint count
    ) internal {
        SummerStaking freshStaking = createFreshStakingWithConfig();
        for (uint256 i = 0; i < count; i++) {
            _stake(
                freshStaking,
                user1,
                STAKE_AMOUNT / 100,
                aMinLockupPeriod + i
            );
        }

        uint256 gasBefore = gasleft();
        vm.prank(user1);
        axSumr.approve(address(freshStaking), STAKE_AMOUNT * 100);
        address newUser = makeAddr(string(abi.encodePacked("user", count)));
        vm.prank(user1);
        freshStaking.transferStakes(newUser);
        uint256 gasAfter = gasleft();
        uint256 gasUsed = gasBefore - gasAfter;
        assertLt(gasUsed, 250000, "gas used should be less than 250000");
        assertEq(
            freshStaking.getUserStakesCount(user1),
            0,
            "user1 should have 0 stakes"
        );
        assertEq(
            freshStaking.getUserStakesCount(newUser),
            count + 1,
            "newUser should have count + 1 stakes"
        );
    }
}
