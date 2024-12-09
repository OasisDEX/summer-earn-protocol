// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {MockStakingRewardsManager} from "./MockStakingRewardsManager.sol";
import {IStakingRewardsManagerBaseErrors} from "../src/interfaces/IStakingRewardsManagerBaseErrors.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test, console} from "forge-std/Test.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/VotingDecayLibrary.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {IStakingRewardsManagerBase} from "../src/interfaces/IStakingRewardsManagerBase.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";

contract StakingRewardsManagerBaseTest is Test {
    MockStakingRewardsManager public stakingRewardsManager;
    ERC20Mock public stakingToken;
    ERC20Mock[] public rewardTokens;
    address public mockGovernor;

    address public owner;
    address public alice;
    address public bob;
    ERC20Mock public mockStakingToken;

    uint256 constant INITIAL_REWARD_AMOUNT = 1000000 * 1e18;
    uint256 constant INITIAL_STAKE_AMOUNT = 100000 * 1e18;

    function setUp() public {
        owner = address(this);
        alice = address(0x1);
        bob = address(0x2);
        mockGovernor = address(0x3);

        // Deploy mock tokens
        console.log("Deploying mock tokens");
        mockStakingToken = new ERC20Mock();
        for (uint256 i = 0; i < 3; i++) {
            rewardTokens.push(new ERC20Mock());
        }

        // Deploy StakingRewardsManager
        console.log("Deploying staking rewards manager");
        IProtocolAccessManager accessManager = new ProtocolAccessManager(
            mockGovernor
        );
        stakingRewardsManager = new MockStakingRewardsManager(
            address(accessManager),
            address(mockStakingToken)
        );

        // Mint initial tokens
        console.log("Minting initial tokens");
        mockStakingToken.mint(alice, INITIAL_STAKE_AMOUNT);
        mockStakingToken.mint(bob, INITIAL_STAKE_AMOUNT);
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            rewardTokens[i].mint(
                address(stakingRewardsManager),
                INITIAL_REWARD_AMOUNT
            );
        }

        // Approve staking
        vm.prank(alice);
        mockStakingToken.approve(
            address(stakingRewardsManager),
            type(uint256).max
        );
        vm.prank(bob);
        mockStakingToken.approve(
            address(stakingRewardsManager),
            type(uint256).max
        );
    }

    function test_NotifyRewardAmount() public {
        vm.prank(mockGovernor);

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

    function test_NotifyRewardAmount_StakingToken() public {
        vm.expectRevert(
            abi.encodeWithSignature("CantAddStakingTokenAsReward()")
        );
        vm.prank(mockGovernor);
        stakingRewardsManager.notifyRewardAmount(
            IERC20(address(mockStakingToken)),
            1000 * 1e18,
            30 days
        );
    }
    function test_NotifyRewardAmount_NewToken() public {
        ERC20Mock newRewardToken = new ERC20Mock();
        uint256 rewardAmount = 1000 * 1e18; // 1000 tokens
        uint256 newDuration = 30 days; // New duration for the reward

        // Mint reward tokens to the staking rewards manager
        newRewardToken.mint(address(stakingRewardsManager), rewardAmount);

        vm.prank(mockGovernor);
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
        vm.prank(mockGovernor);
        stakingRewardsManager.notifyRewardAmount(
            rewardToken,
            initialRewardAmount,
            initialDuration
        );

        // Try to change the duration for an existing token
        uint256 newRewardAmount = 200 * 1e18;
        uint256 newDuration = 14 days;

        vm.prank(mockGovernor);
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
            vm.prank(mockGovernor);
            stakingRewardsManager.notifyRewardAmount(
                rewardToken1,
                604800,
                7 days
            );
        }

        vm.warp(block.timestamp + 8 days);

        vm.prank(mockGovernor);
        stakingRewardsManager.setRewardsDuration(rewardToken1, 1209600);

        // Assert the new rewards duration
        (, , uint256 newRewardsDuration, , ) = stakingRewardsManager.rewardData(
            rewardToken1
        );
        assertEq(newRewardsDuration, 1209600);
    }

    function test_SetRewardsDuration_NonExistingToken() public {
        vm.expectRevert(abi.encodeWithSignature("RewardTokenDoesNotExist()"));
        vm.prank(mockGovernor);
        stakingRewardsManager.setRewardsDuration(
            IERC20(address(0x789)),
            1209600
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

    function test_Unstake() public {
        uint256 stakeAmount = 1000 * 1e18;
        vm.startPrank(alice);
        stakingRewardsManager.stake(stakeAmount);
        stakingRewardsManager.unstake(stakeAmount);
        vm.stopPrank();

        assertEq(
            stakingRewardsManager.balanceOf(alice),
            0,
            "Balance should be zero after unstake"
        );
        assertEq(
            stakingRewardsManager.totalSupply(),
            0,
            "Total supply should be zero after unstake"
        );
    }

    function test_GetReward() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256 rewardAmount = 100 * 1e18;

        vm.prank(alice);
        stakingRewardsManager.stake(stakeAmount);

        vm.prank(mockGovernor);
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

        vm.prank(mockGovernor);
        stakingRewardsManager.notifyRewardAmount(
            IERC20(address(rewardTokens[0])),
            rewardAmount,
            7 days
        );

        // Fast forward time
        vm.warp(block.timestamp + 7 days);

        uint256 stakingTokenBalanceBefore = mockStakingToken.balanceOf(alice);
        uint256 rewardTokenBalanceBefore = rewardTokens[0].balanceOf(alice);

        vm.prank(alice);
        stakingRewardsManager.exit();

        uint256 stakingTokenBalanceAfter = mockStakingToken.balanceOf(alice);
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
        vm.startPrank(mockGovernor);
        for (uint256 i = 0; i < rewardTokens.length; i++) {
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
        for (uint256 i = 0; i < rewardTokens.length; i++) {
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

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            balancesBefore[i] = rewardTokens[i].balanceOf(alice);
        }

        vm.prank(alice);
        stakingRewardsManager.getReward();

        for (uint256 i = 0; i < rewardTokens.length; i++) {
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
        for (uint256 i = 0; i < rewardTokens.length; i++) {
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
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            balancesBeforeFinal[i] = rewardTokens[i].balanceOf(alice);
        }

        // Get final rewards
        vm.prank(alice);
        stakingRewardsManager.getReward();

        // Verify all rewards have been claimed
        for (uint256 i = 0; i < rewardTokens.length; i++) {
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

    function test_UpdateReward() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256 rewardAmount = 100 * 1e18;

        // Setup initial state
        vm.prank(alice);
        stakingRewardsManager.stake(stakeAmount);

        vm.prank(mockGovernor);
        stakingRewardsManager.notifyRewardAmount(
            IERC20(address(rewardTokens[0])),
            rewardAmount,
            7 days
        );

        // Fast forward time to accumulate some rewards
        vm.warp(block.timestamp + 1 days);

        // Get initial reward data
        (
            ,
            ,
            ,
            uint256 lastUpdateTimeBefore,
            uint256 rewardPerTokenStoredBefore
        ) = stakingRewardsManager.rewardData(IERC20(address(rewardTokens[0])));

        // Perform action that triggers updateReward modifier
        vm.prank(alice);
        stakingRewardsManager.stake(100); // Small stake to trigger update

        // Get updated reward data
        (
            ,
            ,
            ,
            uint256 lastUpdateTimeAfter,
            uint256 rewardPerTokenStoredAfter
        ) = stakingRewardsManager.rewardData(IERC20(address(rewardTokens[0])));

        // Verify updates occurred
        assertGt(
            lastUpdateTimeAfter,
            lastUpdateTimeBefore,
            "Last update time should increase"
        );
        assertGt(
            rewardPerTokenStoredAfter,
            rewardPerTokenStoredBefore,
            "Reward per token stored should increase"
        );

        // Verify rewards mapping was updated
        uint256 rewards = stakingRewardsManager.rewards(
            IERC20(address(rewardTokens[0])),
            alice
        );
        assertGt(rewards, 0, "Rewards should be updated for alice");
    }

    function test_UpdateReward_ZeroAddress() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256 rewardAmount = 100 * 1e18;

        // Setup initial state
        vm.prank(alice);
        stakingRewardsManager.stake(stakeAmount);

        vm.prank(mockGovernor);
        stakingRewardsManager.notifyRewardAmount(
            IERC20(address(rewardTokens[0])),
            rewardAmount,
            7 days
        );

        // Fast forward time to accumulate some rewards
        vm.warp(block.timestamp + 1 days);

        // Get initial reward data
        (
            uint256 periodFinish,
            uint256 rewardRate,
            uint256 rewardsDuration,
            uint256 lastUpdateTimeBefore,
            uint256 rewardPerTokenStoredBefore
        ) = stakingRewardsManager.rewardData(IERC20(address(rewardTokens[0])));

        console.log("Before - lastUpdateTime:", lastUpdateTimeBefore);
        console.log("Before - block.timestamp:", block.timestamp);
        console.log("Before - periodFinish:", periodFinish);
        console.log("Before - rewardRate:", rewardRate);

        // Advance time again
        vm.warp(block.timestamp + 1 hours);

        console.log("After warp - block.timestamp:", block.timestamp);

        // Make a small stake to trigger the updateReward modifier
        vm.prank(bob);
        stakingRewardsManager.stake(100);

        // Get updated reward data
        (
            ,
            ,
            ,
            uint256 lastUpdateTimeAfter,
            uint256 rewardPerTokenStoredAfter
        ) = stakingRewardsManager.rewardData(IERC20(address(rewardTokens[0])));

        console.log("After - lastUpdateTime:", lastUpdateTimeAfter);
        console.log("After - block.timestamp:", block.timestamp);

        // Verify updates occurred but rewards mapping wasn't updated
        assertGt(
            lastUpdateTimeAfter,
            lastUpdateTimeBefore,
            "Last update time should increase"
        );
        assertGt(
            rewardPerTokenStoredAfter,
            rewardPerTokenStoredBefore,
            "Reward per token stored should increase"
        );

        // Verify rewards mapping was not updated for zero address
        uint256 zeroAddressRewards = stakingRewardsManager.rewards(
            IERC20(address(rewardTokens[0])),
            address(0)
        );
        assertEq(zeroAddressRewards, 0, "Zero address should have no rewards");
    }

    function test_RewardTokens() public {
        // First notify some rewards to ensure tokens are added to the list
        uint256 rewardAmount = 100 * 1e18;
        uint256 duration = 7 days;

        vm.startPrank(mockGovernor);
        for (uint i = 0; i < rewardTokens.length; i++) {
            stakingRewardsManager.notifyRewardAmount(
                rewardTokens[i],
                rewardAmount,
                duration
            );
        }
        vm.stopPrank();

        // Test valid index
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            IERC20 token = stakingRewardsManager.rewardTokens(i);
            assertEq(
                address(token),
                address(rewardTokens[i]),
                "Reward token address should match"
            );
        }

        // Test index out of bounds
        vm.expectRevert(abi.encodeWithSignature("IndexOutOfBounds()"));
        stakingRewardsManager.rewardTokens(rewardTokens.length);
    }

    function test_GetRewardForDuration() public {
        IERC20 rewardToken = rewardTokens[0];
        uint256 rewardAmount = 100 * 1e18;
        uint256 duration = 7 days;

        // Setup reward data by notifying reward amount
        vm.prank(mockGovernor);
        stakingRewardsManager.notifyRewardAmount(
            rewardToken,
            rewardAmount,
            duration
        );

        // Get reward for duration
        uint256 rewardForDuration = stakingRewardsManager.getRewardForDuration(
            rewardToken
        );

        // Get reward data for manual calculation verification
        (
            ,
            uint256 rewardRate,
            uint256 rewardsDuration,
            ,

        ) = stakingRewardsManager.rewardData(rewardToken);

        // Verify both calculations with a small tolerance for rounding
        // Allow for 0.0001% difference (1 basis point)
        assertApproxEqRel(
            rewardForDuration,
            rewardAmount,
            0.0001e16, // 0.0001% in ray units (1e18 based)
            "Total reward for duration should approximately equal notified amount"
        );

        assertApproxEqRel(
            rewardForDuration,
            rewardRate * rewardsDuration,
            0.0001e16,
            "Reward for duration calculation incorrect"
        );
    }

    function test_RemoveRewardToken() public {
        IERC20 rewardToken = rewardTokens[0];
        uint256 rewardAmount = 1000000 * 1e18; // 1M tokens = 1e24
        uint256 duration = 7 days;

        // Test 1: Cannot remove non-existent token
        IERC20 nonExistentToken = IERC20(address(0x123));
        vm.prank(mockGovernor);
        vm.expectRevert(abi.encodeWithSignature("RewardTokenDoesNotExist()"));
        stakingRewardsManager.removeRewardToken(nonExistentToken);

        // Setup initial state with a reward token
        vm.startPrank(mockGovernor);
        stakingRewardsManager.notifyRewardAmount(
            rewardToken,
            rewardAmount,
            duration
        );
        vm.stopPrank();

        // Test 2: Cannot remove token while period is active
        vm.prank(mockGovernor);
        vm.expectRevert(abi.encodeWithSignature("RewardPeriodNotComplete()"));
        stakingRewardsManager.removeRewardToken(rewardToken);

        // Fast forward past reward period
        vm.warp(block.timestamp + duration + 1);

        // Test 3: Cannot remove if there's remaining balance
        vm.prank(mockGovernor);
        vm.expectRevert(
            abi.encodeWithSignature(
                "RewardTokenStillHasBalance(uint256)",
                rewardAmount
            )
        );
        stakingRewardsManager.removeRewardToken(rewardToken);

        // Simulate all rewards being claimed by transferring tokens out
        vm.startPrank(address(stakingRewardsManager));
        rewardToken.transfer(address(1), rewardAmount);
        vm.stopPrank();

        // Test 4: Successful removal
        vm.prank(mockGovernor);
        vm.expectEmit(true, false, false, false);
        emit IStakingRewardsManagerBase.RewardTokenRemoved(
            address(rewardToken)
        );
        stakingRewardsManager.removeRewardToken(rewardToken);

        // Verify token was removed
        vm.prank(mockGovernor);
        vm.expectRevert(abi.encodeWithSignature("RewardTokenDoesNotExist()"));
        stakingRewardsManager.removeRewardToken(rewardToken);
    }

    function test_RemoveRewardToken_RewardTokenNotInitialized() public {
        vm.expectRevert(abi.encodeWithSignature("RewardTokenDoesNotExist()"));
        vm.prank(mockGovernor);
        stakingRewardsManager.removeRewardToken(IERC20(address(0)));
    }

    function test_Stake_StakingTokenNotInitialized() public {
        // Deploy a new access manager first
        ProtocolAccessManager accessManager = new ProtocolAccessManager(
            mockGovernor
        );

        // Deploy a new staking rewards manager without initializing the staking token
        MockStakingRewardsManager uninitializedManager = new MockStakingRewardsManager(
                address(accessManager), // use the properly initialized access manager
                address(0) // staking token - set to zero address to test uninitialized case
            );

        // Try to stake, which should revert because staking token is not initialized
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSignature("StakingTokenNotInitialized()")
        );
        uninitializedManager.stake(100);
    }
}
