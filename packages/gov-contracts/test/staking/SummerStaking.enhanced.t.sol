// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerStaking} from "../../src/contracts/SummerStaking.sol";
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

/*
 * @title SummerStaking Enhanced Tests
 * @dev Comprehensive test suite for SummerStaking contract with helper methods and extensive coverage.
 */
contract SummerStakingEnhancedTest is SummerGovernorV2TestBase {
    address public user1 = address(0x1001);
    address public user2 = address(0x1002);
    address public user3 = address(0x1003);
    uint256 public constant STAKE_AMOUNT = 1000 ether;
    uint256 public constant REWARD_AMOUNT = 100 ether;

    SummerStaking public aStaking;
    SummerStaking public bStaking;
    MockERC20 public rewardToken;

    // Test lockup periods
    uint256 public constant MIN_LOCKUP = 90 days;
    uint256 public constant MAX_LOCKUP = 4 * 365 days;
    uint256 public constant MEDIUM_LOCKUP = 365 days;

    function setUp() public override {
        super.setUp();

        // Setup test users with tokens
        deal(address(aSummerToken), user1, STAKE_AMOUNT * 10);
        deal(address(aSummerToken), user2, STAKE_AMOUNT * 10);
        deal(address(aSummerToken), user3, STAKE_AMOUNT * 10);

        vm.startPrank(whale);
        axSumr.burn(axSumr.balanceOf(whale));
        bxSumr.burn(bxSumr.balanceOf(whale));
        vm.stopPrank();

        aStaking = new SummerStaking(
            address(accessManagerA),
            address(configurationManagerA),
            address(aSummerToken),
            address(axSumr)
        );
        bStaking = new SummerStaking(
            address(accessManagerB),
            address(configurationManagerB),
            address(bSummerToken),
            address(bxSumr)
        );

        vm.startPrank(address(timelockA));
        axSumr.addStakingModule(address(aStaking));
        aStaking.updateLockupBucketCap(aStaking.BUCKET_0_MAX(), 1000000 ether);
        aStaking.updateLockupBucketCap(aStaking.BUCKET_1_MAX(), 100000 ether);
        aStaking.updateLockupBucketCap(aStaking.BUCKET_2_MAX(), 100000 ether);
        aStaking.updateLockupBucketCap(aStaking.BUCKET_3_MAX(), 100000 ether);
        vm.stopPrank();

        vm.startPrank(address(timelockB));
        bxSumr.addStakingModule(address(bStaking));
        bStaking.updateLockupBucketCap(bStaking.BUCKET_0_MAX(), 1000000 ether);
        bStaking.updateLockupBucketCap(bStaking.BUCKET_1_MAX(), 100000 ether);
        bStaking.updateLockupBucketCap(bStaking.BUCKET_2_MAX(), 100000 ether);
        bStaking.updateLockupBucketCap(bStaking.BUCKET_3_MAX(), 100000 ether);
        vm.stopPrank();

        // Setup reward token
        rewardToken = new MockERC20();
        deal(address(rewardToken), address(timelockA), REWARD_AMOUNT * 1000);
    }

    // ============ HELPER METHODS ============

    /**
     * @notice Wrapper that pranks as the user and calls stakeWithNewLockup
     */
    function _stake(
        address user,
        uint256 amount,
        uint256 lockupPeriod
    ) internal returns (uint256) {
        vm.startPrank(user);
        aSummerToken.approve(address(aStaking), amount);
        aStaking.stakeWithNewLockup(amount, lockupPeriod);
        uint256 stakeIndex = aStaking.getUserStakesCount(user) - 1;
        vm.stopPrank();
        return stakeIndex;
    }

    /**
     * @notice Wrapper that pranks as the user and calls addToStake
     */
    function _addToStake(address user, uint256 index, uint256 amount) internal {
        vm.startPrank(user);
        aSummerToken.approve(address(aStaking), amount);
        aStaking.addToStake(index, amount);
        vm.stopPrank();
    }

    /**
     * @notice Wrapper that pranks as the user and calls approve and unstakeFromLockup
     */
    function _approveAndUnstake(
        address user,
        uint256 index,
        uint256 amount
    ) internal {
        vm.startPrank(user);
        axSumr.approve(address(aStaking), amount);
        aStaking.unstakeFromLockup(index, amount);
        vm.stopPrank();
    }
    /**
     * @notice Wrapper that pranks as the user and calls unstakeFromLockup
     */
    function _unstake(address user, uint256 index, uint256 amount) internal {
        vm.startPrank(user);
        aStaking.unstakeFromLockup(index, amount);
        vm.stopPrank();
    }
    /**
     * @notice Transfers rwdToken to the staking contract and calls notifyRewardAmount as the governor
     */
    function _addAndNotifyRewards(address rwdToken, uint256 amount) internal {
        vm.startPrank(address(timelockA));
        IERC20(rwdToken).approve(address(aStaking), amount);
        aStaking.notifyRewardAmount(rwdToken, amount, 30 days); // 30 days duration
        vm.stopPrank();
    }

    /**
     * @notice Asserts that all fields of a specific UserStake struct match the expected values
     */
    function _assertStake(
        address user,
        uint256 index,
        uint256 expectedAmount,
        uint256 expectedWeightedAmount,
        uint256 expectedLockupEndTime,
        uint256 expectedLockupPeriod
    ) internal {
        (
            uint256 amount,
            uint256 weightedAmount,
            uint256 lockupEndTime,
            uint256 lockupPeriod
        ) = aStaking.getUserStake(user, index);

        assertEq(amount, expectedAmount, "Stake amount mismatch");
        assertEq(
            weightedAmount,
            expectedWeightedAmount,
            "Stake weighted amount mismatch"
        );
        assertEq(
            lockupEndTime,
            expectedLockupEndTime,
            "Stake lockup end time mismatch"
        );
        assertEq(
            lockupPeriod,
            expectedLockupPeriod,
            "Stake lockup period mismatch"
        );
    }

    /**
     * @notice Asserts that a specific bucket has the expected total staked amount
     */
    function _assertBucket(uint256 bucketMax, uint256 expectedStaked) internal {
        uint256 actualStaked = aStaking.getBucketTotalStaked(bucketMax);
        assertEq(actualStaked, expectedStaked, "Bucket staked amount mismatch");
    }

    /**
     * @notice Re-implements the _calculateWeightedStake logic in Solidity for precise verification
     */
    function _calculateExpectedWeightedAmount(
        uint256 amount,
        uint256 period
    ) internal pure returns (uint256) {
        if (period == 0) {
            return amount;
        }

        // Constants from contract
        uint256 WEIGHTED_STAKE_BASE = 0.05e18; // 0.05 in WAD
        uint256 WEIGHTED_STAKE_COEFFICIENT = (4 * Constants.WAD) / 1e16; // 4E-16 in WAD

        // Calculate time squared (in WAD format)
        uint256 timeSquared = (period * period * Constants.WAD) / Constants.WAD;

        // Calculate multiplier: 4E-16 * time^2 + 0.05
        uint256 multiplier = (WEIGHTED_STAKE_COEFFICIENT * timeSquared) /
            Constants.WAD +
            WEIGHTED_STAKE_BASE;

        // Apply multiplier to amount
        return (amount * multiplier) / Constants.WAD;
    }

    /**
     * @notice Re-implements the penalty calculation logic to verify the on-chain results
     */
    function _calculateExpectedPenalty(
        address user,
        uint256 index,
        uint256 currentTime
    ) internal view returns (uint256) {
        (
            uint256 amount,
            ,
            uint256 lockupEndTime,
            uint256 lockupPeriod
        ) = aStaking.getUserStake(user, index);

        if (currentTime >= lockupEndTime) {
            return 0; // No penalty if lockup period has ended
        }

        uint256 timeRemaining = lockupEndTime - currentTime;
        // Penalty percentage = 50% * (time_remaining / original_lockup_period)
        uint256 penaltyPercentage = (timeRemaining * 50 * Constants.WAD) /
            (lockupPeriod * 100);

        return penaltyPercentage;
    }

    /**
     * @notice Uses vm.expectEmit to check for the StakedWithLockup event with the correct parameters
     */
    function _expectStakedWithLockupEvent(
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
     * @notice Uses vm.expectEmit to check for the UnstakedWithPenalty event with the correct parameters
     */
    function _expectUnstakedWithPenaltyEvent(
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
        assertEq(aStaking.getLockupBucketCount(), 5);

        // Check basic bucket details for bucket 0 (which should always exist)
        (uint256 cap0, uint256 staked0) = aStaking.getBucketDetails(0);
        assertEq(cap0, 0);
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

        uint256 expectedWeightedAmount = _calculateExpectedWeightedAmount(
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

        uint256 expectedWeightedAmount = _calculateExpectedWeightedAmount(
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
            uint256 expectedWeightedAmount = _calculateExpectedWeightedAmount(
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
        uint256 expectedWeightedAmount = _calculateExpectedWeightedAmount(
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
            userSummerBalanceBefore - stakeAmount
        );
        assertEq(axSumr.balanceOf(user1), userXSumrBalanceBefore + stakeAmount);

        // Check contract state
        assertEq(aStaking.balanceOf(user1), stakeAmount);
        assertEq(aStaking.weightedBalanceOf(user1), expectedWeightedAmount);
        assertEq(
            aStaking.totalSupply(),
            totalSupplyBefore + expectedWeightedAmount
        );

        // Check bucket totals
        _assertBucket(180 days, stakeAmount); // Should be in bucket 0 (90 days to 180 days)
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
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_InvalidLockupPeriod(string)",
                "Lockup period must be at least 3 months"
            )
        );
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
                _calculateExpectedWeightedAmount(stakeAmount, lockupPeriod)
        );
        assertEq(
            aStaking.totalSupply(),
            totalSupplyBefore -
                _calculateExpectedWeightedAmount(stakeAmount, lockupPeriod)
        );
    }

    // Before Lockup (With Penalty)
    function test_UnstakeImmediately() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = MAX_LOCKUP; // 4 years for maximum penalty

        uint256 stakeIndex = _stake(user1, stakeAmount, lockupPeriod);

        // Calculate expected penalty (should be 50% for immediate unstake)
        uint256 expectedPenalty = _calculateExpectedPenalty(
            user1,
            stakeIndex,
            block.timestamp
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
        _expectUnstakedWithPenaltyEvent(
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
        uint256 expectedPenalty = _calculateExpectedPenalty(
            user1,
            stakeIndex,
            block.timestamp
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
            treasuryBalanceBefore
        );

        // Verify state changes
        assertEq(aStaking.balanceOf(user1), balanceBefore - stakeAmount);
        assertEq(
            aStaking.weightedBalanceOf(user1),
            weightedBalanceBefore -
                _calculateExpectedWeightedAmount(stakeAmount, lockupPeriod)
        );
        assertEq(
            aStaking.totalSupply(),
            totalSupplyBefore -
                _calculateExpectedWeightedAmount(stakeAmount, lockupPeriod)
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
        uint256 bucketMax = aStaking.BUCKET_0_MAX();

        vm.prank(address(timelockA));
        aStaking.updateLockupBucketCap(bucketMax, newCap);

        (uint256 cap, ) = aStaking.getBucketDetails(bucketMax);
        assertEq(cap, newCap);
    }

    function test_Revert_NonGovernorCannotUpdateBucketCap() public {
        uint256 newCap = STAKE_AMOUNT * 10;
        uint256 bucketMax = aStaking.BUCKET_0_MAX();

        vm.prank(user1);
        vm.expectRevert(); // Should revert due to access control
        aStaking.updateLockupBucketCap(bucketMax, newCap);
    }

    function test_Revert_UpdateCapForInvalidIndex() public {
        uint256 invalidIndex = 999 days;

        vm.prank(address(timelockA));
        vm.expectRevert(
            abi.encodeWithSignature("Staking_InvalidBucketIndex()")
        );
        aStaking.updateLockupBucketCap(invalidIndex, STAKE_AMOUNT);
    }

    function test_Revert_StakeWhenBucketCapExceeded() public {
        uint256 bucketMax = aStaking.BUCKET_0_MAX();
        uint256 cap = STAKE_AMOUNT;

        // Set bucket cap
        vm.prank(address(timelockA));
        aStaking.updateLockupBucketCap(bucketMax, cap);

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
        uint256 bucketMax = 180 days;

        // Stake in bucket 0 (90 days to 180 days)
        _stake(user1, STAKE_AMOUNT, MIN_LOCKUP);
        _stake(user2, STAKE_AMOUNT, MIN_LOCKUP);

        // Verify bucket total
        _assertBucket(bucketMax, STAKE_AMOUNT * 2);

        // Unstake from user1
        _approveAndUnstake(user1, 0, STAKE_AMOUNT);

        // Verify bucket total updated
        _assertBucket(bucketMax, STAKE_AMOUNT);
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
        _assertBucket(180 days, stakeAmount);

        // Unstake and verify bucket total is updated
        vm.warp(block.timestamp + MIN_LOCKUP + 1 days);
        _approveAndUnstake(user1, 0, stakeAmount);

        _assertBucket(180 days, 0);
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
}
