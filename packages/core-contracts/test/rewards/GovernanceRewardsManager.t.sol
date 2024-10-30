// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IStakingRewardsManagerBase} from "../../src/interfaces/IStakingRewardsManagerBase.sol";
import {IStakingRewardsManagerBaseErrors} from "../../src/errors/IStakingRewardsManagerBaseErrors.sol";
import {MockSummerGovernor} from "../mocks/MockSummerGovernor.sol";
import {MockSummerToken} from "../mocks/MockSummerToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test, console} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";
import {GovernanceRewardsManager} from "../../src/contracts/GovernanceRewardsManager.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/src/VotingDecayLibrary.sol";
import {IGovernanceRewardsManagerErrors} from "@summerfi/protocol-interfaces/IGovernanceRewardsManagerErrors.sol";
import {IGovernanceRewardsManager} from "@summerfi/protocol-interfaces/IGovernanceRewardsManager.sol";
import {IStakingRewardsManagerBaseErrors} from "../../src/errors/IStakingRewardsManagerBaseErrors.sol";

contract GovernanceRewardsManagerTest is Test {
    GovernanceRewardsManager public stakingRewardsManager;
    MockSummerToken public stakingToken;
    ERC20Mock[] public rewardTokens;
    MockSummerGovernor public mockGovernor;

    address public owner;
    address public alice;
    address public bob;

    uint256 constant INITIAL_REWARD_AMOUNT = 1000000 * 1e18;
    uint256 constant INITIAL_STAKE_AMOUNT = 100000 * 1e18;

    // 0.1e18 per year is approximately 3.168808781402895e9 per second
    // (0.1e18 / (365 * 24 * 60 * 60))
    uint256 internal constant INITIAL_DECAY_RATE = 3.1709792e9; // ~10% per year

    function setUp() public {
        owner = address(this);
        alice = address(0x1);
        bob = address(0x2);

        // Deploy mock tokens
        stakingToken = new MockSummerToken("Summer Token", "SUMMER");
        for (uint i = 0; i < 3; i++) {
            rewardTokens.push(new ERC20Mock());
        }

        // Deploy mock governor
        mockGovernor = new MockSummerGovernor(
            7 days,
            INITIAL_DECAY_RATE,
            VotingDecayLibrary.DecayFunction.Linear
        );

        // Deploy GovernanceRewardsManager
        address[] memory rewardTokenAddresses = new address[](
            rewardTokens.length
        );
        for (uint i = 0; i < rewardTokens.length; i++) {
            rewardTokenAddresses[i] = address(rewardTokens[i]);
        }

        IProtocolAccessManager accessManager = new ProtocolAccessManager(
            address(mockGovernor)
        );
        stakingRewardsManager = new GovernanceRewardsManager(
            address(accessManager)
        );

        // Initialize staking rewards manager
        stakingRewardsManager.initialize(IERC20(address(stakingToken)));

        // Mint initial tokens
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

    function test_StakeForOnlyCallableByStakingToken() public {
        uint256 stakeAmount = 1000 * 1e18;

        // Initialize decay factor
        vm.prank(address(stakingToken));
        mockGovernor.updateDecayFactor(alice);

        vm.prank(alice);
        vm.expectRevert(IGovernanceRewardsManagerErrors.InvalidCaller.selector);
        stakingRewardsManager.stakeFor(alice, stakeAmount);

        vm.prank(address(stakingToken));
        stakingRewardsManager.stakeFor(alice, stakeAmount);

        assertEq(
            stakingRewardsManager.balanceOf(alice),
            stakeAmount,
            "Stake amount should be correct"
        );
    }

    function test_StakeForUpdatesBalancesCorrectly() public {
        uint256 stakeAmount = 1000 * 1e18;

        // Initialize decay factor
        vm.prank(address(stakingToken));
        mockGovernor.updateDecayFactor(alice);

        vm.prank(address(stakingToken));
        stakingRewardsManager.stakeFor(alice, stakeAmount);

        assertEq(
            stakingRewardsManager.balanceOf(alice),
            stakeAmount,
            "Staked balance should be updated"
        );
    }

    function test_UnstakeDirectly() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256 unstakeAmount = 500 * 1e18;

        // Initialize decay factor
        vm.prank(address(stakingToken));
        mockGovernor.updateDecayFactor(alice);

        vm.prank(address(stakingToken));
        stakingRewardsManager.stakeFor(alice, stakeAmount);

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

        // Initialize decay factor
        vm.prank(address(stakingToken));
        mockGovernor.updateDecayFactor(alice);

        vm.prank(address(stakingToken));
        stakingRewardsManager.stakeFor(alice, stakeAmount);

        uint256 initialBalance = stakingToken.balanceOf(alice);

        vm.prank(alice);
        stakingRewardsManager.unstake(unstakeAmount);

        assertEq(
            stakingToken.balanceOf(alice),
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

        // Initialize decay factor
        vm.prank(address(stakingToken));
        mockGovernor.updateDecayFactor(alice);

        // Alice stakes
        vm.prank(address(stakingToken));
        stakingRewardsManager.stakeFor(alice, stakeAmount);

        // Notify reward
        vm.prank(address(mockGovernor));
        stakingRewardsManager.notifyRewardAmount(
            IERC20(address(rewardTokens[0])),
            rewardAmount,
            7 days
        );

        // Fast forward time
        vm.warp(block.timestamp + 3 days);

        // Calculate earned amount before unstake
        uint256 earnedBeforeUnstake = stakingRewardsManager.earned(
            alice,
            IERC20(address(rewardTokens[0]))
        );

        // Alice unstakes half
        vm.prank(alice);
        stakingRewardsManager.unstake(stakeAmount / 2);

        // Fast forward time again
        vm.warp(block.timestamp + 4 days);

        // Calculate final earned amount
        uint256 earnedAfterUnstake = stakingRewardsManager.earned(
            alice,
            IERC20(address(rewardTokens[0]))
        );

        // The earned amount after unstake should be more than before, but less than if Alice hadn't unstaked
        assertGt(
            earnedAfterUnstake,
            earnedBeforeUnstake,
            "Earned amount should increase over time"
        );
        assertLt(
            earnedAfterUnstake,
            rewardAmount,
            "Earned amount should be less than total reward due to unstake"
        );
    }

    function test_StakeForFailsWhenStakingTokenNotInitialized() public {
        uint256 stakeAmount = 1000 * 1e18;

        // Deploy a new uninitialized manager
        IProtocolAccessManager accessManager = new ProtocolAccessManager(
            address(mockGovernor)
        );
        GovernanceRewardsManager uninitializedManager = new GovernanceRewardsManager(
                address(accessManager)
            );

        // Try to stake before initialization
        vm.prank(address(stakingToken));
        vm.expectRevert(
            IStakingRewardsManagerBaseErrors.StakingTokenNotInitialized.selector
        );
        uninitializedManager.stakeFor(alice, stakeAmount);
    }

    function test_InitializeFailsWhenStakingTokenAlreadyInitialized() public {
        // Try to initialize again (note: stakingToken is already initialized in setUp())
        vm.expectRevert(
            IGovernanceRewardsManagerErrors
                .StakingTokenAlreadyInitialized
                .selector
        );
        stakingRewardsManager.initialize(IERC20(address(stakingToken)));
    }
    function test_DirectStakingNotAllowed() public {
        uint256 stakeAmount = 1000 * 1e18;

        vm.prank(alice);
        vm.expectRevert(
            IGovernanceRewardsManagerErrors.DirectStakingNotAllowed.selector
        );
        stakingRewardsManager.stake(stakeAmount);
    }

    function test_CannotInitializeStakingTokenTwice() public {
        // Create a new mock token to attempt re-initialization
        ERC20Mock newStakingToken = new ERC20Mock();

        // Attempt to initialize with a new staking token
        vm.prank(address(mockGovernor));
        vm.expectRevert(
            abi.encodeWithSignature("StakingTokenAlreadyInitialized()")
        );
        stakingRewardsManager.initialize(IERC20(address(newStakingToken)));
    }

    function test_OnlyStakingTokenModifierRequiresInitialization() public {
        // Deploy a new GovernanceRewardsManager without initialization
        IProtocolAccessManager accessManager = new ProtocolAccessManager(
            address(mockGovernor)
        );
        GovernanceRewardsManager newStakingRewardsManager = new GovernanceRewardsManager(
                address(accessManager)
            );

        // Try to call stakeFor() which uses the onlyStakingToken modifier
        vm.prank(address(stakingToken));
        vm.expectRevert(
            IStakingRewardsManagerBaseErrors.StakingTokenNotInitialized.selector
        );
        newStakingRewardsManager.stakeFor(alice, 100);
    }
}
