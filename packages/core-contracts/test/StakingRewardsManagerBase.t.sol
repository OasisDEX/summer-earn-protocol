// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {FleetStakingRewardsManager} from "../src/contracts/FleetStakingRewardsManager.sol";
import {IFleetStakingRewardsManager} from "../src/interfaces/IFleetStakingRewardsManager.sol";
import {IStakingRewardsManagerBaseErrors} from "../src/errors/IStakingRewardsManagerBaseErrors.sol";
import {MockSummerGovernor} from "./mocks/MockSummerGovernor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test, console} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ProtocolAccessManager} from "../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../src/interfaces/IProtocolAccessManager.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/src/VotingDecayLibrary.sol";

contract StakingRewardsManagerBaseTest is Test {
    FleetStakingRewardsManager public stakingRewardsManager;
    ERC20Mock public stakingToken;
    ERC20Mock[] public rewardTokens;
    MockSummerGovernor public mockGovernor;

    address public owner;
    address public alice;
    address public bob;
    ERC20Mock public mockFleetCommander = new ERC20Mock();

    uint256 constant INITIAL_REWARD_AMOUNT = 1000000 * 1e18;
    uint256 constant INITIAL_STAKE_AMOUNT = 100000 * 1e18;

    function setUp() public {
        owner = address(this);
        alice = address(0x1);
        bob = address(0x2);

        // Deploy mock tokens
        console.log("Deploying mock tokens");
        for (uint i = 0; i < 3; i++) {
            rewardTokens.push(new ERC20Mock());
        }

        // Deploy mock governor
        console.log("Deploying mock governor");
        mockGovernor = new MockSummerGovernor(
            0,
            0,
            VotingDecayLibrary.DecayFunction.Linear
        );

        // Deploy StakingRewardsManager
        console.log("Deploying staking rewards manager");
        address[] memory rewardTokenAddresses = new address[](
            rewardTokens.length
        );
        for (uint i = 0; i < rewardTokens.length; i++) {
            rewardTokenAddresses[i] = address(rewardTokens[i]);
        }
        IProtocolAccessManager accessManager = new ProtocolAccessManager(
            address(mockGovernor)
        );
        stakingRewardsManager = new FleetStakingRewardsManager(
            address(accessManager),
            address(mockFleetCommander)
        );

        // Mint initial tokens
        console.log("Minting initial tokens");
        mockFleetCommander.mint(alice, INITIAL_STAKE_AMOUNT);
        mockFleetCommander.mint(bob, INITIAL_STAKE_AMOUNT);
        for (uint i = 0; i < rewardTokens.length; i++) {
            rewardTokens[i].mint(
                address(stakingRewardsManager),
                INITIAL_REWARD_AMOUNT
            );
        }

        // Approve staking
        vm.prank(alice);
        mockFleetCommander.approve(
            address(stakingRewardsManager),
            type(uint256).max
        );
        vm.prank(bob);
        mockFleetCommander.approve(
            address(stakingRewardsManager),
            type(uint256).max
        );
    }

    function test_NotifyRewardAmount() public {
        vm.prank(address(mockGovernor));

        IERC20 rewardToken = rewardTokens[0];
        uint256 rewardAmount = 100000000000000000000; // 100 tokens
        uint256 newDuration = 14 days; // New duration for the reward

        stakingRewardsManager.notifyRewardAmount(
            rewardToken,
            rewardAmount,
            newDuration
        );

        (
            uint256 periodFinish,
            uint256 rewardRate,
            uint256 duration,
            ,

        ) = stakingRewardsManager.rewardData(rewardToken);

        assertEq(
            periodFinish,
            block.timestamp + duration,
            "Period finish should be current time plus duration"
        );
        assertEq(
            rewardRate,
            rewardAmount / duration,
            "Reward rate should be reward amount divided by duration"
        );
        assertEq(
            duration,
            newDuration,
            "Duration should be the new specified duration"
        );
    }

    function test_NotifyRewardAmount_NewToken() public {
        ERC20Mock newRewardToken = new ERC20Mock();
        uint256 rewardAmount = 1000 * 1e18; // 1000 tokens
        uint256 newDuration = 30 days; // New duration for the reward

        // Mint reward tokens to the staking rewards manager
        newRewardToken.mint(address(stakingRewardsManager), rewardAmount);

        vm.prank(address(mockGovernor));
        stakingRewardsManager.notifyRewardAmount(
            IERC20(address(newRewardToken)),
            rewardAmount,
            newDuration
        );

        // Get the reward data
        (
            uint256 periodFinish,
            uint256 rewardRate,
            uint256 rewardsDuration,
            uint256 lastUpdateTime,
            uint256 rewardPerTokenStored
        ) = stakingRewardsManager.rewardData(newRewardToken);

        // Assert the correct values
        assertEq(
            rewardsDuration,
            newDuration,
            "Rewards duration should be set to the new specified duration"
        );

        assertEq(
            periodFinish,
            block.timestamp + newDuration,
            "Period finish should be set correctly"
        );
        assertEq(
            rewardRate,
            rewardAmount / newDuration,
            "Reward rate should be set correctly"
        );
        assertEq(
            lastUpdateTime,
            block.timestamp,
            "Last update time should be set to current timestamp"
        );
        assertEq(
            rewardPerTokenStored,
            0,
            "Reward per token stored should be 0 initially"
        );
    }

    function test_NotifyRewardAmount_ExistingToken_CannotChangeDuration()
        public
    {
        IERC20 rewardToken = rewardTokens[0];
        uint256 initialRewardAmount = 100 * 1e18;
        uint256 initialDuration = 7 days;

        // First notification to set up the reward token
        vm.prank(address(mockGovernor));
        stakingRewardsManager.notifyRewardAmount(
            rewardToken,
            initialRewardAmount,
            initialDuration
        );

        // Try to change the duration for an existing token
        uint256 newRewardAmount = 200 * 1e18;
        uint256 newDuration = 14 days;

        vm.prank(address(mockGovernor));
        vm.expectRevert(
            abi.encodeWithSignature("CannotChangeRewardsDuration()")
        );
        stakingRewardsManager.notifyRewardAmount(
            rewardToken,
            newRewardAmount,
            newDuration
        );

        // Verify that the original duration is still in place
        (, , uint256 duration, , ) = stakingRewardsManager.rewardData(
            rewardToken
        );
        assertEq(duration, initialDuration, "Duration should not have changed");
    }

    function test_SetRewardsDuration() public {
        IERC20 rewardToken1 = rewardTokens[1];

        // First, check if the reward token is already added
        (, , uint256 rewardsDuration, , ) = stakingRewardsManager.rewardData(
            rewardToken1
        );

        if (rewardsDuration == 0) {
            // Only add the reward token if it hasn't been added yet
            vm.prank(address(mockGovernor));
            stakingRewardsManager.notifyRewardAmount(
                rewardToken1,
                604800,
                7 days
            );
        }

        vm.warp(block.timestamp + 8 days);

        vm.prank(address(mockGovernor));
        stakingRewardsManager.setRewardsDuration(rewardToken1, 1209600);

        // Assert the new rewards duration
        (, , uint256 newRewardsDuration, , ) = stakingRewardsManager.rewardData(
            rewardToken1
        );
        assertEq(newRewardsDuration, 1209600);
    }

    function test_SetRewardsDuration_RevertIfPeriodNotComplete() public {
        IERC20 rewardToken = rewardTokens[0];
        uint256 initialDuration = 7 days;
        uint256 rewardAmount = 100 * 1e18;

        // Setup initial reward period
        vm.prank(address(mockGovernor));
        stakingRewardsManager.notifyRewardAmount(
            rewardToken,
            rewardAmount,
            initialDuration
        );

        // Try to change duration while period is still active
        vm.prank(address(mockGovernor));
        vm.expectRevert(abi.encodeWithSignature("RewardPeriodNotComplete()"));
        stakingRewardsManager.setRewardsDuration(rewardToken, 14 days);

        // Verify we can set duration after period is complete
        vm.warp(block.timestamp + initialDuration + 1);
        vm.prank(address(mockGovernor));
        stakingRewardsManager.setRewardsDuration(rewardToken, 14 days);
    }

    function test_Stake() public {
        uint256 stakeAmount = 1000 * 1e18;
        vm.prank(alice);
        stakingRewardsManager.stake(stakeAmount);

        assertEq(
            stakingRewardsManager.balanceOf(alice),
            stakeAmount,
            "Stake amount should be correct"
        );
        assertEq(
            stakingRewardsManager.totalSupply(),
            stakeAmount,
            "Total supply should be updated"
        );
    }

    function test_Unstake() public {
        uint256 stakeAmount = 1000 * 1e18;
        vm.startPrank(alice);
        stakingRewardsManager.stake(stakeAmount);
        stakingRewardsManager.unstake(stakeAmount);
        vm.stopPrank();

        assertEq(
            stakingRewardsManager.balanceOf(alice),
            0,
            "Balance should be zero after withdrawal"
        );
    }

    function test_GetReward() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256 rewardAmount = 100 * 1e18;

        vm.prank(alice);
        stakingRewardsManager.stake(stakeAmount);

        vm.prank(address(mockGovernor));
        stakingRewardsManager.notifyRewardAmount(
            IERC20(address(rewardTokens[0])),
            rewardAmount,
            7 days
        );

        // Fast forward time
        vm.warp(block.timestamp + 7 days);

        uint256 balanceBefore = rewardTokens[0].balanceOf(alice);

        vm.prank(alice);
        stakingRewardsManager.getReward();

        uint256 balanceAfter = rewardTokens[0].balanceOf(alice);
        assertGt(
            balanceAfter,
            balanceBefore,
            "Alice should have received rewards"
        );
    }

    function test_Exit() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256 rewardAmount = 100 * 1e18;

        vm.prank(alice);
        stakingRewardsManager.stake(stakeAmount);

        vm.prank(address(mockGovernor));
        stakingRewardsManager.notifyRewardAmount(
            IERC20(address(rewardTokens[0])),
            rewardAmount,
            7 days
        );

        // Fast forward time
        vm.warp(block.timestamp + 7 days);

        uint256 stakingTokenBalanceBefore = mockFleetCommander.balanceOf(alice);
        uint256 rewardTokenBalanceBefore = rewardTokens[0].balanceOf(alice);

        vm.prank(alice);
        stakingRewardsManager.exit();

        uint256 stakingTokenBalanceAfter = mockFleetCommander.balanceOf(alice);
        uint256 rewardTokenBalanceAfter = rewardTokens[0].balanceOf(alice);
        console.log("Reward token balance before", rewardTokenBalanceBefore);
        console.log("Reward token balance after", rewardTokenBalanceAfter);
        assertEq(
            stakingTokenBalanceAfter,
            stakingTokenBalanceBefore + stakeAmount,
            "Staking tokens should be returned"
        );
        assertGt(
            rewardTokenBalanceAfter,
            rewardTokenBalanceBefore,
            "Rewards should be claimed"
        );
        assertEq(
            stakingRewardsManager.balanceOf(alice),
            0,
            "Staked balance should be zero"
        );
    }

    function test_MultipleRewardTokensComprehensive() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256[] memory rewardAmounts = new uint256[](3);
        rewardAmounts[0] = 100 * 1e18;
        rewardAmounts[1] = 200 * 1e18;
        rewardAmounts[2] = 300 * 1e18;

        // Stake tokens
        vm.prank(alice);
        stakingRewardsManager.stake(stakeAmount);

        // Notify rewards for all three tokens
        vm.startPrank(address(mockGovernor));
        for (uint i = 0; i < rewardTokens.length; i++) {
            stakingRewardsManager.notifyRewardAmount(
                IERC20(address(rewardTokens[i])),
                rewardAmounts[i],
                7 days
            );
        }
        vm.stopPrank();

        // Fast forward time (half the reward period)
        vm.warp(block.timestamp + 3.5 days);

        // Check earned amounts
        uint256[] memory earnedAmounts = new uint256[](3);
        for (uint i = 0; i < rewardTokens.length; i++) {
            earnedAmounts[i] = stakingRewardsManager.earned(
                alice,
                IERC20(address(rewardTokens[i]))
            );
            assertGt(
                earnedAmounts[i],
                0,
                string(
                    abi.encodePacked(
                        "Should have earned rewards from token ",
                        i
                    )
                )
            );
            assertLt(
                earnedAmounts[i],
                rewardAmounts[i],
                string(
                    abi.encodePacked(
                        "Earned amount should be less than total reward for token ",
                        i
                    )
                )
            );
        }

        // Get rewards
        uint256[] memory balancesBefore = new uint256[](3);
        uint256[] memory balancesAfter = new uint256[](3);

        for (uint i = 0; i < rewardTokens.length; i++) {
            balancesBefore[i] = rewardTokens[i].balanceOf(alice);
        }

        vm.prank(alice);
        stakingRewardsManager.getReward();

        for (uint i = 0; i < rewardTokens.length; i++) {
            balancesAfter[i] = rewardTokens[i].balanceOf(alice);
            assertGt(
                balancesAfter[i],
                balancesBefore[i],
                string(
                    abi.encodePacked(
                        "Should have received rewards from token ",
                        i
                    )
                )
            );
            assertEq(
                balancesAfter[i] - balancesBefore[i],
                earnedAmounts[i],
                string(
                    abi.encodePacked(
                        "Received reward should match earned amount for token ",
                        i
                    )
                )
            );
        }

        // Fast forward to end of reward period
        vm.warp(block.timestamp + 3.5 days);

        // Check final earned amounts
        for (uint i = 0; i < rewardTokens.length; i++) {
            uint256 finalEarnedAmount = stakingRewardsManager.earned(
                alice,
                IERC20(address(rewardTokens[i]))
            );
            assertGt(
                finalEarnedAmount,
                0,
                string(
                    abi.encodePacked(
                        "Should have earned more rewards from token ",
                        i
                    )
                )
            );
            assertLt(
                finalEarnedAmount,
                rewardAmounts[i] - earnedAmounts[i],
                string(
                    abi.encodePacked(
                        "Final earned amount should be less than remaining reward for token ",
                        i
                    )
                )
            );
        }

        // Record balances before final getReward
        uint256[] memory balancesBeforeFinal = new uint256[](
            rewardTokens.length
        );
        for (uint i = 0; i < rewardTokens.length; i++) {
            balancesBeforeFinal[i] = rewardTokens[i].balanceOf(alice);
        }

        // Get final rewards
        vm.prank(alice);
        stakingRewardsManager.getReward();

        // Verify all rewards have been claimed
        for (uint i = 0; i < rewardTokens.length; i++) {
            uint256 finalBalance = rewardTokens[i].balanceOf(alice);
            uint256 rewardReceived = finalBalance - balancesBeforeFinal[i];

            // Check that some reward was received
            assertGt(
                rewardReceived,
                0,
                string(
                    abi.encodePacked(
                        "Should have received rewards from token ",
                        i
                    )
                )
            );

            // Check that the total rewards received are close to the expected amount
            uint256 totalRewardsReceived = finalBalance - balancesBefore[i];
            uint256 expectedTotalRewards = rewardAmounts[i];

            // Allow for a small difference due to potential rounding
            uint256 allowedDifference = 1e9; // 1 Gwei, adjust as needed
            assertApproxEqAbs(
                totalRewardsReceived,
                expectedTotalRewards,
                allowedDifference,
                string(
                    abi.encodePacked(
                        "Total rewards should be close to expected for token ",
                        i
                    )
                )
            );
        }
    }

    function test_CannotUnstakeZero() public {
        // First stake some tokens to ensure we have a valid staking position
        uint256 stakeAmount = 1000 * 1e18;
        vm.prank(alice);
        stakingRewardsManager.stake(stakeAmount);

        // Try to unstake zero tokens
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("CannotUnstakeZero()"));
        stakingRewardsManager.unstake(0);
    }

    function test_NotifyRewardAmount_RevertIfRewardTooHigh() public {
        IERC20 rewardToken = rewardTokens[0];
        uint256 balance = rewardToken.balanceOf(address(stakingRewardsManager));
        uint256 duration = 7 days;

        // Calculate a reward that will result in a reward rate higher than balance/duration
        // We need: reward/duration > balance/duration
        // Multiply balance by 2 to ensure reward rate will be too high
        uint256 tooHighReward = balance * 2;

        vm.prank(address(mockGovernor));
        vm.expectRevert(abi.encodeWithSignature("ProvidedRewardTooHigh()"));
        stakingRewardsManager.notifyRewardAmount(
            rewardToken,
            tooHighReward,
            duration
        );

        // Verify that setting a valid reward amount works
        uint256 validReward = balance;
        vm.prank(address(mockGovernor));
        stakingRewardsManager.notifyRewardAmount(
            rewardToken,
            validReward,
            duration
        );
    }

    function test_NotifyRewardAmount_RevertIfDurationZero() public {
        IERC20 rewardToken = rewardTokens[0];
        uint256 rewardAmount = 100 * 1e18;
        uint256 zeroDuration = 0;

        // Try to notify a reward with zero duration
        vm.prank(address(mockGovernor));
        vm.expectRevert(
            abi.encodeWithSignature("RewardsDurationCannotBeZero()")
        );
        stakingRewardsManager.notifyRewardAmount(
            rewardToken,
            rewardAmount,
            zeroDuration
        );

        // Verify that setting a valid duration works
        uint256 validDuration = 7 days;
        vm.prank(address(mockGovernor));
        stakingRewardsManager.notifyRewardAmount(
            rewardToken,
            rewardAmount,
            validDuration
        );
    }

    function test_NotifyRewardAmount_WithExistingPeriod() public {
        IERC20 rewardToken = rewardTokens[0];
        uint256 initialReward = 100 * 1e18;
        uint256 duration = 7 days;

        // Set up initial reward period
        vm.prank(address(mockGovernor));
        stakingRewardsManager.notifyRewardAmount(
            rewardToken,
            initialReward,
            duration
        );

        // Fast forward to middle of reward period
        vm.warp(block.timestamp + duration / 2);

        // Add more rewards during active period
        uint256 additionalReward = 50 * 1e18;
        vm.prank(address(mockGovernor));
        stakingRewardsManager.notifyRewardAmount(
            rewardToken,
            additionalReward,
            duration
        );

        // Get reward data to verify calculations
        (
            uint256 periodFinish,
            uint256 rewardRate,
            uint256 rewardsDuration,
            ,

        ) = stakingRewardsManager.rewardData(rewardToken);

        // Verify period was extended correctly
        assertEq(
            periodFinish,
            block.timestamp + duration,
            "Period finish should be extended"
        );

        // Verify reward rate includes leftover rewards
        uint256 expectedRate = (additionalReward +
            ((initialReward * duration) / 2) /
            duration) / duration;
        assertApproxEqAbs(
            rewardRate,
            expectedRate,
            1e9, // Allow for small rounding differences
            "Reward rate should account for leftover rewards"
        );
    }

    function test_UpdateReward_NonZeroAddress() public {
        // Setup initial reward
        IERC20 rewardToken = rewardTokens[0];
        uint256 rewardAmount = 100 * 1e18;
        uint256 duration = 7 days;

        vm.prank(address(mockGovernor));
        stakingRewardsManager.notifyRewardAmount(
            rewardToken,
            rewardAmount,
            duration
        );

        // Have alice stake some tokens
        uint256 stakeAmount = 1000 * 1e18;
        vm.prank(alice);
        stakingRewardsManager.stake(stakeAmount);

        // Fast forward some time
        vm.warp(block.timestamp + 1 days);

        // Get initial earned amount
        uint256 initialEarned = stakingRewardsManager.earned(
            alice,
            rewardToken
        );

        // Perform another action that triggers updateReward
        vm.prank(alice);
        stakingRewardsManager.stake(stakeAmount);

        // Check that rewards were properly updated
        uint256 newEarned = stakingRewardsManager.earned(alice, rewardToken);
        assertGe(newEarned, initialEarned, "Rewards should have been updated");

        // Verify reward per token stored was updated
        (, , , , uint256 rewardPerTokenStored) = stakingRewardsManager
            .rewardData(rewardToken);
        assertGt(
            rewardPerTokenStored,
            0,
            "Reward per token stored should have been updated"
        );
    }
}
