// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./GovernanceRewardsManager.general.t.sol";
import {console} from "forge-std/console.sol";
contract GovernanceRewardsManagerCalculationsTest is
    GovernanceRewardsManagerTest
{
    function test_RewardPerToken_NoSupply() public {
        // When total supply is 0, should return stored value
        (, , , , uint256 storedValue) = stakingRewardsManager.rewardData(
            IERC20(address(rewardTokens[0]))
        );

        assertEq(
            stakingRewardsManager.rewardPerToken(
                IERC20(address(rewardTokens[0]))
            ),
            storedValue,
            "Should return stored value when supply is 0"
        );
    }

    function test_RewardPerToken_WithSupply() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256 rewardAmount = 100 * 1e18;

        // Setup staking
        vm.startPrank(alice);
        aSummerToken.delegate(alice);
        stakingRewardsManager.stake(stakeAmount);
        vm.stopPrank();

        // Setup reward
        vm.prank(address(mockGovernor));
        stakingRewardsManager.notifyRewardAmount(
            IERC20(address(rewardTokens[0])),
            rewardAmount,
            7 days
        );

        // Move forward in time
        vm.warp(block.timestamp + 1 days);

        // Calculate expected reward per token
        uint256 timePassed = 1 days;
        (
            ,
            uint256 rewardRate,
            ,
            uint256 lastUpdateTime,
            uint256 rewardPerTokenStored
        ) = stakingRewardsManager.rewardData(IERC20(address(rewardTokens[0])));

        uint256 expectedRewardPerToken = rewardPerTokenStored +
            ((timePassed * rewardRate) / stakeAmount);

        assertEq(
            stakingRewardsManager.rewardPerToken(
                IERC20(address(rewardTokens[0]))
            ),
            expectedRewardPerToken,
            "RewardPerToken calculation mismatch"
        );
    }

    function test_GetRewardForDuration_SingleRewardToken() public {
        uint256 rewardAmount = 100 * 1e18;
        uint256 duration = 7 days;

        vm.prank(address(mockGovernor));
        stakingRewardsManager.notifyRewardAmount(
            IERC20(address(rewardTokens[0])),
            rewardAmount,
            duration
        );

        assertApproxEqAbs(
            stakingRewardsManager.getRewardForDuration(
                IERC20(address(rewardTokens[0]))
            ),
            rewardAmount,
            10, // Allow difference of up to 10 wei
            "GetRewardForDuration should return approximately total reward"
        );
    }

    function test_GetRewardForDuration_MultipleNotifications() public {
        uint256 initialReward = 100 * 1e18;
        uint256 additionalReward = 50 * 1e18;
        uint256 duration = 7 days;

        // First notification
        vm.prank(address(mockGovernor));
        stakingRewardsManager.notifyRewardAmount(
            IERC20(address(rewardTokens[0])),
            initialReward,
            duration
        );

        // Second notification
        vm.prank(address(mockGovernor));
        stakingRewardsManager.notifyRewardAmount(
            IERC20(address(rewardTokens[0])),
            additionalReward,
            duration
        );

        assertApproxEqAbs(
            stakingRewardsManager.getRewardForDuration(
                IERC20(address(rewardTokens[0]))
            ),
            initialReward + additionalReward,
            10, // Allow difference of up to 10 wei
            "GetRewardForDuration should return approximately total reward"
        );
    }
}
