// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerStaking} from "../../src/contracts/SummerStaking.sol";
import {ISummerStaking} from "../../src/interfaces/ISummerStaking.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Constants} from "@summerfi/constants/Constants.sol";
import {SummerGovernorV2TestBase} from "../governorV2/SummerGovernorV2TestBase.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {UD60x18, ud60x18, convert} from "@prb/math/src/UD60x18.sol";

/*
 * @title SummerStaking Test Base
 * @dev Base contract for SummerStaking tests with common helper methods.
 */
contract SummerStakingTestBase is SummerGovernorV2TestBase {
    uint256 public constant STAKE_AMOUNT = 1000 ether;
    uint256 public constant REWARD_AMOUNT = 100 ether;
    uint256 public constant DEFAULT_CAP_AMOUNT = 100000 ether;
    uint256 public constant MAX_CAP_AMOUNT = type(uint256).max;

    SummerStaking public aStaking;
    SummerStaking public bStaking;
    MockERC20 public rewardToken;

    // Test lockup periods

    uint256 public constant MEDIUM_LOCKUP = 365 days;
    uint256 public aMaxPenaltyPercentage;
    uint256 public bMaxPenaltyPercentage;
    uint256 public aMinPenaltyPercentage;
    uint256 public bMinPenaltyPercentage;
    uint256 public aMaxLockupPeriod;
    uint256 public bMaxLockupPeriod;
    uint256 public aMinLockupPeriod;
    uint256 public bMinLockupPeriod;

    function setUp() public virtual override {
        super.setUp();

        // Setup test users with tokens
        deal(address(aSummerToken), user1, STAKE_AMOUNT * 3);
        deal(address(aSummerToken), user2, STAKE_AMOUNT * 3);

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

        aMaxPenaltyPercentage = aStaking.MAX_PENALTY_PERCENTAGE();
        bMaxPenaltyPercentage = bStaking.MAX_PENALTY_PERCENTAGE();
        aMaxLockupPeriod = aStaking.MAX_LOCKUP_PERIOD();
        bMaxLockupPeriod = bStaking.MAX_LOCKUP_PERIOD();
        aMinLockupPeriod = aStaking.BUCKET_SHORT_TERM_MAX() + 1;
        bMinLockupPeriod = bStaking.BUCKET_SHORT_TERM_MAX() + 1;
        aMinPenaltyPercentage = aStaking.MIN_PENALTY_PERCENTAGE();
        bMinPenaltyPercentage = bStaking.MIN_PENALTY_PERCENTAGE();

        vm.startPrank(address(timelockA));
        axSumr.addStakingModule(address(aStaking));
        aStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.NoLockup,
            type(uint256).max
        );
        aStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.TwoWeeksToThreeMonths,
            DEFAULT_CAP_AMOUNT
        );
        aStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.ThreeToSixMonths,
            DEFAULT_CAP_AMOUNT
        );
        aStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.SixToTwelveMonths,
            DEFAULT_CAP_AMOUNT
        );
        aStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.OneToTwoYears,
            DEFAULT_CAP_AMOUNT
        );
        aStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.TwoToThreeYears,
            DEFAULT_CAP_AMOUNT
        );
        vm.stopPrank();

        vm.startPrank(address(timelockB));
        bxSumr.addStakingModule(address(bStaking));
        bStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.NoLockup,
            type(uint256).max
        );
        bStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.TwoWeeksToThreeMonths,
            DEFAULT_CAP_AMOUNT
        );
        bStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.ThreeToSixMonths,
            DEFAULT_CAP_AMOUNT
        );
        bStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.SixToTwelveMonths,
            DEFAULT_CAP_AMOUNT
        );
        bStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.OneToTwoYears,
            DEFAULT_CAP_AMOUNT
        );
        bStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.TwoToThreeYears,
            DEFAULT_CAP_AMOUNT
        );
        vm.stopPrank();

        // Setup reward token
        rewardToken = new MockERC20();
        deal(address(rewardToken), address(timelockA), REWARD_AMOUNT * 1000);
    }

    // ============ GOVERNANCE INTEGRATION HELPERS ============

    /**
     * @notice Internal helper to stake tokens for a user and delegate
     */
    function stakeAndDelegate(
        address user,
        uint256 amount,
        bool delegateToSelf
    ) internal {
        vm.startPrank(user);
        aSummerToken.approve(address(aStaking), amount);
        aStaking.stakeLockup(amount, 0);
        if (delegateToSelf) {
            axSumr.delegate(user);
        }
        vm.stopPrank();
        // SummerGovernorV2TestBase gives the whale 100% of the StakedSummerToken supply
        // to make the tests easier and make total gov token invariant we burn the amount of tokens
        // that are staked for the user
        vm.startPrank(whale);
        axSumr.burn(amount);
        vm.stopPrank();
    }

    /**
     * @notice Internal helper to create a proposal for testing governance integration
     */
    function createStakingProposal()
        internal
        returns (uint256 proposalId, address[] memory targets)
    {
        targets = new address[](1);
        targets[0] = address(testToken);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            bob,
            1000
        );

        string memory description = "Test proposal for staking integration";

        proposalId = governorA.propose(targets, values, calldatas, description);
        return (proposalId, targets);
    }

    // ============ HELPER METHODS ============

    /**
     * @notice Helper function to create a fresh staking contract for isolated tests
     */
    function createFreshStaking() internal returns (SummerStaking) {
        SummerStaking freshStaking = new SummerStaking(
            address(accessManagerA),
            address(configurationManagerA),
            address(aSummerToken),
            address(axSumr)
        );

        // Set staking module so freshStaking can mint/burn StakedSummerToken
        vm.prank(address(timelockA));
        axSumr.addStakingModule(address(freshStaking));

        return freshStaking;
    }

    /**
     * @notice Helper function to create a fresh staking contract for isolated tests
     */
    function createFreshStakingWithDefaultCaps()
        internal
        returns (SummerStaking)
    {
        SummerStaking freshStaking = new SummerStaking(
            address(accessManagerA),
            address(configurationManagerA),
            address(aSummerToken),
            address(axSumr)
        );
        vm.startPrank(address(timelockA));
        freshStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.NoLockup,
            type(uint256).max
        );
        freshStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.TwoWeeksToThreeMonths,
            DEFAULT_CAP_AMOUNT
        );
        freshStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.ThreeToSixMonths,
            DEFAULT_CAP_AMOUNT
        );
        freshStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.SixToTwelveMonths,
            DEFAULT_CAP_AMOUNT
        );
        freshStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.OneToTwoYears,
            DEFAULT_CAP_AMOUNT
        );
        freshStaking.updateLockupBucketCap(
            ISummerStaking.Bucket.TwoToThreeYears,
            DEFAULT_CAP_AMOUNT
        );
        vm.stopPrank();
        // Set staking module so freshStaking can mint/burn StakedSummerToken

        axSumr.addStakingModule(address(freshStaking));
        uint256[] memory expectedBucketCaps = new uint256[](7);
        expectedBucketCaps[0] = MAX_CAP_AMOUNT;
        expectedBucketCaps[1] = 0;
        expectedBucketCaps[2] = DEFAULT_CAP_AMOUNT;
        expectedBucketCaps[3] = DEFAULT_CAP_AMOUNT;
        expectedBucketCaps[4] = DEFAULT_CAP_AMOUNT;
        expectedBucketCaps[5] = DEFAULT_CAP_AMOUNT;
        expectedBucketCaps[6] = DEFAULT_CAP_AMOUNT;
        _verifyBucketCaps(freshStaking, expectedBucketCaps);

        return freshStaking;
    }
    /**
     * @notice Wrapper that pranks as the user and calls stakeLockup
     * @param user The address of the user staking
     * @param amount The amount of tokens to stake
     * @param lockupPeriod The lockup period in seconds
     * @return The index of the stake
     */
    function _stake(
        SummerStaking staking,
        address user,
        uint256 amount,
        uint256 lockupPeriod
    ) internal returns (uint256) {
        vm.startPrank(user);
        aSummerToken.approve(address(staking), amount);
        staking.stakeLockup(amount, lockupPeriod);
        uint256 stakeIndex = lockupPeriod == 0
            ? 0
            : staking.getUserStakesCount(user) - 1;
        vm.stopPrank();
        return stakeIndex;
    }

    /**
     * @notice Wrapper that pranks as the user and calls approve and unstakeLockup
     */
    function _approveAndUnstake(
        SummerStaking staking,
        address user,
        uint256 index,
        uint256 amount
    ) internal {
        vm.startPrank(user);
        axSumr.approve(address(staking), amount);
        staking.unstakeLockup(index, amount);
        vm.stopPrank();
    }

    /**
     * @notice Wrapper that pranks as the user and calls unstakeLockup
     */
    function _unstake(address user, uint256 index, uint256 amount) internal {
        vm.startPrank(user);
        aStaking.unstakeLockup(index, amount);
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
    ) internal view {
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
    function _assertBucket(
        ISummerStaking.Bucket bucket,
        uint256 expectedStaked
    ) internal view {
        uint256 actualStaked = aStaking.getBucketTotalStaked(bucket);
        assertEq(actualStaked, expectedStaked, "Bucket staked amount mismatch");
    }

    /**
     * @notice Uses vm.expectEmit to check for the StakedWithLockup event with the correct parameters
     */
    function _expectStakedWithLockupEvent(
        address user,
        uint256 stakeIndex,
        uint256 amount,
        uint256 lockupPeriod,
        uint256 weightedAmount
    ) internal {
        vm.expectEmit(true, false, false, false);
        emit ISummerStaking.StakedWithLockup(
            user,
            stakeIndex,
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
        uint256 stakeIndex,
        uint256 unstaked,
        uint256 penalty,
        uint256 returnAmount
    ) internal {
        vm.expectEmit(true, false, false, false);
        emit ISummerStaking.UnstakedWithPenalty(
            user,
            stakeIndex,
            unstaked,
            penalty,
            returnAmount
        );
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
        SummerStaking staking,
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
            stakeIndices[i] = _stake(
                staking,
                user,
                amounts[i],
                lockupPeriods[i]
            );
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
        // Constants from contract
        uint256 WEIGHTED_STAKE_BASE = 1e18;
        uint256 WEIGHTED_STAKE_COEFFICIENT = 700; //
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
    ) internal view {
        ISummerStaking.Bucket[] memory buckets = new ISummerStaking.Bucket[](7);
        buckets[0] = ISummerStaking.Bucket.NoLockup;
        buckets[1] = ISummerStaking.Bucket.ShortTerm;
        buckets[2] = ISummerStaking.Bucket.TwoWeeksToThreeMonths;
        buckets[3] = ISummerStaking.Bucket.ThreeToSixMonths;
        buckets[4] = ISummerStaking.Bucket.SixToTwelveMonths;
        buckets[5] = ISummerStaking.Bucket.OneToTwoYears;
        buckets[6] = ISummerStaking.Bucket.TwoToThreeYears;

        for (uint256 i = 0; i < 7; i++) {
            uint256 actualStaked = staking.getBucketTotalStaked(buckets[i]);
            console.log("Bucket", i, "actualStaked", actualStaked);
            assertEq(
                actualStaked,
                expectedBucketAmounts[i],
                string(abi.encodePacked("Bucket ", i, " mismatch"))
            );
        }
    }
    /**
     * @notice Helper to verify bucket caps
     */
    function _verifyBucketCaps(
        SummerStaking staking,
        uint256[] memory expectedBucketCaps
    ) internal view {
        ISummerStaking.Bucket[] memory buckets = new ISummerStaking.Bucket[](7);
        buckets[0] = ISummerStaking.Bucket.NoLockup;
        buckets[1] = ISummerStaking.Bucket.ShortTerm;
        buckets[2] = ISummerStaking.Bucket.TwoWeeksToThreeMonths;
        buckets[3] = ISummerStaking.Bucket.ThreeToSixMonths;
        buckets[4] = ISummerStaking.Bucket.SixToTwelveMonths;
        buckets[5] = ISummerStaking.Bucket.OneToTwoYears;
        buckets[6] = ISummerStaking.Bucket.TwoToThreeYears;

        for (uint256 i = 0; i < 7; i++) {
            (uint256 actualCap, , , ) = staking.getBucketDetails(buckets[i]);
            assertEq(
                actualCap,
                expectedBucketCaps[i],
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
     * @notice Aggregated snapshot of a user's staking-related balances
     */
    struct UserSnapshot {
        uint256 raw; // aStaking.balanceOf(user)
        uint256 weighted; // aStaking.weightedBalanceOf(user)
        uint256 xsumr; // axSumr.balanceOf(user)
        uint256 rewards; // rewardToken.balanceOf(user)
    }

    /**
     * @notice Helper to snapshot a user's staking-related balances in one memory struct
     */
    function _snapshotUser(
        SummerStaking staking,
        address user
    ) internal view returns (UserSnapshot memory s) {
        s.raw = staking.balanceOf(user);
        s.weighted = staking.weightedBalanceOf(user);
        s.xsumr = axSumr.balanceOf(user);
        s.rewards = rewardToken.balanceOf(user);
    }

    /**
     * @notice Helper to verify reward distribution
     */
    function _verifyRewardDistribution(
        SummerStaking staking,
        address user,
        uint256 expectedReward
    ) internal view {
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
        return lockupPeriod >= 90 days && lockupPeriod <= 3 * 365 days;
    }

    /**
     * @notice Helper to calculate penalty percentage based on time remaining
     */
    function _calculatePenaltyPercentage(
        uint256 timeRemaining,
        uint256 originalLockupPeriod
    ) internal view returns (uint256) {
        if (originalLockupPeriod == 0) return 0;
        return (timeRemaining * aMaxPenaltyPercentage) / (aMaxLockupPeriod);
    }

    /**
     * @notice Helper to verify event emission with specific parameters
     */
    function _verifyStakedEvent(
        address user,
        uint256 stakeIndex,
        uint256 amount,
        uint256 lockupPeriod,
        uint256 weightedAmount
    ) internal {
        vm.expectEmit(true, false, false, false);
        emit ISummerStaking.StakedWithLockup(
            user,
            stakeIndex,
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
        uint256 stakeIndex,
        uint256 unstaked,
        uint256 penalty,
        uint256 returnAmount
    ) internal {
        vm.expectEmit(true, false, false, false);
        emit ISummerStaking.UnstakedWithPenalty(
            user,
            stakeIndex,
            unstaked,
            penalty,
            returnAmount
        );
    }
}
