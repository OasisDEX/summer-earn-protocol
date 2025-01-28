// SPDX-License-Identifier: BUSL-1.1
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
import {ERC20, ERC20Wrapper} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {Constants} from "@summerfi/constants/Constants.sol";

contract ERC20MockWithoutDecimals is ERC20Mock {
    constructor() ERC20Mock() {}

    function decimals() public pure override returns (uint8) {
        revert("decimals() not implemented");
    }
}

contract MockWrappedToken is ERC20Wrapper {
    constructor(
        IERC20 _underlying
    ) ERC20("Wrapped Mock Token", "wMTK") ERC20Wrapper(_underlying) {}
}

contract StakingRewardsManagerBaseTest is Test {
    MockStakingRewardsManager public stakingRewardsManager;
    ERC20Mock[] public rewardTokens;
    address public mockGovernor;

    address public owner;
    address public alice;
    address public bob;
    ERC20Mock public mockStakingToken;
    ERC20Mock public rewardTokenWithDecimals;
    ERC20MockWithoutDecimals public rewardTokenWithoutDecimals;

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
        rewardTokenWithDecimals = new ERC20Mock();
        rewardTokenWithoutDecimals = new ERC20MockWithoutDecimals();
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
            rewardTokens[i].mint(mockGovernor, INITIAL_REWARD_AMOUNT);
        }
        rewardTokenWithDecimals.mint(mockGovernor, 1000 * 1e18);
        rewardTokenWithoutDecimals.mint(mockGovernor, 1000 * 1e18);

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
        IERC20 rewardToken = rewardTokens[0];
        uint256 rewardAmount = 100000000000000000000; // 100 tokens
        uint256 newDuration = 14 days;

        vm.startPrank(mockGovernor);
        rewardToken.approve(address(stakingRewardsManager), rewardAmount);
        stakingRewardsManager.notifyRewardAmount(
            address(rewardToken),
            rewardAmount,
            newDuration
        );
        vm.stopPrank();

        (
            uint256 periodFinish,
            uint256 rewardRate,
            uint256 duration,
            ,

        ) = stakingRewardsManager.rewardData(address(rewardToken));

        assertEq(
            periodFinish,
            block.timestamp + duration,
            "Period finish should be current time plus duration"
        );
        assertEq(
            rewardRate,
            ((rewardAmount * Constants.WAD) / duration),
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

        // Mint reward tokens to the governor instead of staking manager
        newRewardToken.mint(mockGovernor, rewardAmount);

        vm.startPrank(mockGovernor);
        newRewardToken.approve(address(stakingRewardsManager), rewardAmount);
        stakingRewardsManager.notifyRewardAmount(
            address(newRewardToken),
            rewardAmount,
            newDuration
        );
        vm.stopPrank();

        // Get the reward data
        (
            uint256 periodFinish,
            uint256 rewardRate,
            uint256 rewardsDuration,
            uint256 lastUpdateTime,
            uint256 rewardPerTokenStored
        ) = stakingRewardsManager.rewardData(address(newRewardToken));

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
            ((rewardAmount * Constants.WAD) / newDuration),
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
        vm.startPrank(mockGovernor);
        rewardToken.approve(
            address(stakingRewardsManager),
            initialRewardAmount
        );
        stakingRewardsManager.notifyRewardAmount(
            address(rewardToken),
            initialRewardAmount,
            initialDuration
        );
        vm.stopPrank();

        // Try to change the duration for an existing token
        uint256 newRewardAmount = 200 * 1e18;
        uint256 newDuration = 14 days; // Different duration

        vm.startPrank(mockGovernor);
        rewardToken.approve(address(stakingRewardsManager), newRewardAmount);

        // This should revert with CannotChangeRewardsDuration
        vm.expectRevert(
            abi.encodeWithSignature("CannotChangeRewardsDuration()")
        );
        stakingRewardsManager.notifyRewardAmount(
            address(rewardToken),
            newRewardAmount,
            newDuration
        );
        vm.stopPrank();

        // Verify that the original duration is still in place
        (, , uint256 duration, , ) = stakingRewardsManager.rewardData(
            address(rewardToken)
        );
        assertEq(duration, initialDuration, "Duration should not have changed");
    }

    function test_SetRewardsDuration() public {
        IERC20 rewardToken1 = rewardTokens[1];

        // First, check if the reward token is already added
        (, , uint256 rewardsDuration, , ) = stakingRewardsManager.rewardData(
            address(rewardToken1)
        );

        if (rewardsDuration == 0) {
            // Only add the reward token if it hasn't been added yet
            vm.startPrank(mockGovernor);
            rewardToken1.approve(address(stakingRewardsManager), 604800);
            stakingRewardsManager.notifyRewardAmount(
                address(rewardToken1),
                604800,
                7 days
            );
            vm.stopPrank();
        }

        vm.warp(block.timestamp + 8 days);

        vm.prank(mockGovernor);
        stakingRewardsManager.setRewardsDuration(
            address(rewardToken1),
            1209600
        );

        // Assert the new rewards duration
        (, , uint256 newRewardsDuration, , ) = stakingRewardsManager.rewardData(
            address(rewardToken1)
        );
        assertEq(newRewardsDuration, 1209600);
    }

    function test_SetRewardsDuration_NonExistingToken() public {
        vm.expectRevert(abi.encodeWithSignature("RewardTokenDoesNotExist()"));
        vm.prank(mockGovernor);
        stakingRewardsManager.setRewardsDuration(address(0x789), 1209600);
    }

    function test_Stake() public {
        uint256 stakeAmount = 1000 * 1e18;

        // Expect the Staked event with correct parameters
        vm.expectEmit(true, true, false, true);
        emit IStakingRewardsManagerBase.Staked(alice, alice, stakeAmount);

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

        // Expect the Unstaked event with correct parameters
        vm.expectEmit(true, true, false, true);
        emit IStakingRewardsManagerBase.Unstaked(alice, alice, stakeAmount);

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

    function test_StakeOnBehalfOf() public {
        uint256 stakeAmount = 1000 * 1e18;

        // First approve the tokens
        vm.startPrank(alice);
        mockStakingToken.approve(address(stakingRewardsManager), stakeAmount);

        // Expect the Staked event with correct parameters
        vm.expectEmit(true, true, false, true, address(stakingRewardsManager));
        emit IStakingRewardsManagerBase.Staked(alice, bob, stakeAmount);

        // Then call stakeOnBehalfOf
        stakingRewardsManager.stakeOnBehalfOf(bob, stakeAmount);
        vm.stopPrank();

        assertEq(
            stakingRewardsManager.balanceOf(bob),
            stakeAmount,
            "Stake amount should be correct for receiver"
        );
        assertEq(
            stakingRewardsManager.balanceOf(alice),
            0,
            "Staker should have no balance"
        );
        assertEq(
            stakingRewardsManager.totalSupply(),
            stakeAmount,
            "Total supply should be updated"
        );
    }

    function test_GetReward() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256 rewardAmount = 100 * 1e18;

        vm.prank(alice);
        stakingRewardsManager.stake(stakeAmount);

        vm.startPrank(mockGovernor);
        rewardTokens[0].approve(address(stakingRewardsManager), rewardAmount);
        stakingRewardsManager.notifyRewardAmount(
            address(rewardTokens[0]),
            rewardAmount,
            7 days
        );
        vm.stopPrank();
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

    function test_GetReward_SpecificToken() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256 rewardAmount = 100 * 1e18;

        vm.prank(alice);
        stakingRewardsManager.stake(stakeAmount);

        vm.startPrank(mockGovernor);
        rewardTokens[0].approve(address(stakingRewardsManager), rewardAmount);
        stakingRewardsManager.notifyRewardAmount(
            address(rewardTokens[0]),
            rewardAmount,
            7 days
        );
        vm.stopPrank();
        // Fast forward time
        vm.warp(block.timestamp + 7 days);

        uint256 balanceBefore = rewardTokens[0].balanceOf(alice);

        vm.prank(alice);
        stakingRewardsManager.getReward(address(rewardTokens[0]));

        uint256 balanceAfter = rewardTokens[0].balanceOf(alice);
        assertGt(
            balanceAfter,
            balanceBefore,
            "Alice should have received rewards"
        );
    }

    function test_GetReward_SpecificToken_NonExistingToken() public {
        vm.expectRevert(abi.encodeWithSignature("RewardTokenDoesNotExist()"));
        vm.prank(alice);
        stakingRewardsManager.getReward(address(0x789));
    }

    function test_Exit() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256 rewardAmount = 100 * 1e18;

        vm.prank(alice);
        stakingRewardsManager.stake(stakeAmount);

        vm.startPrank(mockGovernor);
        rewardTokens[0].approve(address(stakingRewardsManager), rewardAmount);
        stakingRewardsManager.notifyRewardAmount(
            address(rewardTokens[0]),
            rewardAmount,
            7 days
        );
        vm.stopPrank();

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
            rewardTokens[i].approve(
                address(stakingRewardsManager),
                rewardAmounts[i]
            );
            stakingRewardsManager.notifyRewardAmount(
                address(rewardTokens[i]),
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
                address(rewardTokens[i])
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
                address(rewardTokens[i])
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

        vm.startPrank(mockGovernor);
        rewardTokens[0].approve(address(stakingRewardsManager), rewardAmount);
        stakingRewardsManager.notifyRewardAmount(
            address(rewardTokens[0]),
            rewardAmount,
            7 days
        );
        vm.stopPrank();
        // Fast forward time to accumulate some rewards
        vm.warp(block.timestamp + 1 days);

        // Get initial reward data
        (
            ,
            ,
            ,
            uint256 lastUpdateTimeBefore,
            uint256 rewardPerTokenStoredBefore
        ) = stakingRewardsManager.rewardData(address(rewardTokens[0]));

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
        ) = stakingRewardsManager.rewardData(address(rewardTokens[0]));

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
            address(rewardTokens[0]),
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

        vm.startPrank(mockGovernor);
        rewardTokens[0].approve(address(stakingRewardsManager), rewardAmount);
        stakingRewardsManager.notifyRewardAmount(
            address(rewardTokens[0]),
            rewardAmount,
            7 days
        );
        vm.stopPrank();

        // Fast forward time to accumulate some rewards
        vm.warp(block.timestamp + 1 days);

        // Get initial reward data
        (
            uint256 periodFinish,
            uint256 rewardRate,
            ,
            uint256 lastUpdateTimeBefore,
            uint256 rewardPerTokenStoredBefore
        ) = stakingRewardsManager.rewardData(address(rewardTokens[0]));

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
        ) = stakingRewardsManager.rewardData(address(rewardTokens[0]));

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
            address(rewardTokens[0]),
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
            rewardTokens[i].approve(
                address(stakingRewardsManager),
                rewardAmount
            );
            stakingRewardsManager.notifyRewardAmount(
                address(rewardTokens[i]),
                rewardAmount,
                duration
            );
        }
        vm.stopPrank();

        // Test valid index
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address token = stakingRewardsManager.rewardTokens(i);
            assertEq(
                token,
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

        vm.startPrank(mockGovernor);
        rewardToken.approve(address(stakingRewardsManager), rewardAmount);
        stakingRewardsManager.notifyRewardAmount(
            address(rewardToken),
            rewardAmount,
            duration
        );
        vm.stopPrank();
        uint256 rewardForDuration = stakingRewardsManager.getRewardForDuration(
            address(rewardToken)
        );

        assertApproxEqRel(
            rewardForDuration,
            rewardAmount,
            0.0001e16,
            "Total reward for duration should approximately equal notified amount"
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
        stakingRewardsManager.removeRewardToken(address(nonExistentToken));

        // Setup initial state with a reward token
        vm.startPrank(mockGovernor);
        rewardToken.approve(address(stakingRewardsManager), rewardAmount);
        stakingRewardsManager.notifyRewardAmount(
            address(rewardToken),
            rewardAmount,
            duration
        );
        vm.stopPrank();

        // Test 2: Cannot remove token while period is active
        vm.prank(mockGovernor);
        vm.expectRevert(abi.encodeWithSignature("RewardPeriodNotComplete()"));
        stakingRewardsManager.removeRewardToken(address(rewardToken));

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
        stakingRewardsManager.removeRewardToken(address(rewardToken));

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
        stakingRewardsManager.removeRewardToken(address(rewardToken));

        // Verify token was removed
        vm.prank(mockGovernor);
        vm.expectRevert(abi.encodeWithSignature("RewardTokenDoesNotExist()"));
        stakingRewardsManager.removeRewardToken(address(rewardToken));
    }

    function test_RemoveRewardToken_RewardTokenNotInitialized() public {
        vm.expectRevert(abi.encodeWithSignature("RewardTokenDoesNotExist()"));
        vm.prank(mockGovernor);
        stakingRewardsManager.removeRewardToken(address(0));
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

    function test_RemoveRewardToken_WithDecimals() public {
        // Notify reward amount
        vm.startPrank(mockGovernor);
        rewardTokenWithDecimals.approve(
            address(stakingRewardsManager),
            1000 * 1e18
        );
        stakingRewardsManager.notifyRewardAmount(
            address(rewardTokenWithDecimals),
            1000 * 1e18,
            7 days
        );
        vm.stopPrank();

        // Fast forward past reward period
        vm.warp(block.timestamp + 8 days);

        // Simulate claiming rewards, leaving only dust (0.00001 tokens)
        vm.startPrank(address(stakingRewardsManager));
        uint256 balance = rewardTokenWithDecimals.balanceOf(
            address(stakingRewardsManager)
        );
        rewardTokenWithDecimals.transfer(address(1), balance - 1e13); // Leave 0.00001 tokens as dust
        vm.stopPrank();

        // Should succeed with dust amount
        vm.prank(mockGovernor);
        stakingRewardsManager.removeRewardToken(
            address(rewardTokenWithDecimals)
        );
    }

    function test_RemoveRewardToken_WithoutDecimals() public {
        // Notify reward amount
        vm.startPrank(mockGovernor);
        rewardTokenWithoutDecimals.approve(
            address(stakingRewardsManager),
            1000 * 1e18
        );
        stakingRewardsManager.notifyRewardAmount(
            address(rewardTokenWithoutDecimals),
            1000 * 1e18,
            7 days
        );
        vm.stopPrank();

        // Fast forward past reward period
        vm.warp(block.timestamp + 8 days);

        // Simulate claiming rewards, leaving only dust (0.000001 tokens)
        vm.startPrank(address(stakingRewardsManager));
        uint256 balance = rewardTokenWithoutDecimals.balanceOf(
            address(stakingRewardsManager)
        );
        rewardTokenWithoutDecimals.transfer(address(1), balance - 1e12); // Leave 0.000001 tokens as dust
        vm.stopPrank();

        // Should succeed with dust amount
        vm.prank(mockGovernor);
        stakingRewardsManager.removeRewardToken(
            address(rewardTokenWithoutDecimals)
        );
    }

    function test_NotifyRewardAmount_WithWrappedStakingToken() public {
        // Deploy a wrapped version of the staking token
        MockWrappedToken wrappedStakingToken = new MockWrappedToken(
            IERC20(address(mockStakingToken))
        );

        // Setup initial state - mint wrapped tokens to governor
        uint256 rewardAmount = 100 * 1e18;
        mockStakingToken.mint(mockGovernor, rewardAmount);

        vm.startPrank(mockGovernor);
        // Approve underlying token to wrapped token
        mockStakingToken.approve(address(wrappedStakingToken), rewardAmount);
        // Deposit underlying for wrapped tokens
        wrappedStakingToken.depositFor(mockGovernor, rewardAmount);
        // Approve wrapped tokens to staking manager
        wrappedStakingToken.approve(
            address(stakingRewardsManager),
            rewardAmount
        );
        // Notify reward amount (this will transfer the tokens)
        stakingRewardsManager.notifyRewardAmount(
            address(wrappedStakingToken),
            rewardAmount,
            7 days
        );
        vm.stopPrank();

        // Verify reward token was added
        (uint256 periodFinish, uint256 rewardRate, , , ) = stakingRewardsManager
            .rewardData(address(wrappedStakingToken));

        assertTrue(rewardRate > 0, "Reward rate should be set");
        assertGt(
            periodFinish,
            block.timestamp,
            "Period finish should be in the future"
        );
    }

    function test_GetReward_WithWrappedNonStakingToken() public {
        // Create and setup wrapped token
        ERC20Mock underlyingToken = new ERC20Mock();
        MockWrappedToken wrappedToken = new MockWrappedToken(underlyingToken);

        // Mint tokens to user for staking
        mockStakingToken.mint(alice, 1000 * 1e18);

        // Setup staking
        vm.prank(alice);
        mockStakingToken.approve(address(stakingRewardsManager), 1000 * 1e18);
        vm.prank(alice);
        stakingRewardsManager.stake(1000 * 1e18);

        // Mint underlying tokens to governor
        underlyingToken.mint(mockGovernor, 100 * 1e18);

        vm.startPrank(mockGovernor);
        // Approve underlying token to wrapped token
        underlyingToken.approve(address(wrappedToken), 100 * 1e18);
        // Deposit underlying for wrapped tokens
        wrappedToken.depositFor(mockGovernor, 100 * 1e18);
        // Approve wrapped tokens to staking manager for notifyRewardAmount
        wrappedToken.approve(address(stakingRewardsManager), 100 * 1e18);
        // Notify reward amount (this will transfer the tokens)
        stakingRewardsManager.notifyRewardAmount(
            address(wrappedToken),
            100 * 1e18,
            7 days
        );
        vm.stopPrank();

        // Advance time
        vm.warp(block.timestamp + 7 days);

        // Get reward
        vm.prank(alice);
        stakingRewardsManager.getReward();

        // Verify rewards were distributed, allowing for small rounding differences
        assertApproxEqAbs(
            wrappedToken.balanceOf(alice),
            100 * 1e18,
            1000, // Allow difference of up to 1000 wei
            "User should have received wrapped tokens"
        );
    }

    function test_GetRewardFor() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256 rewardAmount = 100 * 1e18;

        // Setup: Alice stakes tokens
        vm.prank(alice);
        stakingRewardsManager.stake(stakeAmount);

        // Setup: Add rewards
        vm.startPrank(mockGovernor);
        rewardTokens[0].approve(address(stakingRewardsManager), rewardAmount);
        stakingRewardsManager.notifyRewardAmount(
            address(rewardTokens[0]),
            rewardAmount,
            7 days
        );
        vm.stopPrank();

        // Fast forward time
        vm.warp(block.timestamp + 7 days);

        uint256 balanceBefore = rewardTokens[0].balanceOf(alice);

        // Bob claims rewards on behalf of Alice
        vm.prank(bob);
        stakingRewardsManager.getRewardFor(alice);

        uint256 balanceAfter = rewardTokens[0].balanceOf(alice);
        assertGt(
            balanceAfter,
            balanceBefore,
            "Alice should have received rewards"
        );
    }

    function test_GetRewardFor_SpecificToken() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256 rewardAmount = 100 * 1e18;

        // Setup: Alice stakes tokens
        vm.prank(alice);
        stakingRewardsManager.stake(stakeAmount);

        // Setup: Add multiple reward tokens
        vm.startPrank(mockGovernor);
        for (uint256 i = 0; i < 2; i++) {
            rewardTokens[i].approve(
                address(stakingRewardsManager),
                rewardAmount
            );
            stakingRewardsManager.notifyRewardAmount(
                address(rewardTokens[i]),
                rewardAmount,
                7 days
            );
        }
        vm.stopPrank();

        // Fast forward time
        vm.warp(block.timestamp + 7 days);

        uint256 balanceBefore = rewardTokens[0].balanceOf(alice);
        uint256 otherTokenBefore = rewardTokens[1].balanceOf(alice);

        // Bob claims specific reward token for Alice
        vm.prank(bob);
        stakingRewardsManager.getRewardFor(alice, address(rewardTokens[0]));

        uint256 balanceAfter = rewardTokens[0].balanceOf(alice);
        uint256 otherTokenAfter = rewardTokens[1].balanceOf(alice);

        assertGt(
            balanceAfter,
            balanceBefore,
            "Alice should have received rewards for the specific token"
        );
        assertEq(
            otherTokenAfter,
            otherTokenBefore,
            "Alice should not have received rewards for other token"
        );
    }

    function test_GetRewardFor_InvalidToken() public {
        vm.expectRevert(abi.encodeWithSignature("RewardTokenDoesNotExist()"));
        stakingRewardsManager.getRewardFor(alice, address(0x123));
    }

    function test_RewardTokenRemovalAndReaddition() public {
        console.log("----------------------------------------");
        console.log("Setting up initial variables");
        uint256 stakeAmount = 1000 * 1e18;
        uint256 rewardAmount = 100 * 1e18;
        IERC20 rewardToken = rewardTokens[0];

        console.log("----------------------------------------");
        console.log("First reward period setup - notifying reward amount");
        vm.startPrank(mockGovernor);
        rewardToken.approve(address(stakingRewardsManager), rewardAmount);
        stakingRewardsManager.notifyRewardAmount(
            address(rewardToken),
            rewardAmount,
            7 days
        );
        vm.stopPrank();

        console.log("----------------------------------------");
        console.log("User staking tokens");
        vm.prank(alice);
        stakingRewardsManager.stake(stakeAmount);

        console.log("----------------------------------------");
        console.log("Waiting 10 minutes and getting initial rewards");
        vm.warp(block.timestamp + 10 minutes);

        uint256 balanceBefore = rewardToken.balanceOf(alice);
        vm.prank(alice);
        stakingRewardsManager.getReward();
        uint256 firstRewardAmount = rewardToken.balanceOf(alice) -
            balanceBefore;
        console.log("First reward amount:", firstRewardAmount);

        assertGt(firstRewardAmount, 0, "Should have received first reward");

        console.log("----------------------------------------");
        console.log("Fast forwarding past reward period");
        vm.warp(block.timestamp + 7 days);

        console.log("----------------------------------------");
        console.log(
            "Simulating all rewards claimed by transferring out remaining balance"
        );
        vm.startPrank(address(stakingRewardsManager));
        uint256 remainingBalance = rewardToken.balanceOf(
            address(stakingRewardsManager)
        );
        console.log("Remaining balance to transfer:", remainingBalance);
        rewardToken.transfer(address(1), remainingBalance);
        vm.stopPrank();

        console.log("----------------------------------------");
        console.log("Removing reward token");
        vm.prank(mockGovernor);
        stakingRewardsManager.removeRewardToken(address(rewardToken));

        console.log("----------------------------------------");
        console.log("Adding same reward token again with new rewards");
        vm.startPrank(mockGovernor);
        rewardToken.approve(address(stakingRewardsManager), rewardAmount);
        stakingRewardsManager.notifyRewardAmount(
            address(rewardToken),
            rewardAmount,
            7 days
        );
        vm.stopPrank();

        console.log("----------------------------------------");
        console.log("Waiting 5 minutes and getting rewards again");
        vm.warp(block.timestamp + 5 minutes);

        balanceBefore = rewardToken.balanceOf(alice);
        vm.prank(alice);
        stakingRewardsManager.getReward();
        uint256 secondRewardAmount = rewardToken.balanceOf(alice) -
            balanceBefore;
        console.log("Second reward amount:", secondRewardAmount);

        assertGt(secondRewardAmount, 0, "Should have received second reward");

        console.log("----------------------------------------");
        console.log("Verifying reward proportions");
        console.log("First reward (10 min period):", firstRewardAmount);
        console.log("Second reward (5 min period):", secondRewardAmount);
        console.log("Second reward * 2:", secondRewardAmount * 2);

        assertApproxEqRel(
            secondRewardAmount * 2,
            firstRewardAmount,
            0.01e18, // 1% tolerance
            "Second reward should be approximately half of first reward due to time difference"
        );
        console.log("----------------------------------------");
        console.log("Test completed successfully");
    }

    function test_BuggedRemoveRewardToken_UnderflowError() public {
        console.log("----------------------------------------");
        console.log("Setting up initial variables");
        uint256 stakeAmount = 1000 * 1e18;
        uint256 rewardAmount = 100 * 1e18;
        IERC20 rewardToken = rewardTokens[0];

        console.log("----------------------------------------");
        console.log("First reward period setup - notifying reward amount");
        vm.startPrank(mockGovernor);
        rewardToken.approve(address(stakingRewardsManager), rewardAmount);
        stakingRewardsManager.notifyRewardAmount(
            address(rewardToken),
            rewardAmount,
            7 days
        );
        vm.stopPrank();

        console.log("----------------------------------------");
        console.log("User staking tokens");
        vm.prank(alice);
        stakingRewardsManager.stake(stakeAmount);

        console.log("----------------------------------------");
        console.log("Waiting 10 minutes and getting initial rewards");
        vm.warp(block.timestamp + 10 minutes);

        uint256 balanceBefore = rewardToken.balanceOf(alice);
        vm.prank(alice);
        stakingRewardsManager.getReward();
        uint256 firstRewardAmount = rewardToken.balanceOf(alice) -
            balanceBefore;
        console.log("First reward amount:", firstRewardAmount);

        assertGt(firstRewardAmount, 0, "Should have received first reward");

        console.log("----------------------------------------");
        console.log("Fast forwarding past reward period");
        vm.warp(block.timestamp + 7 days);

        console.log("----------------------------------------");
        console.log(
            "Simulating all rewards claimed by transferring out remaining balance"
        );
        vm.startPrank(address(stakingRewardsManager));
        uint256 remainingBalance = rewardToken.balanceOf(
            address(stakingRewardsManager)
        );
        console.log("Remaining balance to transfer:", remainingBalance);
        rewardToken.transfer(address(1), remainingBalance);
        vm.stopPrank();

        console.log("----------------------------------------");
        console.log("Removing reward token");
        vm.prank(mockGovernor);
        stakingRewardsManager.buggedRemoveRewardToken(address(rewardToken));

        console.log("----------------------------------------");
        console.log("Adding same reward token again with new rewards");
        vm.startPrank(mockGovernor);
        rewardToken.approve(address(stakingRewardsManager), rewardAmount);
        stakingRewardsManager.notifyRewardAmount(
            address(rewardToken),
            rewardAmount,
            7 days
        );
        vm.stopPrank();

        console.log("----------------------------------------");
        console.log("Waiting 5 minutes and getting rewards again");
        vm.warp(block.timestamp + 5 minutes);

        balanceBefore = rewardToken.balanceOf(alice);
        vm.prank(alice);
        vm.expectRevert();
        stakingRewardsManager.getReward();
    }
}
