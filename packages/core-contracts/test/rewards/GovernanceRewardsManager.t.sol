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
}

// import {IStakingRewardsManagerBase} from "../../src/interfaces/IStakingRewardsManagerBase.sol";
// import {IStakingRewardsManagerBaseErrors} from "../../src/errors/IStakingRewardsManagerBaseErrors.sol";
// import {MockSummerGovernor} from "../mocks/MockSummerGovernor.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {Test, console} from "forge-std/Test.sol";
// import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
// import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
// import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";
// import {GovernanceRewardsManager} from "../../src/contracts/GovernanceRewardsManager.sol";

// contract GovernanceRewardsManagerTest is Test {
//     GovernanceRewardsManager public stakingRewardsManager;
//     ERC20Mock public stakingToken;
//     ERC20Mock[] public rewardTokens;
//     MockSummerGovernor public mockGovernor;

//     address public owner;
//     address public alice;
//     address public bob;

//     uint256 constant INITIAL_REWARD_AMOUNT = 1000000 * 1e18;
//     uint256 constant INITIAL_STAKE_AMOUNT = 100000 * 1e18;
//     // 0.1e18 per year is approximately 3.168808781402895e9 per second
//     // (0.1e18 / (365 * 24 * 60 * 60))
//     uint256 internal constant INITIAL_DECAY_RATE = 3.1709792e9; // ~10% per year

//     function setUp() public {
//         owner = address(this);
//         alice = address(0x1);
//         bob = address(0x2);

//         // Deploy mock tokens
//         stakingToken = new ERC20Mock();
//         for (uint i = 0; i < 3; i++) {
//             rewardTokens.push(new ERC20Mock());
//         }

//         // Deploy mock governor with initial decay settings
//         mockGovernor = new MockSummerGovernor(
//             7 days,
//             INITIAL_DECAY_RATE,
//             VotingDecayLibrary.DecayFunction.Linear
//         );

//         mockGovernor.initializeAccount(alice);

//         // Deploy DecayableStakingRewardsManager
//         address[] memory rewardTokenAddresses = new address[](
//             rewardTokens.length
//         );
//         for (uint i = 0; i < rewardTokens.length; i++) {
//             rewardTokenAddresses[i] = address(rewardTokens[i]);
//         }

//         IProtocolAccessManager accessManager = new ProtocolAccessManager(
//             address(mockGovernor)
//         );
//         stakingRewardsManager = new GovernanceRewardsManager(
//             address(accessManager),
//             address(mockGovernor),
//             address(stakingToken)
//         );

//         // Mint initial tokens
//         stakingToken.mint(alice, INITIAL_STAKE_AMOUNT);
//         stakingToken.mint(bob, INITIAL_STAKE_AMOUNT);
//         for (uint i = 0; i < rewardTokens.length; i++) {
//             rewardTokens[i].mint(
//                 address(stakingRewardsManager),
//                 INITIAL_REWARD_AMOUNT
//             );
//         }

//         // Approve staking
//         vm.prank(alice);
//         stakingToken.approve(address(stakingRewardsManager), type(uint256).max);
//         vm.prank(bob);
//         stakingToken.approve(address(stakingRewardsManager), type(uint256).max);
//     }

//     function test_DecayFactorInitialization() public {
//         uint256 stakeAmount = 1000 * 1e18;

//         // Alice stakes
//         vm.prank(address(stakingToken));
//         stakingRewardsManager.stakeFor(alice, stakeAmount);

//         // Check if the decay factor is initialized correctly
//         uint256 decayFactor = mockGovernor.getDecayFactor(alice);
//         assertEq(
//             decayFactor,
//             1e18,
//             "Initial decay factor should be 1e18 (100%)"
//         );
//     }

//     function test_DecayFactorUpdate() public {
//         uint256 stakeAmount = 1000 * 1e18;

//         // Alice stakes
//         vm.prank(address(stakingToken));
//         stakingRewardsManager.stakeFor(alice, stakeAmount);

