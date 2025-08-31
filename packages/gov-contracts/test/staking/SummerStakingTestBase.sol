// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerStaking} from "../../src/contracts/SummerStaking.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Constants} from "@summerfi/constants/Constants.sol";
import {SummerGovernorV2TestBase} from "../governorV2/SummerGovernorV2TestBase.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";

/*
 * @title SummerStaking Test Base
 * @dev Base contract for SummerStaking tests with common helper methods.
 */
contract SummerStakingTestBase is SummerGovernorV2TestBase {
    address public user1 = address(0x1001);
    address public user2 = address(0x1002);
    uint256 public constant STAKE_AMOUNT = 1000 ether;
    uint256 public constant REWARD_AMOUNT = 100 ether;

    SummerStaking public aStaking;
    SummerStaking public bStaking;
    MockERC20 public rewardToken;

    // Test lockup periods
    uint256 public constant MIN_LOCKUP = 90 days;
    uint256 public constant MAX_LOCKUP = 4 * 365 days;
    uint256 public constant MEDIUM_LOCKUP = 365 days;

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

        vm.startPrank(address(timelockA));
        axSumr.addStakingModule(address(aStaking));
        aStaking.updateLockupBucketCap(
            SummerStaking.Bucket.ThreeToSixMonths,
            1000000 ether
        );
        aStaking.updateLockupBucketCap(
            SummerStaking.Bucket.SixToTwelveMonths,
            100000 ether
        );
        aStaking.updateLockupBucketCap(
            SummerStaking.Bucket.OneToTwoYears,
            100000 ether
        );
        aStaking.updateLockupBucketCap(
            SummerStaking.Bucket.TwoToFourYears,
            100000 ether
        );
        vm.stopPrank();

        vm.startPrank(address(timelockB));
        bxSumr.addStakingModule(address(bStaking));
        bStaking.updateLockupBucketCap(
            SummerStaking.Bucket.ThreeToSixMonths,
            1000000 ether
        );
        bStaking.updateLockupBucketCap(
            SummerStaking.Bucket.SixToTwelveMonths,
            100000 ether
        );
        bStaking.updateLockupBucketCap(
            SummerStaking.Bucket.OneToTwoYears,
            100000 ether
        );
        bStaking.updateLockupBucketCap(
            SummerStaking.Bucket.TwoToFourYears,
            100000 ether
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
        aStaking.stakeWithNewLockup(amount, 0);
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
     * @notice Internal helper to add to existing stake and delegate
     */
    function stakeAndDelegate(
        address user,
        uint256 amount,
        bool delegateToSelf,
        uint256 index
    ) internal {
        vm.startPrank(user);
        aSummerToken.approve(address(aStaking), amount);
        aStaking.addToStake(index, amount);
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
     * @notice Wrapper that pranks as the user and calls stakeWithNewLockup on a specific staking contract
     */
    function _stakeOnContract(
        SummerStaking staking,
        address user,
        uint256 amount,
        uint256 lockupPeriod
    ) internal returns (uint256) {
        vm.startPrank(user);
        aSummerToken.approve(address(staking), amount);
        staking.stakeWithNewLockup(amount, lockupPeriod);
        uint256 stakeIndex = staking.getUserStakesCount(user) - 1;
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
     * @notice Wrapper that pranks as the user and calls addToStake on a specific staking contract
     */
    function _addToStakeOnContract(
        SummerStaking staking,
        address user,
        uint256 index,
        uint256 amount
    ) internal {
        vm.startPrank(user);
        aSummerToken.approve(address(staking), amount);
        staking.addToStake(index, amount);
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
     * @notice Wrapper that pranks as the user and calls approve and unstakeFromLockup on a specific staking contract
     */
    function _approveAndUnstakeOnContract(
        SummerStaking staking,
        address user,
        uint256 index,
        uint256 amount
    ) internal {
        vm.startPrank(user);
        axSumr.approve(address(staking), amount);
        staking.unstakeFromLockup(index, amount);
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
     * @notice Wrapper that pranks as the user and calls unstakeFromLockup on a specific staking contract
     */
    function _unstakeOnContract(
        SummerStaking staking,
        address user,
        uint256 index,
        uint256 amount
    ) internal {
        vm.startPrank(user);
        staking.unstakeFromLockup(index, amount);
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
     * @notice Transfers rwdToken to a specific staking contract and calls notifyRewardAmount as the governor
     */
    function _addAndNotifyRewardsOnContract(
        SummerStaking staking,
        address rwdToken,
        uint256 amount
    ) internal {
        vm.startPrank(address(timelockA));
        IERC20(rwdToken).approve(address(staking), amount);
        staking.notifyRewardAmount(rwdToken, amount, 30 days); // 30 days duration
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
     * @notice Asserts that all fields of a specific UserStake struct match the expected values on a specific staking contract
     */
    function _assertStakeOnContract(
        SummerStaking staking,
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
        ) = staking.getUserStake(user, index);

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
        SummerStaking.Bucket bucket,
        uint256 expectedStaked
    ) internal view {
        uint256 actualStaked = aStaking.getBucketTotalStaked(bucket);
        assertEq(actualStaked, expectedStaked, "Bucket staked amount mismatch");
    }

    /**
     * @notice Asserts that a specific bucket has the expected total staked amount on a specific staking contract
     */
    function _assertBucketOnContract(
        SummerStaking staking,
        SummerStaking.Bucket bucket,
        uint256 expectedStaked
    ) internal view {
        uint256 actualStaked = staking.getBucketTotalStaked(bucket);
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
     * @notice Re-implements the penalty calculation logic to verify the on-chain results on a specific staking contract
     */
    function _calculateExpectedPenaltyOnContract(
        SummerStaking staking,
        address user,
        uint256 index,
        uint256 currentTime
    ) internal view returns (uint256) {
        (
            uint256 amount,
            ,
            uint256 lockupEndTime,
            uint256 lockupPeriod
        ) = staking.getUserStake(user, index);

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
     * @notice Uses vm.expectEmit to check for the StakedWithLockup event with the correct parameters on a specific staking contract
     */
    function _expectStakedWithLockupEventOnContract(
        SummerStaking staking,
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

    /**
     * @notice Uses vm.expectEmit to check for the UnstakedWithPenalty event with the correct parameters on a specific staking contract
     */
    function _expectUnstakedWithPenaltyEventOnContract(
        SummerStaking staking,
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
}
