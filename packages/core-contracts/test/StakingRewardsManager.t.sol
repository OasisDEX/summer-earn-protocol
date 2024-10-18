// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {StakingRewardsManager} from "../src/contracts/StakingRewardsManager.sol";
import {IStakingRewardsManager} from "../src/interfaces/IStakingRewardsManager.sol";
import {IStakingRewardsManagerErrors} from "../src/errors/IStakingRewardsManagerErrors.sol";
import {MockSummerGovernor} from "./mocks/MockSummerGovernor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test, console} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ProtocolAccessManager} from "../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../src/interfaces/IProtocolAccessManager.sol";

contract StakingRewardsManagerTest is Test {
    StakingRewardsManager public stakingRewardsManager;
    ERC20Mock public stakingToken;
    ERC20Mock[] public rewardTokens;
    MockSummerGovernor public mockGovernor;

    address public owner;
    address public alice;
    address public bob;

    uint256 constant INITIAL_REWARD_AMOUNT = 1000000 * 1e18;
    uint256 constant INITIAL_STAKE_AMOUNT = 100000 * 1e18;

    function setUp() public {
        owner = address(this);
        alice = address(0x1);
        bob = address(0x2);

        // Deploy mock tokens
        console.log("Deploying mock tokens");
        stakingToken = new ERC20Mock();
        for (uint i = 0; i < 3; i++) {
            rewardTokens.push(new ERC20Mock());
        }

        // Deploy mock governor
        console.log("Deploying mock governor");
        mockGovernor = new MockSummerGovernor();

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
        stakingRewardsManager = new StakingRewardsManager(
            IStakingRewardsManager.StakingRewardsParams({
                rewardTokens: rewardTokenAddresses,
                accessManager: address(accessManager),
                governor: address(mockGovernor)
            })
        );

        vm.prank(address(mockGovernor));
        stakingRewardsManager.initialize(IERC20(address(stakingToken)));

        // Mint initial tokens
        console.log("Minting initial tokens");
        stakingToken.mint(alice, INITIAL_STAKE_AMOUNT);
        stakingToken.mint(bob, INITIAL_STAKE_AMOUNT);
        for (uint i = 0; i < rewardTokens.length; i++) {
            rewardTokens[i].mint(
                address(stakingRewardsManager),
                INITIAL_REWARD_AMOUNT
            );
        }

        // Approve staking
        vm.prank(alice);
        stakingToken.approve(address(stakingRewardsManager), type(uint256).max);
        vm.prank(bob);
        stakingToken.approve(address(stakingRewardsManager), type(uint256).max);
    }

    function test_NotifyRewardAmount() public {
        vm.prank(address(mockGovernor));

        IERC20 rewardToken = rewardTokens[0];
        uint256 rewardAmount = 100000000000000000000; // 100 tokens
        stakingRewardsManager.notifyRewardAmount(rewardToken, rewardAmount);

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
        assertEq(duration, 604800, "Duration should be 7 days in seconds");
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
            stakingRewardsManager.addRewardToken(rewardToken1, 604800);
        }

        // Continue with the rest of your test...
        vm.prank(address(mockGovernor));
        stakingRewardsManager.setRewardsDuration(rewardToken1, 1209600);

        // Assert the new rewards duration
        (, , uint256 newRewardsDuration, , ) = stakingRewardsManager.rewardData(
            rewardToken1
        );
        assertEq(newRewardsDuration, 1209600);
    }

    function test_AddRewardToken() public {
        ERC20Mock newRewardToken = new ERC20Mock();
        uint256 newRewardsDuration = 30 days;

        vm.prank(address(mockGovernor));
        stakingRewardsManager.addRewardToken(
            IERC20(address(newRewardToken)),
            newRewardsDuration
        );

        // Get the reward data
        (
            uint256 periodFinish,
            uint256 rewardRate,
            uint256 rewardsDuration,
            uint256 lastUpdateTime,
            uint256 rewardPerTokenStored
        ) = stakingRewardsManager.rewardData(newRewardToken);

        // Assert the correct value
        assertEq(
            rewardsDuration,
            2592000,
            "Rewards duration should be set correctly"
        );

        assertEq(periodFinish, 0, "Period finish should be 0 initially");
        assertEq(rewardRate, 0, "Reward rate should be 0 initially");
        assertEq(lastUpdateTime, 0, "Last update time should be 0 initially");
        assertEq(
            rewardPerTokenStored,
            0,
            "Reward per token stored should be 0 initially"
        );
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

    function test_Withdraw() public {
        uint256 stakeAmount = 1000 * 1e18;
        vm.startPrank(alice);
        stakingRewardsManager.stake(stakeAmount);
        stakingRewardsManager.withdraw(stakeAmount);
        vm.stopPrank();

        assertEq(
            stakingRewardsManager.balanceOf(alice),
            0,
            "Balance should be zero after withdrawal"
        );
        assertEq(
            stakingRewardsManager.totalSupply(),
            0,
            "Total supply should be zero after withdrawal"
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
            rewardAmount
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
            rewardAmount
        );

        // Fast forward time
        vm.warp(block.timestamp + 7 days);

        uint256 stakingTokenBalanceBefore = stakingToken.balanceOf(alice);
        uint256 rewardTokenBalanceBefore = rewardTokens[0].balanceOf(alice);

        vm.prank(alice);
        stakingRewardsManager.exit();

        uint256 stakingTokenBalanceAfter = stakingToken.balanceOf(alice);
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
                rewardAmounts[i]
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
}