//         // Fast forward time beyond decay-free window
//         vm.warp(block.timestamp + 8 days);

//         // Alice stakes again, triggering decay factor update
//         vm.prank(address(stakingToken));
//         stakingRewardsManager.stakeFor(alice, stakeAmount);

//         // Check updated decay factor
//         uint256 decayFactor = mockGovernor.getDecayFactor(alice);
//         assertLt(decayFactor, 1e18, "Decay factor should have decreased");
//         assertGt(
//             decayFactor,
//             0.99e18,
//             "Decay factor should be slightly less than 1e18"
//         );
//     }

//     function test_EarnedWithDecay() public {
//         uint256 stakeAmount = 1000 * 1e18;
//         uint256 rewardAmount = 100 * 1e18;

//         // Alice stakes
//         vm.prank(address(stakingToken));
//         stakingRewardsManager.stakeFor(alice, stakeAmount);

//         // Simulate decay factor update on mock governor
//         MockSummerGovernor(address(stakingRewardsManager.governor()))
//             .updateDecayFactor(alice);

//         // Notify reward
//         vm.prank(address(mockGovernor));
//         stakingRewardsManager.notifyRewardAmount(
//             IERC20(address(rewardTokens[0])),
//             rewardAmount,
//             7 days
//         );

//         // Fast forward time beyond decay-free window
//         // 7 days is the decay-free window, 36 days is the decay period (where 1% decay is applied)
//         vm.warp(block.timestamp + 7 days + 36 days);

//         // Calculate earned amount
//         uint256 earnedAmount = stakingRewardsManager.earned(
//             alice,
//             IERC20(address(rewardTokens[0]))
//         );

//         // Expected earned amount should be slightly less than the full reward due to decay
//         uint256 expectedEarnedAmount = (rewardAmount * 0.99e18) / 1e18; // Approximate 1% decay

//         assertApproxEqRel(
//             earnedAmount,
//             expectedEarnedAmount,
//             0.01e18, // 1% tolerance
//             "Earned amount should be adjusted by decay factor"
//         );
//     }

//     function test_MultipleRewardTokensWithDecay() public {
//         uint256 stakeAmount = 1000 * 1e18;
//         uint256[] memory rewardAmounts = new uint256[](3);
//         rewardAmounts[0] = 100 * 1e18;
//         rewardAmounts[1] = 200 * 1e18;
//         rewardAmounts[2] = 300 * 1e18;

//         // Alice stakes
//         vm.prank(address(stakingToken));
//         stakingRewardsManager.stakeFor(alice, stakeAmount);

//         // Simulate decay factor update on mock governor
//         MockSummerGovernor(address(stakingRewardsManager.governor()))
//             .updateDecayFactor(alice);

//         // Notify rewards for all three tokens
//         vm.startPrank(address(mockGovernor));
//         for (uint i = 0; i < rewardTokens.length; i++) {
//             stakingRewardsManager.notifyRewardAmount(
//                 IERC20(address(rewardTokens[i])),
//                 rewardAmounts[i],
//                 7 days
//             );
//         }
//         vm.stopPrank();

//         // Fast forward time beyond decay-free window
//         // 7 days is the decay-free window, 36 days is the decay period (where 1% decay is applied)
//         vm.warp(block.timestamp + 7 days + 36 days);

//         // Check earned amounts
//         for (uint i = 0; i < rewardTokens.length; i++) {
//             uint256 earnedAmount = stakingRewardsManager.earned(
//                 alice,
//                 IERC20(address(rewardTokens[i]))
//             );
//             uint256 expectedEarnedAmount = (rewardAmounts[i] * 0.99e18) / 1e18; // Approximate 1% decay

//             assertApproxEqRel(
//                 earnedAmount,
//                 expectedEarnedAmount,
//                 0.01e18, // 1% tolerance
//                 string(
//                     abi.encodePacked(
//                         "Earned amount should be adjusted by decay factor for token ",
//                         i
//                     )
//                 )
//             );
//         }
//     }
// }
