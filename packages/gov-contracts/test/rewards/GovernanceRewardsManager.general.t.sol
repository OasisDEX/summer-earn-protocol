// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {SummerGovernorTestBase} from "../governor/SummerGovernorTestBase.sol";
import {GovernanceRewardsManager} from "../../src/contracts/GovernanceRewardsManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract GovernanceRewardsManagerTest is SummerGovernorTestBase {
    GovernanceRewardsManager public stakingRewardsManager;
    ERC20Mock[] public rewardTokens;

    uint256 constant INITIAL_REWARD_AMOUNT = 1000000 * 1e18;
    uint256 constant INITIAL_STAKE_AMOUNT = 100000 * 1e18;

    function setUp() public override {
        super.setUp();

        // Deploy reward tokens
        for (uint i = 0; i < 3; i++) {
            rewardTokens.push(new ERC20Mock());
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

        // Mint reward tokens
        for (uint i = 0; i < rewardTokens.length; i++) {
            rewardTokens[i].mint(
                address(stakingRewardsManager),
                INITIAL_REWARD_AMOUNT
            );
        }

        // Approve staking
        vm.prank(alice);
        aSummerToken.approve(address(stakingRewardsManager), type(uint256).max);
        vm.prank(bob);
        aSummerToken.approve(address(stakingRewardsManager), type(uint256).max);

        // In the test setup
        rewardTokens[0].mint(address(mockGovernor), 100000000000000000000); // Mint 100 tokens
    }

    function test_StakeOnBehalfOfUpdatesBalancesCorrectly() public {
        uint256 stakeAmount = 1000 * 1e18;

        vm.prank(address(alice));
        stakingRewardsManager.stakeOnBehalfOf(bob, stakeAmount);

        assertEq(
            stakingRewardsManager.balanceOf(bob),
            stakeAmount,
            "Staked balance should be updated"
        );
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
            IERC20(address(rewardTokens[0])),
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
            IERC20(address(rewardTokens[0]))
        );

        assertGt(earnedAmount, 0, "Earned amount should increase over time");
    }

    function test_DelegateDecayAffectsDelegators() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256 rewardAmount = 100 * 1e18;

        // Mint reward tokens to the governor first
        rewardTokens[0].mint(address(mockGovernor), rewardAmount);

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
            IERC20(address(rewardTokens[0])),
            rewardAmount,
            7 days
        );
        vm.stopPrank();
        // Fast forward past decay-free window
        vm.warp(block.timestamp + 30 days);

        // Get initial earned amounts
        uint256 bobInitialEarned = stakingRewardsManager.earned(
            bob,
            IERC20(address(rewardTokens[0]))
        );
        uint256 aliceInitialEarned = stakingRewardsManager.earned(
            alice,
            IERC20(address(rewardTokens[0]))
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
            IERC20(address(rewardTokens[0]))
        );
        uint256 aliceDecayedEarned = stakingRewardsManager.earned(
            alice,
            IERC20(address(rewardTokens[0]))
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
            IERC20(address(rewardTokens[0]))
        );
        uint256 aliceFinalEarned = stakingRewardsManager.earned(
            alice,
            IERC20(address(rewardTokens[0]))
        );

        // Verify Alice now has different rewards than Bob
        assertNotEq(
            aliceFinalEarned,
            bobFinalEarned,
            "After changing delegation, rewards should differ"
        );
    }

    function test_NoRewardsWithoutDelegation() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256 rewardAmount = 100 * 1e18;

        // Alice stakes without delegating first
        vm.prank(alice);
        stakingRewardsManager.stake(stakeAmount);

        // Notify reward
        vm.startPrank(address(mockGovernor));
        rewardTokens[0].approve(address(stakingRewardsManager), rewardAmount);
        stakingRewardsManager.notifyRewardAmount(
            IERC20(address(rewardTokens[0])),
            rewardAmount,
            7 days
        );
        vm.stopPrank();
        // Fast forward time
        vm.warp(block.timestamp + 3 days);

        // Check earned amount - should be 0 since no delegation
        uint256 earnedAmount = stakingRewardsManager.earned(
            alice,
            IERC20(address(rewardTokens[0]))
        );

        assertEq(
            earnedAmount,
            0,
            "User should not earn rewards without delegating first"
        );

        // Now let's delegate and verify rewards start accruing
        vm.prank(alice);
        aSummerToken.delegate(alice);

        // Fast forward more time
        vm.warp(block.timestamp + 1 days);

        // Check earned amount again - should be non-zero now
        uint256 earnedAfterDelegation = stakingRewardsManager.earned(
            alice,
            IERC20(address(rewardTokens[0]))
        );

        assertGt(
            earnedAfterDelegation,
            0,
            "User should start earning rewards after delegating"
        );
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
            IERC20(address(aSummerToken)),
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
            IERC20(address(rewardTokens[0])),
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
        assertEq(
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
            IERC20(address(rewardTokens[0])),
            rewardAmount,
            duration
        );
        vm.stopPrank();

        (
            uint256 periodFinish,
            uint256 rewardRate,
            uint256 rewardsDuration,
            ,

        ) = stakingRewardsManager.rewardData(IERC20(address(rewardTokens[0])));

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
            IERC20(address(rewardTokens[0])),
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
        stakingRewardsManager.removeRewardToken(
            IERC20(address(rewardTokens[0]))
        );

        // Verify token was removed
        vm.prank(address(mockGovernor));
        vm.expectRevert(abi.encodeWithSignature("RewardTokenDoesNotExist()"));
        stakingRewardsManager.removeRewardToken(
            IERC20(address(rewardTokens[0]))
        );
    }

    function test_SetRewardsDuration() public {
        uint256 rewardAmount = 100 * 1e18;
        uint256 initialDuration = 7 days;
        uint256 newDuration = 14 days;

        // Setup initial reward
        vm.startPrank(address(mockGovernor));
        rewardTokens[0].approve(address(stakingRewardsManager), rewardAmount);
        stakingRewardsManager.notifyRewardAmount(
            IERC20(address(rewardTokens[0])),
            rewardAmount,
            initialDuration
        );
        vm.stopPrank();

        // Fast forward past initial period
        vm.warp(block.timestamp + 8 days);

        // Set new duration
        vm.prank(address(mockGovernor));
        stakingRewardsManager.setRewardsDuration(
            IERC20(address(rewardTokens[0])),
            newDuration
        );

        // Verify new duration
        (, , uint256 duration, , ) = stakingRewardsManager.rewardData(
            IERC20(address(rewardTokens[0]))
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
}
