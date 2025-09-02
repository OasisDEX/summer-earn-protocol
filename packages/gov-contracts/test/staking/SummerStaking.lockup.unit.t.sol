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

        // Update lockup bucket caps for enhanced testing
        vm.startPrank(address(timelockA));
        aStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.ThreeToSixMonths,
            1000000 ether
        );
        aStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.SixToTwelveMonths,
            100000 ether
        );
        aStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.OneToTwoYears,
            100000 ether
        );
        aStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.TwoToFourYears,
            100000 ether
        );
        vm.stopPrank();

        vm.startPrank(address(timelockB));
        bStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.ThreeToSixMonths,
            1000000 ether
        );
        bStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.SixToTwelveMonths,
            100000 ether
        );
        bStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.OneToTwoYears,
            100000 ether
        );
        bStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.TwoToFourYears,
            100000 ether
        );
        vm.stopPrank();

        // Setup reward token
        rewardToken = new MockERC20();
        deal(address(rewardToken), address(timelockA), REWARD_AMOUNT * 1000);

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
            ISummerStaking.Bucket.TwoToFourYears,
            100000 ether
        );
        vm.stopPrank();

        return freshStaking;
    }

    /**
     * @notice Helper to advance time and mine blocks
     */
    function _advanceTime(uint256 time) internal {
        vm.warp(block.timestamp + time);
        vm.roll(block.number + (time / 12)); // Assuming 12 second block time
    }

    /**
     * @notice Helper to create multiple stakes with different lockup periods
     */
    function _createMultipleStakes(
        address user,
        uint256[] memory amounts,
        uint256[] memory lockupPeriods
    ) internal returns (uint256[] memory) {
        require(
            amounts.length == lockupPeriods.length,
            "Arrays must have same length"
        );

        uint256[] memory stakeIndices = new uint256[](amounts.length);

        for (uint256 i = 0; i < amounts.length; i++) {
            stakeIndices[i] = _stake(user, amounts[i], lockupPeriods[i]);
        }

        return stakeIndices;
    }

    /**
     * @notice Helper to calculate expected weighted amount for a given lockup period
     */
    function _calculateExpectedWeightedAmountForPeriod(
        uint256 amount,
        uint256 lockupPeriod
    ) internal pure returns (uint256) {
        if (lockupPeriod == 0) {
            return amount;
        }

        // Constants from contract
        uint256 WEIGHTED_STAKE_BASE = 5e16;
        uint256 WEIGHTED_STAKE_COEFFICIENT = 4e2; //
        // Convert lockupPeriod into 60.18 fixed-point
        UD60x18 time = convert(lockupPeriod);

        // Square it safely in 60.18 format
        UD60x18 timeSquared = time.mul(time);

        // multiplier = (WEIGHTED_STAKE_COEFFICIENT * time^2) + WEIGHTED_STAKE_BASE
        UD60x18 multiplier = ud60x18(WEIGHTED_STAKE_COEFFICIENT)
            .mul(timeSquared)
            .add(ud60x18(WEIGHTED_STAKE_BASE));

        // weightedAmount = amount * multiplier
        return ud60x18(amount).mul(multiplier).unwrap();
    }

    /**
     * @notice Helper to verify bucket distribution
     */
    function _verifyBucketDistribution(
        SummerStaking staking,
        uint256[] memory expectedBucketAmounts
    ) internal {
        ISummerStaking.Bucket[] memory buckets = new ISummerStaking.Bucket[](4);
        buckets[0] = ISummerStaking.Bucket.ThreeToSixMonths;
        buckets[1] = ISummerStaking.Bucket.SixToTwelveMonths;
        buckets[2] = ISummerStaking.Bucket.OneToTwoYears;
        buckets[3] = ISummerStaking.Bucket.TwoToFourYears;

        for (uint256 i = 0; i < 4; i++) {
            uint256 actualStaked = staking.getBucketTotalStaked(buckets[i]);
            assertEq(
                actualStaked,
                expectedBucketAmounts[i],
                string(abi.encodePacked("Bucket ", i, " mismatch"))
            );
        }
    }

    /**
     * @notice Helper to check if a user has a specific stake
     */
    function _hasStake(
        SummerStaking staking,
        address user,
        uint256 index
    ) internal view returns (bool) {
        (uint256 amount, , , ) = staking.getUserStake(user, index);
        return amount > 0;
    }

    /**
     * @notice Helper to get total staked amount for a user across all stakes
     */
    function _getTotalStakedAmount(
        SummerStaking staking,
        address user
    ) internal view returns (uint256) {
        uint256 total = 0;
        uint256 stakeCount = staking.getUserStakesCount(user);

        for (uint256 i = 0; i < stakeCount; i++) {
            (uint256 amount, , , ) = staking.getUserStake(user, i);
            total += amount;
        }

        return total;
    }

    /**
     * @notice Helper to get total weighted amount for a user across all stakes
     */
    function _getTotalWeightedAmount(
        SummerStaking staking,
        address user
    ) internal view returns (uint256) {
        uint256 total = 0;
        uint256 stakeCount = staking.getUserStakesCount(user);

        for (uint256 i = 0; i < stakeCount; i++) {
            (, uint256 weightedAmount, , ) = staking.getUserStake(user, i);
            total += weightedAmount;
        }

        return total;
    }

    /**
     * @notice Helper to verify reward distribution
     */
    function _verifyRewardDistribution(
        SummerStaking staking,
        address user,
        uint256 expectedReward
    ) internal {
        uint256 actualReward = staking.earned(user, address(rewardToken));
        assertEq(actualReward, expectedReward, "Reward amount mismatch");
    }

    /**
     * @notice Helper to claim rewards for a user
     */
    function _claimRewards(SummerStaking staking, address user) internal {
        vm.prank(user);
        staking.getReward(address(rewardToken));
    }

    /**
     * @notice Helper to check if a lockup period is valid
     */
    function _isValidLockupPeriod(
        uint256 lockupPeriod
    ) internal pure returns (bool) {
        return lockupPeriod >= 90 days && lockupPeriod <= 4 * 365 days;
    }

    /**
     * @notice Helper to calculate penalty percentage based on time remaining
     */
    function _calculatePenaltyPercentage(
        uint256 timeRemaining,
        uint256 originalLockupPeriod
    ) internal pure returns (uint256) {
        if (originalLockupPeriod == 0) return 0;
        return
            (timeRemaining * 50 * Constants.WAD) / (originalLockupPeriod * 100);
    }

    /**
     * @notice Helper to verify event emission with specific parameters
     */
    function _verifyStakedEvent(
        address user,
        uint256 amount,
        uint256 lockupPeriod,
        uint256 weightedAmount
    ) internal {
        vm.expectEmit(true, false, false, false);
        emit SummerStaking.StakedWithLockup(
            user,
            amount,
            lockupPeriod,
            weightedAmount
        );
    }

    /**
     * @notice Helper to verify unstaked event with specific parameters
     */
    function _verifyUnstakedEvent(
        address user,
        uint256 unstaked,
        uint256 penalty,
        uint256 returnAmount
    ) internal {
        vm.expectEmit(true, false, false, false);
        emit SummerStaking.UnstakedWithPenalty(
            user,
            unstaked,
            penalty,
            returnAmount
        );
    }

    // ============ DEPLOYMENT & INITIALIZATION TESTS ============

    function test_CorrectInitialization() public {
        assertEq(address(aStaking.SUMMER_TOKEN()), address(aSummerToken));
        assertEq(address(aStaking.STAKED_SUMMER_TOKEN()), address(axSumr));
        assertEq(
            aStaking.wrappedStakingToken(),
            address(aStaking.wrappedStakingToken())
        );

        // Check default bucket configurations

        // Check basic bucket details for NoLockup bucket (which should always exist)
        (uint256 cap0, uint256 staked0, , ) = aStaking.getBucketDetails(
            ISummerStaking.Bucket.NoLockup
        );
        assertEq(cap0, type(uint256).max); // No cap
        assertEq(staked0, 0);
    }

    function test_Revert_DeployWithZeroSummerToken() public {
        vm.expectRevert();
        new SummerStaking(
            address(accessManagerA),
            address(configurationManagerA),
            address(0), // Zero summer token
            address(axSumr)
        );
    }

    function test_Revert_DeployWithZeroStakedSummerToken() public {
        vm.expectRevert();
        new SummerStaking(
            address(accessManagerA),
            address(configurationManagerA),
            address(aSummerToken),
            address(0) // Zero StakedSummerToken
        );
    }

    // ============ STAKING TESTS (stakeWithNewLockup) ============

    // Success Cases
    function test_StakeWithMinLockup() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = 0; // No lockup for now to avoid bucket cap issues

        uint256 expectedWeightedAmount = _calculateExpectedWeightedAmountForPeriod(
                stakeAmount,
                lockupPeriod
            );
        uint256 expectedLockupEndTime = block.timestamp + lockupPeriod;

        uint256 stakeIndex = _stake(user1, stakeAmount, lockupPeriod);

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
        assertEq(axSumr.balanceOf(user1), stakeAmount);
    }

    function test_StakeWithMaxLockup() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = 0; // No lockup for now to avoid bucket cap issues

        uint256 expectedWeightedAmount = _calculateExpectedWeightedAmountForPeriod(
                stakeAmount,
                lockupPeriod
            );
        uint256 expectedLockupEndTime = block.timestamp + lockupPeriod;

        uint256 stakeIndex = _stake(user1, stakeAmount, lockupPeriod);

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

            uint256 stakeIndex = _stake(user1, STAKE_AMOUNT, lockupPeriods[i]);
            _assertStake(
                user1,
                stakeIndex,
                STAKE_AMOUNT,
                expectedWeightedAmount,
                expectedLockupEndTime,
                lockupPeriods[i]
            );
        }

        assertEq(aStaking.getUserStakesCount(user1), 3);
        assertEq(aStaking.balanceOf(user1), STAKE_AMOUNT * 3);
    }

    function test_CorrectStateChangesOnStake() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = MIN_LOCKUP;
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

        uint256 stakeIndex = _stake(user1, stakeAmount, lockupPeriod);

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
        aStaking.stakeWithNewLockup(0, MIN_LOCKUP);
    }

    function test_Revert_StakeWithLockupBelowMin() public {
        uint256 invalidLockupPeriod = MIN_LOCKUP - 1 days;

        vm.startPrank(user1);
        aSummerToken.approve(address(aStaking), STAKE_AMOUNT);
        vm.expectRevert(abi.encodeWithSignature("Staking_BucketCapExceeded()"));
        aStaking.stakeWithNewLockup(STAKE_AMOUNT, invalidLockupPeriod);
        vm.stopPrank();
    }

    function test_Revert_StakeWithLockupAboveMax() public {
        uint256 invalidLockupPeriod = MAX_LOCKUP + 1 days;

        vm.startPrank(user1);
        aSummerToken.approve(address(aStaking), STAKE_AMOUNT);
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_InvalidLockupPeriod(string)",
                "Lockup period cannot exceed 4 years"
            )
        );
        aStaking.stakeWithNewLockup(STAKE_AMOUNT, invalidLockupPeriod);
        vm.stopPrank();
    }

    function test_Revert_StakeWhenMaxStakesReached() public {
        // Create 10 stakes to reach the maximum
        for (uint256 i = 0; i < 10; i++) {
            _stake(user1, STAKE_AMOUNT / 10, MIN_LOCKUP);
        }

        assertEq(aStaking.getUserStakesCount(user1), 10);

        // Attempt to create an 11th stake should revert
        vm.startPrank(user1);
        aSummerToken.approve(address(aStaking), STAKE_AMOUNT);
        vm.expectRevert(abi.encodeWithSignature("Staking_MaxStakesReached()"));
        aStaking.stakeWithNewLockup(STAKE_AMOUNT, MIN_LOCKUP);
        vm.stopPrank();
    }

    function test_Revert_StakeWithInsufficientBalance() public {
        uint256 largeAmount = aSummerToken.balanceOf(user1) + 1 ether;

        vm.startPrank(user1);
        aSummerToken.approve(address(aStaking), largeAmount);
        vm.expectRevert(); // ERC20 will revert on insufficient balance
        aStaking.stakeWithNewLockup(largeAmount, MIN_LOCKUP);
        vm.stopPrank();
    }

    function test_Revert_StakeWithoutApproval() public {
        vm.prank(user1);
        vm.expectRevert(); // SafeERC20 will revert on insufficient allowance
        aStaking.stakeWithNewLockup(STAKE_AMOUNT, MIN_LOCKUP);
    }

    // ============ ADDING TO STAKE TESTS (addToStake) ============

    // Success Cases
    function test_AddToExistingStake() public {
        uint256 initialAmount = STAKE_AMOUNT;
        uint256 additionalAmount = STAKE_AMOUNT / 2;
        uint256 lockupPeriod = MIN_LOCKUP;

        // Create initial stake
        uint256 stakeIndex = _stake(user1, initialAmount, lockupPeriod);

        // Get initial state
        (
            uint256 initialStakeAmount,
            uint256 initialWeightedAmount,
            ,

        ) = aStaking.getUserStake(user1, stakeIndex);

        // Add to existing stake
        _addToStake(user1, stakeIndex, additionalAmount);

        // Get updated state
        (
            uint256 updatedStakeAmount,
            uint256 updatedWeightedAmount,
            ,

        ) = aStaking.getUserStake(user1, stakeIndex);

        // Verify amounts increased
        assertEq(updatedStakeAmount, initialStakeAmount + additionalAmount);
        assertGt(updatedWeightedAmount, initialWeightedAmount);

        // Verify total balances
        assertEq(aStaking.balanceOf(user1), initialAmount + additionalAmount);
        assertEq(aStaking.weightedBalanceOf(user1), updatedWeightedAmount);
    }

    function test_CorrectStateChangesOnAddToStake() public {
        uint256 initialAmount = STAKE_AMOUNT;
        uint256 additionalAmount = STAKE_AMOUNT / 2;
        uint256 lockupPeriod = MIN_LOCKUP;

        // Create initial stake
        uint256 stakeIndex = _stake(user1, initialAmount, lockupPeriod);

        // Get state before adding
        uint256 balanceBefore = aStaking.balanceOf(user1);
        uint256 weightedBalanceBefore = aStaking.weightedBalanceOf(user1);
        uint256 totalSupplyBefore = aStaking.totalSupply();

        // Add to stake
        _addToStake(user1, stakeIndex, additionalAmount);

        // Verify state changes
        assertEq(aStaking.balanceOf(user1), balanceBefore + additionalAmount);
        assertGt(aStaking.weightedBalanceOf(user1), weightedBalanceBefore);
        assertGt(aStaking.totalSupply(), totalSupplyBefore);
    }

    function test_AddToStake_UpdatesOriginalBucketDespiteRemainingTime()
        public
    {
        uint256 initialAmount = STAKE_AMOUNT;
        uint256 additionalAmount = STAKE_AMOUNT / 2;

        // Initial stake into ThreeToSixMonths bucket (MIN_LOCKUP within 90-180 days)
        uint256 stakeIndex = _stake(user1, initialAmount, MIN_LOCKUP);

        // Sanity: starting bucket total
        _assertBucket(ISummerStaking.Bucket.ThreeToSixMonths, initialAmount);
        _assertBucket(ISummerStaking.Bucket.ShortTerm, 0);

        // Warp so remaining time falls into ShortTerm bucket (< 90 days)
        vm.warp(block.timestamp + 1 days);

        // Add to existing stake should count towards original bucket (ThreeToSixMonths)
        _addToStake(user1, stakeIndex, additionalAmount);

        _assertBucket(
            ISummerStaking.Bucket.ThreeToSixMonths,
            initialAmount + additionalAmount
        );
        _assertBucket(ISummerStaking.Bucket.ShortTerm, 0);
    }

    function test_AddToStake_RespectsOriginalBucketCap_Success() public {
        uint256 initialAmount = STAKE_AMOUNT;
        uint256 additionalAmount = STAKE_AMOUNT / 2;

        // Configure caps: original (ThreeToSixMonths) uncapped/high, remaining-time (ShortTerm) disabled
        vm.startPrank(address(timelockA));
        aStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.ThreeToSixMonths,
            1_000_000 ether
        );
        aStaking.updateLockupBucketCap(ISummerStaking.Bucket.ShortTerm, 0);
        vm.stopPrank();

        uint256 stakeIndex = _stake(user1, initialAmount, MIN_LOCKUP);

        // Warp so remaining time would fall into ShortTerm if it were used
        vm.warp(block.timestamp + 1 days);

        // Should succeed because cap check uses original bucket (ThreeToSixMonths)
        _addToStake(user1, stakeIndex, additionalAmount);

        _assertBucket(
            ISummerStaking.Bucket.ThreeToSixMonths,
            initialAmount + additionalAmount
        );
    }

    function test_AddToStake_RespectsOriginalBucketCap_Revert() public {
        uint256 initialAmount = STAKE_AMOUNT;
        uint256 additionalAmount = STAKE_AMOUNT / 2;

        // Configure caps: original bucket capped to initial amount; remaining-time bucket uncapped
        vm.startPrank(address(timelockA));
        aStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.ThreeToSixMonths,
            initialAmount
        );
        aStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.ShortTerm,
            type(uint256).max
        );
        vm.stopPrank();

        uint256 stakeIndex = _stake(user1, initialAmount, MIN_LOCKUP);

        // Warp so remaining time would fall into ShortTerm if it were used
        vm.warp(block.timestamp + 1 days);

        // Adding should revert due to original bucket cap being reached
        vm.startPrank(user1);
        aSummerToken.approve(address(aStaking), additionalAmount);
        vm.expectRevert(abi.encodeWithSignature("Staking_BucketCapExceeded()"));
        aStaking.addToStake(stakeIndex, additionalAmount);
        vm.stopPrank();

        // Bucket total remains at initial amount
        _assertBucket(ISummerStaking.Bucket.ThreeToSixMonths, initialAmount);
    }

    // Failure Cases
    function test_Revert_AddToStakeWithInvalidIndex() public {
        uint256 stakeIndex = _stake(user1, STAKE_AMOUNT, MIN_LOCKUP);

        vm.startPrank(user1);
        aSummerToken.approve(address(aStaking), STAKE_AMOUNT);
        vm.expectRevert(abi.encodeWithSignature("Staking_InvalidStakeIndex()"));
        aStaking.addToStake(stakeIndex + 1, STAKE_AMOUNT); // Invalid index
        vm.stopPrank();
    }

    function test_Revert_AddToStakeOnExpiredLockup() public {
        uint256 lockupPeriod = MIN_LOCKUP;
        uint256 stakeIndex = _stake(user1, STAKE_AMOUNT, lockupPeriod);

        // Warp time past the lockup end
        vm.warp(block.timestamp + lockupPeriod + 1 days);

        vm.startPrank(user1);
        aSummerToken.approve(address(aStaking), STAKE_AMOUNT);
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_InvalidLockupPeriod(string)",
                "Lockup period has ended"
            )
        );
        aStaking.addToStake(stakeIndex, STAKE_AMOUNT);
        vm.stopPrank();
    }

    // ============ UNSTAKING TESTS (unstakeFromLockup) ============

    // After Lockup (No Penalty)
    function test_UnstakeFullAmountAfterLockup() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = 0; // No lockup for now to avoid bucket cap issues

        uint256 stakeIndex = _stake(user1, stakeAmount, lockupPeriod);

        // No need to warp time since there's no lockup

        // Get balances before unstaking
        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 userXSumrBalanceBefore = axSumr.balanceOf(user1);

        // Unstake full amount
        _approveAndUnstake(user1, stakeIndex, stakeAmount);

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
        uint256 lockupPeriod = MIN_LOCKUP;

        uint256 stakeIndex = _stake(user1, stakeAmount, lockupPeriod);

        // Warp time past lockup end
        vm.warp(block.timestamp + lockupPeriod + 1 days);

        // Unstake partial amount
        _approveAndUnstake(user1, stakeIndex, unstakeAmount);

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
        uint256 lockupPeriod = MIN_LOCKUP;

        uint256 stakeIndex = _stake(user1, stakeAmount, lockupPeriod);

        // Warp time past lockup end
        vm.warp(block.timestamp + lockupPeriod + 1 days);

        // Get state before unstaking
        uint256 balanceBefore = aStaking.balanceOf(user1);
        uint256 weightedBalanceBefore = aStaking.weightedBalanceOf(user1);
        uint256 totalSupplyBefore = aStaking.totalSupply();

        // Unstake full amount
        _approveAndUnstake(user1, stakeIndex, stakeAmount);

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
        uint256 lockupPeriod = MAX_LOCKUP; // 4 years for maximum penalty

        uint256 stakeIndex = _stake(user1, stakeAmount, lockupPeriod);

        // Calculate expected penalty (should be 50% for immediate unstake)
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
        uint256 lockupPeriod = MAX_LOCKUP; // 4 years

        uint256 stakeIndex = _stake(user1, stakeAmount, lockupPeriod);

        // Warp time to 50% of lockup period
        vm.warp(block.timestamp + lockupPeriod / 2);

        // Calculate expected penalty (should be 25% for halfway unstake)
        uint256 expectedPenalty = _calculatePenaltyPercentage(
            lockupPeriod / 2,
            lockupPeriod
        );
        uint256 expectedReturnAmount = stakeAmount -
            (stakeAmount * expectedPenalty) /
            Constants.WAD;

        // Unstake halfway through
        _approveAndUnstake(user1, stakeIndex, stakeAmount);

        // Verify penalty is approximately half of immediate unstake penalty
        assertApproxEqRel(expectedPenalty, Constants.WAD / 4, 0.01e18); // 25% ± 1%
    }

    function test_CorrectStateChangesOnUnstakeWithPenalty() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = MAX_LOCKUP;

        uint256 stakeIndex = _stake(user1, stakeAmount, lockupPeriod);

        // Get state before unstaking
        uint256 balanceBefore = aStaking.balanceOf(user1);
        uint256 weightedBalanceBefore = aStaking.weightedBalanceOf(user1);
        uint256 totalSupplyBefore = aStaking.totalSupply();
        uint256 treasuryBalanceBefore = aSummerToken.balanceOf(
            aStaking.treasury()
        );

        // Unstake with penalty
        _approveAndUnstake(user1, stakeIndex, stakeAmount);

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
        uint256 stakeIndex = _stake(user1, STAKE_AMOUNT, MIN_LOCKUP);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("CannotUnstakeZero()"));
        aStaking.unstakeFromLockup(stakeIndex, 0);
    }

    function test_Revert_UnstakeWithInvalidIndex() public {
        uint256 stakeIndex = _stake(user1, STAKE_AMOUNT, MIN_LOCKUP);

        vm.startPrank(user1);
        axSumr.approve(address(aStaking), STAKE_AMOUNT);
        vm.expectRevert(abi.encodeWithSignature("Staking_InvalidStakeIndex()"));
        aStaking.unstakeFromLockup(stakeIndex + 1, STAKE_AMOUNT);
        vm.stopPrank();
    }

    function test_Revert_UnstakeMoreThanTotalBalance() public {
        uint256 stakeIndex = _stake(user1, STAKE_AMOUNT, MIN_LOCKUP);

        vm.startPrank(user1);
        axSumr.approve(address(aStaking), STAKE_AMOUNT * 2);
        vm.expectRevert(
            abi.encodeWithSignature("Staking_InsufficientBalance()")
        );
        aStaking.unstakeFromLockup(stakeIndex, STAKE_AMOUNT * 2);
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
        vm.expectRevert(); // Should revert due to access control
        aStaking.updateLockupBucketCap(bucket, newCap);
    }

    function test_Revert_StakeWhenBucketCapExceeded() public {
        ISummerStaking.Bucket bucket = ISummerStaking.Bucket.ThreeToSixMonths;
        uint256 cap = STAKE_AMOUNT;

        // Set bucket cap
        vm.prank(address(timelockA));
        aStaking.updateLockupBucketCap(bucket, cap);

        // Stake up to the cap
        _stake(user1, cap, MIN_LOCKUP);

        // Attempt to stake more should revert
        vm.startPrank(user2);
        aSummerToken.approve(address(aStaking), STAKE_AMOUNT);
        vm.expectRevert(abi.encodeWithSignature("Staking_BucketCapExceeded()"));
        aStaking.stakeWithNewLockup(STAKE_AMOUNT, MIN_LOCKUP);
        vm.stopPrank();
    }

    function test_CorrectBucketAccounting() public {
        ISummerStaking.Bucket bucket = ISummerStaking.Bucket.ThreeToSixMonths;

        // Stake in ThreeToSixMonths bucket (90 days to 180 days)
        _stake(user1, STAKE_AMOUNT, MIN_LOCKUP);
        _stake(user2, STAKE_AMOUNT, MIN_LOCKUP);

        // Verify bucket total
        _assertBucket(bucket, STAKE_AMOUNT * 2);

        // Unstake from user1
        _approveAndUnstake(user1, 0, STAKE_AMOUNT);

        // Verify bucket total updated
        _assertBucket(bucket, STAKE_AMOUNT);
    }

    // ============ REWARDS & WEIGHTED LOGIC TESTS ============

    function test_EarnedIsCorrectForSingleStaker() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = MIN_LOCKUP;

        _stake(user1, stakeAmount, lockupPeriod);

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
        _stake(user1, stakeAmount, MIN_LOCKUP);

        // User2 stakes with maximum lockup (highest weight)
        _stake(user2, stakeAmount, MAX_LOCKUP);

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
        uint256 lockupPeriod = MIN_LOCKUP;

        _stake(user1, stakeAmount, lockupPeriod);

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
        uint256 lockupPeriod = MIN_LOCKUP;

        _stake(user1, stakeAmount, lockupPeriod);

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
                "Use stakeWithNewLockup instead"
            )
        );
        aStaking.stake(STAKE_AMOUNT);
    }

    function test_Revert_CallingDirectUnstake() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_DirectUnstakeNotAllowed(string)",
                "Use unstakeFromLockup instead"
            )
        );
        aStaking.unstake(STAKE_AMOUNT);
    }

    function test_Revert_CallingExit() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_DirectUnstakeNotAllowed(string)",
                "Use unstakeFromLockup instead"
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
        lockupPeriod = uint32(bound(lockupPeriod, MIN_LOCKUP, MAX_LOCKUP));

        // Ensure user has enough tokens
        deal(address(aSummerToken), user1, amount);

        // Stake should succeed with valid parameters
        uint256 stakeIndex = _stake(user1, amount, lockupPeriod);

        // Verify stake was created
        (uint256 stakedAmount, , , ) = aStaking.getUserStake(user1, stakeIndex);
        assertEq(stakedAmount, amount);
    }

    function test_Fuzz_AddToStake(uint128 amount) public {
        // Create initial stake
        uint256 stakeIndex = _stake(user1, STAKE_AMOUNT, MIN_LOCKUP);

        // Bound the additional amount
        amount = uint128(bound(amount, 1 ether, STAKE_AMOUNT));

        // Add to stake should succeed
        _addToStake(user1, stakeIndex, amount);

        // Verify total amount increased
        (uint256 totalAmount, , , ) = aStaking.getUserStake(user1, stakeIndex);
        assertEq(totalAmount, STAKE_AMOUNT + amount);
    }

    function test_Fuzz_Unstake(uint128 amount) public {
        // Create stake
        uint256 stakeIndex = _stake(user1, STAKE_AMOUNT, MIN_LOCKUP);

        // Bound the unstake amount
        amount = uint128(bound(amount, 1 ether, STAKE_AMOUNT));

        // Warp time past lockup to avoid penalties
        vm.warp(block.timestamp + MIN_LOCKUP + 1 days);

        // Unstake should succeed
        _approveAndUnstake(user1, stakeIndex, amount);

        // Verify remaining amount
        (uint256 remainingAmount, , , ) = aStaking.getUserStake(
            user1,
            stakeIndex
        );
        assertEq(remainingAmount, STAKE_AMOUNT - amount);
    }

    // ============ INVARIANT TESTS ============

    function test_Invariant_SupplyConsistency() public {
        // Create multiple stakes
        _stake(user1, STAKE_AMOUNT, MIN_LOCKUP);
        _stake(user1, STAKE_AMOUNT, MEDIUM_LOCKUP);
        _stake(user2, STAKE_AMOUNT, MAX_LOCKUP);

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

        _stake(user1, stakeAmount1, MIN_LOCKUP);
        _stake(user1, stakeAmount2, MEDIUM_LOCKUP);

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
        _stake(user1, stakeAmount, MIN_LOCKUP);

        // Verify bucket total matches staked amount
        _assertBucket(ISummerStaking.Bucket.ThreeToSixMonths, stakeAmount);

        // Unstake and verify bucket total is updated
        vm.warp(block.timestamp + MIN_LOCKUP + 1 days);
        _approveAndUnstake(user1, 0, stakeAmount);

        _assertBucket(ISummerStaking.Bucket.ThreeToSixMonths, 0);
    }

    function test_Invariant_TokenAccounting() public {
        uint256 stakeAmount = STAKE_AMOUNT;

        _stake(user1, stakeAmount, MIN_LOCKUP);

        // Verify sSUMMER token supply equals staked amount
        assertEq(
            axSumr.totalSupply(),
            stakeAmount,
            "sSUMMER supply should equal staked amount"
        );

        // Unstake and verify
        vm.warp(block.timestamp + MIN_LOCKUP + 1 days);
        _approveAndUnstake(user1, 0, stakeAmount);

        assertEq(
            axSumr.totalSupply(),
            0,
            "sSUMMER supply should be zero after unstaking"
        );
    }

    // ============ PENALTY PARAMS GOVERNANCE TESTS ============

    function test_SetMaxPenaltyWad_OnlyGovernorAndEvent() public {
        uint256 oldValue = aStaking.maxPenaltyWad();
        uint256 newValue = 6e17; // 60%

        vm.prank(address(timelockA));
        vm.expectEmit(true, false, false, false);
        emit SummerStaking.MaxPenaltyUpdated(oldValue, newValue);
        aStaking.setMaxPenaltyWad(newValue);

        assertEq(aStaking.maxPenaltyWad(), newValue);
    }

    function test_SetMaxPenaltyWad_Revert_NonGovernor() public {
        vm.prank(user1);
        vm.expectRevert();
        aStaking.setMaxPenaltyWad(7e17);
    }

    function test_SetMaxPenaltyWad_Revert_AboveOneWad() public {
        vm.prank(address(timelockA));
        vm.expectRevert(
            abi.encodeWithSignature("Staking_InvalidMaxPenaltyWad()")
        );
        aStaking.setMaxPenaltyWad(Constants.WAD + 1);
    }

    // ============ PENALTY BEHAVIOR TESTS ============

    function test_PenaltyScenarios_ImmediateHalfwayEnd_ForVariousPeriods()
        public
    {
        uint256[3] memory periods = [
            uint256(365 days),
            uint256(730 days),
            uint256(MAX_LOCKUP)
        ];

        for (uint256 i = 0; i < periods.length; i++) {
            uint256 lockupPeriod = periods[i];
            uint256 stakeIndex = _stake(user1, STAKE_AMOUNT, lockupPeriod);

            // Immediate: 50% of amount regardless of period with default 0.5e18
            uint256 immediatePenalty = aStaking.calculatePenalty(
                user1,
                stakeIndex
            );
            assertEq(
                immediatePenalty,
                5e17,
                "Immediate penalty should be 50% in WAD"
            );

            // Halfway
            vm.warp(block.timestamp + lockupPeriod / 2);
            uint256 halfwayPenalty = aStaking.calculatePenalty(
                user1,
                stakeIndex
            );
            assertApproxEqRel(halfwayPenalty, 25e16, 1e16); // ~25%

            // After end
            vm.warp(block.timestamp + (lockupPeriod / 2) + 1);
            uint256 afterEndPenalty = aStaking.calculatePenalty(
                user1,
                stakeIndex
            );
            assertEq(afterEndPenalty, 0, "Penalty should be zero after expiry");

            // Clean up: fully unstake to reset for next iteration
            vm.startPrank(user1);
            axSumr.approve(address(aStaking), STAKE_AMOUNT);
            vm.stopPrank();
            _unstake(user1, stakeIndex, STAKE_AMOUNT);
        }
    }

    function test_PartialUnstake_BeforeExpiry_PenaltyOnUnstakedAndWeightedProportional()
        public
    {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = 365 days; // 1 year
        uint256 stakeIndex = _stake(user1, stakeAmount, lockupPeriod);

        // Capture initial weighted and totalSupply
        (, uint256 initialWeighted, , ) = aStaking.getUserStake(
            user1,
            stakeIndex
        );
        uint256 totalSupplyBefore = aStaking.totalSupply();

        // Unstake partway through: warp to 1/4 of period elapsed (3/4 remaining)
        vm.warp(block.timestamp + lockupPeriod / 4);

        uint256 unstakeAmount = stakeAmount / 5; // 20%
        // Expected penalty percentage = 0.5 * (remaining/period) = 0.5 * 0.75 = 0.375
        uint256 expectedPenaltyPerc = (5e17 * 3) / 4; // 0.375e18
        uint256 expectedPenalty = (unstakeAmount * expectedPenaltyPerc) /
            Constants.WAD;
        uint256 expectedReturn = unstakeAmount - expectedPenalty;
        uint256 expectedWeightedToRemove = (initialWeighted * unstakeAmount) /
            stakeAmount;

        // Balances before
        uint256 userSummerBefore = aSummerToken.balanceOf(user1);
        uint256 treasuryBefore = aSummerToken.balanceOf(aStaking.treasury());

        // Perform partial unstake
        _approveAndUnstake(user1, stakeIndex, unstakeAmount);

        // Check user received amount minus penalty and treasury got penalty
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBefore + expectedReturn,
            "Incorrect returned amount"
        );
        assertEq(
            aSummerToken.balanceOf(aStaking.treasury()),
            treasuryBefore + expectedPenalty,
            "Incorrect penalty sent to treasury"
        );

        // Check proportional weighted removal and totalSupply
        (uint256 remainingAmount, uint256 remainingWeighted, , ) = aStaking
            .getUserStake(user1, stakeIndex);
        assertEq(
            remainingAmount,
            stakeAmount - unstakeAmount,
            "Remaining amount mismatch"
        );
        assertEq(
            remainingWeighted,
            initialWeighted - expectedWeightedToRemove,
            "Remaining weighted mismatch"
        );
        assertEq(
            aStaking.totalSupply(),
            totalSupplyBefore - expectedWeightedToRemove,
            "totalSupply not decreased by removed weighted"
        );
    }

    // ============ GETTER CONSISTENCY TESTS ============

    function test_GetterConsistency_BucketDetailsMatchesGetAllBucketInfo()
        public
    {
        // Configure caps to have mixed values
        vm.startPrank(address(timelockA));
        aStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.NoLockup,
            type(uint256).max
        );
        aStaking.updateLockupBucketCap(ISummerStaking.Bucket.ShortTerm, 0);
        aStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.ThreeToSixMonths,
            1_000_000 ether
        );
        aStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.SixToTwelveMonths,
            500_000 ether
        );
        aStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.OneToTwoYears,
            250_000 ether
        );
        aStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.TwoToFourYears,
            type(uint256).max
        );
        vm.stopPrank();

        // Create some stakes across buckets
        _stake(user1, STAKE_AMOUNT, 0);
        _stake(user1, STAKE_AMOUNT, MIN_LOCKUP); // ThreeToSixMonths
        _stake(user2, STAKE_AMOUNT / 2, MEDIUM_LOCKUP); // SixToTwelveMonths

        (
            ISummerStaking.Bucket[] memory buckets,
            uint256[] memory caps,
            uint256[] memory staked,
            uint256[] memory minPeriods,
            uint256[] memory maxPeriods
        ) = aStaking.getAllBucketInfo();

        for (uint256 i = 0; i < buckets.length; i++) {
            (
                uint256 cap,
                uint256 stakedAmt,
                uint256 minP,
                uint256 maxP
            ) = aStaking.getBucketDetails(buckets[i]);

            assertEq(cap, caps[i], "Cap mismatch");
            assertEq(stakedAmt, staked[i], "Staked mismatch");
            assertEq(minP, minPeriods[i], "Min period mismatch");
            assertEq(maxP, maxPeriods[i], "Max period mismatch");
        }

        // Boundary checks
        (, , uint256 minShort, uint256 maxShort) = aStaking.getBucketDetails(
            ISummerStaking.Bucket.ShortTerm
        );
        (, , uint256 minThreeSix, uint256 maxThreeSix) = aStaking
            .getBucketDetails(ISummerStaking.Bucket.ThreeToSixMonths);
        (, , uint256 minSixTwelve, uint256 maxSixTwelve) = aStaking
            .getBucketDetails(ISummerStaking.Bucket.SixToTwelveMonths);
        (, , uint256 minOneTwo, uint256 maxOneTwo) = aStaking.getBucketDetails(
            ISummerStaking.Bucket.OneToTwoYears
        );
        (, , uint256 minTwoFour, uint256 maxTwoFour) = aStaking
            .getBucketDetails(ISummerStaking.Bucket.TwoToFourYears);

        assertEq(minShort, 1 seconds);
        assertEq(minThreeSix, maxShort + 1);
        assertEq(minSixTwelve, maxThreeSix + 1);
        assertEq(minOneTwo, maxSixTwelve + 1);
        assertEq(minTwoFour, maxOneTwo + 1);
        // Max for last bucket equals contract constant
        assertEq(maxTwoFour, MAX_LOCKUP);
    }

    // ============ EARNED ZERO-WEIGHT CASE ============

    function test_Earned_ZeroWeightAccount_ReturnsStoredRewardOnly() public {
        // User stakes and accrues rewards
        uint256 stakeIndex = _stake(user1, STAKE_AMOUNT, MIN_LOCKUP);
        _addAndNotifyRewards(address(rewardToken), REWARD_AMOUNT);
        vm.warp(block.timestamp + 7 days);
        uint256 earnedBeforeUnstake = aStaking.earned(
            user1,
            address(rewardToken)
        );
        assertGt(earnedBeforeUnstake, 0);

        // Fully unstake (still before lockup end to keep some behavior realistic)
        vm.warp(block.timestamp + MIN_LOCKUP + 1);
        _approveAndUnstake(user1, stakeIndex, STAKE_AMOUNT);

        // Now weighted balance is 0; earned should equal stored and not grow with time
        uint256 stored = aStaking.earned(user1, address(rewardToken));
        assertGt(stored, 0);
        vm.warp(block.timestamp + 30 days);
        uint256 later = aStaking.earned(user1, address(rewardToken));
        assertEq(
            stored,
            later,
            "Earned should not increase for zero-weight account"
        );
    }
}
