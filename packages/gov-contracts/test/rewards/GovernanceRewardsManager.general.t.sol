// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerGovernorTestBase} from "../governor/SummerGovernorTestBase.sol";
import {IGovernanceRewardsManagerErrors} from "../../src/errors/IGovernanceRewardsManagerErrors.sol";
import {IStakingRewardsManagerBaseErrors} from "@summerfi/rewards-contracts/interfaces/IStakingRewardsManagerBaseErrors.sol";
import {IGovernanceRewardsManagerErrors} from "../../src/errors/IGovernanceRewardsManagerErrors.sol";
import {IStakingRewardsManagerBase} from "@summerfi/rewards-contracts/interfaces/IStakingRewardsManagerBase.sol";
import {StakingRewardsManagerBase} from "@summerfi/rewards-contracts/contracts/StakingRewardsManagerBase.sol";
import {GovernanceRewardsManager} from "../../src/contracts/GovernanceRewardsManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";
import {UnprotectedGovernanceRewardsManager} from "../mocks/UnprotectedGovernanceRewardsManager.sol";

contract GovernanceRewardsManagerTest is SummerGovernorTestBase {
    GovernanceRewardsManager public stakingRewardsManager;
    IERC20[] public rewardTokens;

    uint256 constant INITIAL_REWARD_AMOUNT = 1000000 * 1e18;
    uint256 constant INITIAL_STAKE_AMOUNT = 100000 * 1e18;

    function setUp() public override {
        super.setUp();

        // Deploy reward tokens
        for (uint i = 0; i < 3; i++) {
            rewardTokens.push(aSummerToken);
        }

        // Deploy GovernanceRewardsManager with aSummerToken
        stakingRewardsManager = new GovernanceRewardsManager(
            address(aSummerToken),
            address(accessManagerA)
        );

        // Grant roles
        vm.startPrank(address(timelockA));
        accessManagerA.grantDecayControllerRole(address(stakingRewardsManager));
        accessManagerA.grantGovernorRole(address(mockGovernor));
        vm.stopPrank();

        // Mint initial tokens
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, INITIAL_STAKE_AMOUNT);
        aSummerToken.transfer(bob, INITIAL_STAKE_AMOUNT);
        vm.stopPrank();

        // Delegate
        vm.prank(alice);
        aSummerToken.delegate(alice);
        vm.prank(bob);
        aSummerToken.delegate(bob);

        // Approve staking
        vm.prank(alice);
        aSummerToken.approve(address(stakingRewardsManager), type(uint256).max);
        vm.prank(bob);
        aSummerToken.approve(address(stakingRewardsManager), type(uint256).max);

        deal(
            address(rewardTokens[0]),
            address(mockGovernor),
            100000000000000000000
        ); // Mint 100 tokens
    }

    function test_Unstake() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256 unstakeAmount = 500 * 1e18;

        vm.prank(address(alice));
        stakingRewardsManager.stake(stakeAmount);

        vm.prank(alice);
        stakingRewardsManager.unstake(unstakeAmount);

        assertEq(
            stakingRewardsManager.balanceOf(alice),
            stakeAmount - unstakeAmount,
            "Staked balance should be updated after unstake"
        );
    }

    function test_UnstakeUpdatesBalancesCorrectly() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256 unstakeAmount = 500 * 1e18;

        vm.prank(address(alice));
        stakingRewardsManager.stake(stakeAmount);

        uint256 initialBalance = aSummerToken.balanceOf(alice);

        vm.prank(alice);
        stakingRewardsManager.unstake(unstakeAmount);

        assertEq(
            aSummerToken.balanceOf(alice),
            initialBalance + unstakeAmount,
            "Token balance should increase after unstake"
        );
        assertEq(
            stakingRewardsManager.balanceOf(alice),
            stakeAmount - unstakeAmount,
            "Staked balance should decrease after unstake"
        );
    }

    function test_RewardCalculationAfterStakeAndUnstake() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256 rewardAmount = 100 * 1e18;

        // Setup delegation first
        vm.prank(alice);
        aSummerToken.delegate(alice);

        // Alice stakes
        vm.prank(alice);
        stakingRewardsManager.stake(stakeAmount);

        // Notify reward
        vm.startPrank(address(mockGovernor));
        rewardTokens[0].approve(address(stakingRewardsManager), rewardAmount);
        stakingRewardsManager.notifyRewardAmount(
            address(rewardTokens[0]),
            rewardAmount,
            7 days
        );
        vm.stopPrank();
        // Fast forward time
        vm.warp(block.timestamp + 3 days);

        // Alice unstakes half
        vm.prank(alice);
        stakingRewardsManager.unstake(stakeAmount / 2);

        // Fast forward more time
        vm.warp(block.timestamp + 4 days);

        // Check earned amount - should be greater than 0
        uint256 earnedAmount = stakingRewardsManager.earned(
            alice,
            address(rewardTokens[0])
        );

        assertGt(earnedAmount, 0, "Earned amount should increase over time");
    }

    function test_DelegateDecayAffectsDelegators() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256 rewardAmount = 100 * 1e18;

        // Mint reward tokens to the governor first
        deal(address(rewardTokens[0]), address(mockGovernor), rewardAmount);

        // Setup delegate (bob) and delegator (alice)
        vm.startPrank(bob);
        aSummerToken.delegate(bob); // Bob self-delegates first
        stakingRewardsManager.stake(stakeAmount);
        vm.stopPrank();

        vm.startPrank(alice);
        aSummerToken.delegate(bob); // Alice delegates to Bob
        stakingRewardsManager.stake(stakeAmount);
        vm.stopPrank();

        // Notify reward
        vm.startPrank(address(mockGovernor));
        rewardTokens[0].approve(address(stakingRewardsManager), rewardAmount);
        stakingRewardsManager.notifyRewardAmount(
            address(rewardTokens[0]),
            rewardAmount,
            7 days
        );
        vm.stopPrank();
        // Fast forward past decay-free window
        vm.warp(block.timestamp + 30 days);

        // Get initial earned amounts
        uint256 bobInitialEarned = stakingRewardsManager.earned(
            bob,
            address(rewardTokens[0])
        );
        uint256 aliceInitialEarned = stakingRewardsManager.earned(
            alice,
            address(rewardTokens[0])
        );

        // Verify Alice's rewards are affected by Bob's decay factor
        assertEq(
            aliceInitialEarned,
            bobInitialEarned,
            "Delegator should have same rewards as delegate due to same stake and decay factor"
        );

        // Fast forward more time to accumulate decay
        vm.warp(block.timestamp + 60 days);

        // Get decayed earned amounts
        uint256 bobDecayedEarned = stakingRewardsManager.earned(
            bob,
            address(rewardTokens[0])
        );
        uint256 aliceDecayedEarned = stakingRewardsManager.earned(
            alice,
            address(rewardTokens[0])
        );

        // Verify both accounts are affected by decay
        assertLt(
            bobDecayedEarned,
            bobInitialEarned,
            "Delegate rewards should decay over time"
        );
        assertLt(
            aliceDecayedEarned,
            aliceInitialEarned,
            "Delegator rewards should decay with delegate"
        );
        assertEq(
            aliceDecayedEarned,
            bobDecayedEarned,
            "Delegator should maintain same rewards as delegate"
        );

        // Now let's have Alice switch to self-delegation
        vm.prank(alice);
        aSummerToken.delegate(alice);

        // Fast forward a bit more
        vm.warp(block.timestamp + 1 days);

        // Get new earned amounts after delegation change
        uint256 bobFinalEarned = stakingRewardsManager.earned(
            bob,
            address(rewardTokens[0])
        );
        uint256 aliceFinalEarned = stakingRewardsManager.earned(
            alice,
            address(rewardTokens[0])
        );

        // Verify Alice now has different rewards than Bob
        assertNotEq(
            aliceFinalEarned,
            bobFinalEarned,
            "After changing delegation, rewards should differ"
        );
    }

    function test_NoRewardsWithoutDelegation() public {
        address randomAddress = makeAddr("random");

        // Try to stake without delegation - should revert
        vm.prank(randomAddress);
        vm.expectRevert(IGovernanceRewardsManagerErrors.NotDelegated.selector);
        stakingRewardsManager.stake(1000 * 1e18);
    }

    function test_ClaimReward_WithStakingToken() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256 rewardAmount = 100 * 1e18;

        // Setup staking and delegation
        vm.prank(alice);
        aSummerToken.delegate(alice);
        vm.prank(alice);
        stakingRewardsManager.stake(stakeAmount);

        vm.warp(block.timestamp + 30 days + 1);

        // Setup reward with aSummerToken
        vm.startPrank(address(timelockA));
        // First transfer tokens to the rewards manager
        aSummerToken.transfer(address(stakingRewardsManager), rewardAmount);
        // Then transfer tokens to governor for notification
        aSummerToken.transfer(address(mockGovernor), rewardAmount);
        vm.stopPrank();

        vm.startPrank(address(mockGovernor));
        aSummerToken.approve(address(stakingRewardsManager), rewardAmount);
        stakingRewardsManager.notifyRewardAmount(
            address(aSummerToken),
            rewardAmount,
            7 days
        );
        vm.stopPrank();

        // Fast forward time
        vm.warp(block.timestamp + 7 days);

        // Record initial balance
        uint256 initialBalance = aSummerToken.balanceOf(alice);

        // Claim rewards
        vm.prank(alice);
        stakingRewardsManager.getReward();

        // Check that Alice received aSummerToken
        assertGt(
            aSummerToken.balanceOf(alice),
            initialBalance,
            "Should receive aSummerToken as reward"
        );
    }

    function test_Exit() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256 rewardAmount = 100 * 1e18;

        // Setup delegation first
        vm.prank(alice);
        aSummerToken.delegate(alice);

        // Alice stakes
        vm.prank(alice);
        stakingRewardsManager.stake(stakeAmount);

        // Setup reward
        vm.startPrank(address(mockGovernor));
        rewardTokens[0].approve(address(stakingRewardsManager), rewardAmount);
        stakingRewardsManager.notifyRewardAmount(
            address(rewardTokens[0]),
            rewardAmount,
            7 days
        );
        vm.stopPrank();

        // Fast forward time
        vm.warp(block.timestamp + 7 days);

        // Record balances before exit
        uint256 stakingTokenBalanceBefore = aSummerToken.balanceOf(alice);
        uint256 rewardTokenBalanceBefore = rewardTokens[0].balanceOf(alice);

        // Exit
        vm.prank(alice);
        stakingRewardsManager.exit();

        // Verify balances
        assertGt(
            aSummerToken.balanceOf(alice),
            stakingTokenBalanceBefore + stakeAmount,
            "Staking tokens should be returned"
        );
        assertGt(
            rewardTokens[0].balanceOf(alice),
            rewardTokenBalanceBefore,
            "Rewards should be claimed"
        );
        assertEq(
            stakingRewardsManager.balanceOf(alice),
            0,
            "Staked balance should be zero"
        );
    }

    function test_NotifyRewardAmount() public {
        uint256 rewardAmount = 100 * 1e18;
        uint256 duration = 7 days;

        vm.startPrank(address(mockGovernor));
        rewardTokens[0].approve(address(stakingRewardsManager), rewardAmount);
        stakingRewardsManager.notifyRewardAmount(
            address(rewardTokens[0]),
            rewardAmount,
            duration
        );
        vm.stopPrank();

        (
            uint256 periodFinish,
            uint256 rewardRate,
            uint256 rewardsDuration,
            ,

        ) = stakingRewardsManager.rewardData(address(rewardTokens[0]));

        assertEq(rewardsDuration, duration, "Duration should be set correctly");
        assertEq(
            periodFinish,
            block.timestamp + duration,
            "Period finish should be set correctly"
        );
        assertGt(rewardRate, 0, "Reward rate should be greater than 0");
    }

    function test_RemoveRewardToken() public {
        uint256 rewardAmount = 100 * 1e18;

        // Setup reward token
        vm.startPrank(address(mockGovernor));
        rewardTokens[0].approve(address(stakingRewardsManager), rewardAmount);
        stakingRewardsManager.notifyRewardAmount(
            address(rewardTokens[0]),
            rewardAmount,
            7 days
        );
        vm.stopPrank();

        // Fast forward past reward period
        vm.warp(block.timestamp + 8 days);

        // Transfer out ALL rewards to simulate them being claimed
        uint256 remainingBalance = rewardTokens[0].balanceOf(
            address(stakingRewardsManager)
        );
        vm.prank(address(stakingRewardsManager));
        rewardTokens[0].transfer(address(1), remainingBalance);

        // Remove reward token
        vm.prank(address(mockGovernor));
        stakingRewardsManager.removeRewardToken(address(rewardTokens[0]));

        // Verify token was removed
        vm.prank(address(mockGovernor));
        vm.expectRevert(abi.encodeWithSignature("RewardTokenDoesNotExist()"));
        stakingRewardsManager.removeRewardToken(address(rewardTokens[0]));
    }

    function test_SetRewardsDuration() public {
        uint256 rewardAmount = 100 * 1e18;
        uint256 initialDuration = 7 days;
        uint256 newDuration = 14 days;

        // Setup initial reward
        vm.startPrank(address(mockGovernor));
        rewardTokens[0].approve(address(stakingRewardsManager), rewardAmount);
        stakingRewardsManager.notifyRewardAmount(
            address(rewardTokens[0]),
            rewardAmount,
            initialDuration
        );
        vm.stopPrank();

        // Fast forward past initial period
        vm.warp(block.timestamp + 8 days);

        // Set new duration
        vm.prank(address(mockGovernor));
        stakingRewardsManager.setRewardsDuration(
            address(rewardTokens[0]),
            newDuration
        );

        // Verify new duration
        (, , uint256 duration, , ) = stakingRewardsManager.rewardData(
            address(rewardTokens[0])
        );
        assertEq(duration, newDuration, "Duration should be updated");
    }

    function test_UnstakeByDelegate() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256 unstakeAmount = 500 * 1e18;

        // Setup delegation
        vm.prank(alice);
        aSummerToken.delegate(bob);

        // Stake tokens
        vm.prank(alice);
        stakingRewardsManager.stake(stakeAmount);

        uint256 initialBalance = aSummerToken.balanceOf(alice);

        // Bob tries to unstake Alice's tokens - this should fail because delegation
        // only gives voting power, not control over staked tokens
        vm.prank(bob);
        vm.expectRevert(); // or a specific error if one is defined
        stakingRewardsManager.unstake(unstakeAmount);

        // Verify balances haven't changed
        assertEq(
            aSummerToken.balanceOf(alice),
            initialBalance,
            "Token balance should not change"
        );
        assertEq(
            stakingRewardsManager.balanceOf(alice),
            stakeAmount,
            "Staked balance should not change"
        );
    }

    function test_SetRewardsDurationAfterNotify() public {
        uint256 rewardAmount = 1000 * 1e18;
        uint256 validDuration = 30 days;
        uint256 invalidDuration = 361 days; // Just over MAX_REWARD_DURATION (360 days)

        deal(address(rewardTokens[0]), address(mockGovernor), rewardAmount);

        // First test with valid duration
        vm.startPrank(address(mockGovernor));
        rewardTokens[0].approve(address(stakingRewardsManager), rewardAmount);
        stakingRewardsManager.notifyRewardAmount(
            address(rewardTokens[0]),
            rewardAmount,
            validDuration
        );
        vm.stopPrank();

        // Fast forward past the reward period
        vm.warp(block.timestamp + validDuration + 1);

        // Try to set an invalid duration
        vm.prank(address(mockGovernor));
        vm.expectRevert(
            IStakingRewardsManagerBaseErrors.RewardsDurationTooLong.selector
        );
        stakingRewardsManager.setRewardsDuration(
            address(rewardTokens[0]),
            invalidDuration
        );

        // Set a valid new duration
        vm.prank(address(mockGovernor));
        stakingRewardsManager.setRewardsDuration(
            address(rewardTokens[0]),
            validDuration
        );

        // Verify the new duration was set
        (, , uint256 duration, , ) = stakingRewardsManager.rewardData(
            address(rewardTokens[0])
        );
        assertEq(
            duration,
            validDuration,
            "Duration should be updated to new valid value"
        );
    }

    function test_RevertWhen_NotifyRewardAmountWithInvalidDuration() public {
        uint256 rewardAmount = 1000 * 1e18;
        uint256 zeroDuration = 0;
        uint256 tooLongDuration = 361 days; // MAX_REWARD_DURATION is 360 days

        // Mint tokens to governor for testing
        deal(address(rewardTokens[0]), address(mockGovernor), rewardAmount);

        vm.startPrank(address(mockGovernor));
        rewardTokens[0].approve(address(stakingRewardsManager), rewardAmount);

        // Test zero duration
        vm.expectRevert(
            IStakingRewardsManagerBaseErrors
                .RewardsDurationCannotBeZero
                .selector
        );
        stakingRewardsManager.notifyRewardAmount(
            address(rewardTokens[0]),
            rewardAmount,
            zeroDuration
        );

        // Test too long duration
        vm.expectRevert(
            IStakingRewardsManagerBaseErrors.RewardsDurationTooLong.selector
        );
        stakingRewardsManager.notifyRewardAmount(
            address(rewardTokens[0]),
            rewardAmount,
            tooLongDuration
        );

        // Set up initial reward with valid duration
        stakingRewardsManager.notifyRewardAmount(
            address(rewardTokens[0]),
            rewardAmount,
            30 days
        );

        // Try to notify again with different duration
        vm.expectRevert(
            IStakingRewardsManagerBaseErrors
                .CannotChangeRewardsDuration
                .selector
        );
        stakingRewardsManager.notifyRewardAmount(
            address(rewardTokens[0]),
            rewardAmount,
            60 days // Different duration than initial
        );

        vm.stopPrank();
    }

    function test_RevertWhen_StakeOnBehalfOfIsCalled() public {
        uint256 stakeAmount = 1000 * 1e18;

        // Approve staking from alice
        vm.prank(alice);
        aSummerToken.approve(address(stakingRewardsManager), stakeAmount);

        // Try to stake on behalf of alice from bob's address
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSignature("StakeOnBehalfOfNotSupported()")
        );
        stakingRewardsManager.stakeOnBehalfOf(alice, stakeAmount);
    }

    function test_Regression_Interchanged_Staking_And_Claiming_Rewards()
        public
    {
        console.log("==========================================");
        console.log("============= STARTING TEST ==============");
        console.log("==========================================");

        address actor1 = makeAddr("actor1");
        address actor2 = makeAddr("actor2");
        uint256 rewardAmount = 100_000 * 1e18;
        console.log(
            "Initial reward amount:                     ",
            rewardAmount,
            string.concat("(", _formatScientific(rewardAmount), ")")
        );

        // Ensure mockGovernor has enough tokens for rewards
        deal(address(rewardTokens[0]), address(mockGovernor), rewardAmount);

        // 1. First notify reward amount
        vm.startPrank(address(mockGovernor));
        rewardTokens[0].approve(address(stakingRewardsManager), rewardAmount);
        stakingRewardsManager.notifyRewardAmount(
            address(rewardTokens[0]),
            rewardAmount,
            1 weeks
        );
        vm.stopPrank();

        // 2. Move forward from notify to first stake
        vm.warp(block.timestamp + 15 hours);
        console.log("\nTime warped by 15 hours");

        // 3. Actor1 first stake
        uint256 actor1FirstStake = 4 * 1e18;
        vm.startPrank(actor1);
        deal(address(aSummerToken), actor1, actor1FirstStake);
        aSummerToken.delegate(actor1);
        aSummerToken.approve(address(stakingRewardsManager), actor1FirstStake);
        stakingRewardsManager.stake(actor1FirstStake);
        vm.stopPrank();

        _logStateForManager(
            stakingRewardsManager,
            actor1,
            "After actor1 first stake:",
            actor1FirstStake
        );

        // 4. Actor1 first claim
        vm.warp(block.timestamp + 1 hours);
        console.log("\nTime warped by 1 hour");

        vm.prank(actor1);
        stakingRewardsManager.getReward();

        _logStateForManager(
            stakingRewardsManager,
            actor1,
            "After actor1 first claim:",
            0
        );

        // 5. Actor1 second claim
        vm.warp(block.timestamp + 1 hours);
        console.log("\nTime warped by 1 hour");

        vm.prank(actor1);
        stakingRewardsManager.getReward();

        _logStateForManager(
            stakingRewardsManager,
            actor1,
            "After actor1 second claim:",
            0
        );

        // 6. Actor2 first stake
        uint256 actor2FirstStake = 900 * 1e18;
        vm.startPrank(actor2);
        deal(address(aSummerToken), actor2, actor2FirstStake);
        aSummerToken.delegate(actor2);
        aSummerToken.approve(address(stakingRewardsManager), actor2FirstStake);
        stakingRewardsManager.stake(actor2FirstStake);
        vm.stopPrank();

        _logStateForManager(
            stakingRewardsManager,
            actor2,
            "After actor2 first stake:",
            actor2FirstStake
        );

        // 7. Actor2 first claim
        vm.warp(block.timestamp + 1 hours);
        console.log("\nTime warped by 1 hour");

        vm.prank(actor2);
        stakingRewardsManager.getReward();

        _logStateForManager(
            stakingRewardsManager,
            actor2,
            "After actor2 first claim:",
            0
        );

        // 8. Actor1 second stake
        uint256 actor1SecondStake = 500 * 1e18;
        vm.startPrank(actor1);
        deal(address(aSummerToken), actor1, actor1SecondStake);
        aSummerToken.approve(address(stakingRewardsManager), actor1SecondStake);
        stakingRewardsManager.stake(actor1SecondStake);
        vm.stopPrank();

        _logStateForManager(
            stakingRewardsManager,
            actor1,
            "After actor1 second stake:",
            actor1SecondStake
        );

        // 9. Actor2 second claim
        vm.warp(block.timestamp + 1 hours);
        console.log("\nTime warped by 1 hour");

        vm.prank(actor2);
        stakingRewardsManager.getReward();

        _logStateForManager(
            stakingRewardsManager,
            actor2,
            "After actor2 second claim:",
            0
        );

        // 10. Actor1 third claim
        vm.warp(block.timestamp + 1 hours);
        console.log("\nTime warped by 1 hour");

        vm.prank(actor1);
        stakingRewardsManager.getReward();

        _logStateForManager(
            stakingRewardsManager,
            actor1,
            "After actor1 third claim:",
            0
        );

        // 11. Actor1 third stake
        uint256 actor1ThirdStake = 300 * 1e18;
        vm.startPrank(actor1);
        deal(address(aSummerToken), actor1, actor1ThirdStake);
        aSummerToken.approve(address(stakingRewardsManager), actor1ThirdStake);
        stakingRewardsManager.stake(actor1ThirdStake);
        vm.stopPrank();

        _logStateForManager(
            stakingRewardsManager,
            actor1,
            "After actor1 third stake:",
            actor1ThirdStake
        );

        // Final state check for both actors
        console.log("\nFinal state check:");
        _logStateForManager(
            stakingRewardsManager,
            actor1,
            "Actor1 final state:",
            0
        );
        _logStateForManager(
            stakingRewardsManager,
            actor2,
            "Actor2 final state:",
            0
        );
    }

    function test_Regression_Revert_Claim_Without_UpdateReward() public {
        console.log("==========================================");
        console.log("============= STARTING TEST ==============");
        console.log("==========================================");

        address actor1 = makeAddr("actor1");
        address actor2 = makeAddr("actor2");
        uint256 rewardAmount = 100_000 * 1e18;

        // Deploy unprotected version
        UnprotectedGovernanceRewardsManager unprotectedManager = new UnprotectedGovernanceRewardsManager(
                address(aSummerToken),
                address(accessManagerA)
            );

        // Grant roles
        vm.startPrank(address(timelockA));
        accessManagerA.grantDecayControllerRole(address(unprotectedManager));
        accessManagerA.grantGovernorRole(address(mockGovernor));
        vm.stopPrank();

        // Ensure mockGovernor has enough tokens for rewards
        deal(address(rewardTokens[0]), address(mockGovernor), rewardAmount);

        // 1. First notify reward amount
        vm.startPrank(address(mockGovernor));
        rewardTokens[0].approve(address(unprotectedManager), rewardAmount);
        unprotectedManager.notifyRewardAmount(
            address(rewardTokens[0]),
            rewardAmount,
            1 weeks
        );
        vm.stopPrank();

        // 2. Move forward from notify to first stake
        vm.warp(block.timestamp + 15 hours);
        console.log("\nTime warped by 15 hours");

        // 3. Actor1 first stake
        uint256 actor1FirstStake = 4 * 1e18;
        deal(address(aSummerToken), actor1, actor1FirstStake);
        vm.startPrank(actor1);
        aSummerToken.delegate(actor1);
        aSummerToken.approve(address(unprotectedManager), type(uint256).max);
        unprotectedManager.stakeWithoutUpdateReward(actor1FirstStake);
        vm.stopPrank();

        _logStateForManager(
            unprotectedManager,
            actor1,
            "After actor1 first stake:",
            actor1FirstStake
        );

        // 4. Actor1 first claim
        vm.warp(block.timestamp + 1 hours);
        console.log("\nTime warped by 1 hour");

        vm.prank(actor1);
        unprotectedManager.getReward();

        _logStateForManager(
            unprotectedManager,
            actor1,
            "After actor1 first claim:",
            0
        );

        // 5. Actor2 stake
        uint256 actor2FirstStake = 900 * 1e18;
        deal(address(aSummerToken), actor2, actor2FirstStake);
        vm.startPrank(actor2);
        aSummerToken.delegate(actor2);
        aSummerToken.approve(address(unprotectedManager), type(uint256).max);
        unprotectedManager.stakeWithoutUpdateReward(actor2FirstStake);
        vm.stopPrank();

        _logStateForManager(
            unprotectedManager,
            actor2,
            "After actor2 stake:",
            actor2FirstStake
        );

        vm.warp(block.timestamp + 1 hours);
        console.log("\nTime warped by 1 hour");

        vm.prank(actor2);
        vm.expectRevert();
        unprotectedManager.getReward();
    }

    function _logStateForManager(
        IStakingRewardsManagerBase manager,
        address user,
        string memory label,
        uint256 stakeAmount
    ) internal view {
        console.log("\n----------------------------------------");
        console.log(label);
        if (stakeAmount > 0) {
            console.log(
                "Stake Amount:                             ",
                stakeAmount,
                string.concat("(", _formatScientific(stakeAmount), ")")
            );
        }
        uint256 totalSupply = manager.totalSupply();
        console.log(
            "Total Supply:                             ",
            totalSupply,
            string.concat("(", _formatScientific(totalSupply), ")")
        );

        uint256 userBalance = manager.balanceOf(user);
        console.log(
            "User Balance:                             ",
            userBalance,
            string.concat("(", _formatScientific(userBalance), ")")
        );

        uint256 earned = manager.earned(user, address(rewardTokens[0]));
        console.log(
            "Amount can claim:                         ",
            earned,
            string.concat("(", _formatScientific(earned), ")")
        );

        uint256 remainingReward = rewardTokens[0].balanceOf(address(manager));
        console.log(
            "Remaining reward amount:                  ",
            remainingReward,
            string.concat("(", _formatScientific(remainingReward), ")")
        );

        uint256 rewardPerToken = manager.rewardPerToken(
            address(rewardTokens[0])
        );
        console.log(
            "Reward Per Token:                         ",
            rewardPerToken,
            string.concat("(", _formatScientific(rewardPerToken), ")")
        );

        uint256 userRewardPaid = StakingRewardsManagerBase(address(manager))
            .userRewardPerTokenPaid(address(rewardTokens[0]), user);
        console.log(
            "User Reward Per Token Paid:               ",
            userRewardPaid,
            string.concat("(", _formatScientific(userRewardPaid), ")")
        );
    }

    function _formatScientific(
        uint256 value
    ) internal pure returns (string memory) {
        if (value == 0) return "0";

        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            temp /= 10;
            digits++;
        }

        if (digits <= 1) return string.concat(vm.toString(value));

        uint256 exponent = digits - 1;
        uint256 mantissa = value / (10 ** exponent);

        return string.concat(vm.toString(mantissa), "e", vm.toString(exponent));
    }
}
