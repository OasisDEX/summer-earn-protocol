// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IStakingRewardsManager} from "../../src/interfaces/IStakingRewardsManager.sol";
import {IStakingRewardsManagerErrors} from "../../src/errors/IStakingRewardsManagerErrors.sol";
import {MockSummerGovernor} from "../mocks/MockSummerGovernor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test, console} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";
import {DecayableStakingRewardsManager} from "../../src/contracts/DecayableStakingRewardsManager.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/src/VotingDecayLibrary.sol";

contract DecayableStakingRewardsManagerTest is Test {
    DecayableStakingRewardsManager public stakingRewardsManager;
    ERC20Mock public stakingToken;
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
        stakingToken = new ERC20Mock();
        for (uint i = 0; i < 3; i++) {
            rewardTokens.push(new ERC20Mock());
        }

        // Deploy mock governor with initial decay settings
        mockGovernor = new MockSummerGovernor(
            7 days,
            INITIAL_DECAY_RATE,
            VotingDecayLibrary.DecayFunction.Linear
        );

        mockGovernor.initializeAccount(alice);

        // Deploy DecayableStakingRewardsManager
        address[] memory rewardTokenAddresses = new address[](
            rewardTokens.length
        );
        for (uint i = 0; i < rewardTokens.length; i++) {
            rewardTokenAddresses[i] = address(rewardTokens[i]);
        }
        IProtocolAccessManager accessManager = new ProtocolAccessManager(
            address(mockGovernor)
        );
        stakingRewardsManager = new DecayableStakingRewardsManager(
            IStakingRewardsManager.StakingRewardsParams({
                rewardTokens: rewardTokenAddresses,
                accessManager: address(accessManager),
                governor: address(mockGovernor)
            }),
            address(mockGovernor)
        );

        vm.prank(address(mockGovernor));
        stakingRewardsManager.initialize(stakingToken);

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

    function test_DecayFactorInitialization() public {
        uint256 stakeAmount = 1000 * 1e18;

        // Alice stakes
        vm.prank(alice);
        stakingRewardsManager.stake(stakeAmount);

        // Check if the decay factor is initialized correctly
        uint256 decayFactor = mockGovernor.getDecayFactor(alice);
        assertEq(
            decayFactor,
            1e18,
            "Initial decay factor should be 1e18 (100%)"
        );
    }

    function test_DecayFactorUpdate() public {
        uint256 stakeAmount = 1000 * 1e18;

        // Alice stakes
        vm.prank(alice);
        stakingRewardsManager.stake(stakeAmount);

        // Fast forward time beyond decay-free window
        vm.warp(block.timestamp + 8 days);

        // Alice stakes again, triggering decay factor update
        vm.prank(alice);
        stakingRewardsManager.stake(stakeAmount);

        // Check updated decay factor
        uint256 decayFactor = mockGovernor.getDecayFactor(alice);
        assertLt(decayFactor, 1e18, "Decay factor should have decreased");
        assertGt(
            decayFactor,
            0.99e18,
            "Decay factor should be slightly less than 1e18"
        );
    }

    function test_EarnedWithDecay() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256 rewardAmount = 100 * 1e18;

        // Alice stakes
        vm.prank(alice);
        stakingRewardsManager.stake(stakeAmount);

        // Simulate decay factor update on mock governor
        MockSummerGovernor(address(stakingRewardsManager.governor()))
            .updateDecayFactor(alice);

        // Notify reward
        vm.prank(address(mockGovernor));
        stakingRewardsManager.notifyRewardAmount(
            IERC20(address(rewardTokens[0])),
            rewardAmount
        );

        // Fast forward time beyond decay-free window
        // 7 days is the decay-free window, 36 days is the decay period (where 1% decay is applied)
        vm.warp(block.timestamp + 7 days + 36 days);

        // Calculate earned amount
        uint256 earnedAmount = stakingRewardsManager.earned(
            alice,
            IERC20(address(rewardTokens[0]))
        );

        // Expected earned amount should be slightly less than the full reward due to decay
        uint256 expectedEarnedAmount = (rewardAmount * 0.99e18) / 1e18; // Approximate 1% decay

        assertApproxEqRel(
            earnedAmount,
            expectedEarnedAmount,
            0.01e18, // 1% tolerance
            "Earned amount should be adjusted by decay factor"
        );
    }

    function test_MultipleRewardTokensWithDecay() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256[] memory rewardAmounts = new uint256[](3);
        rewardAmounts[0] = 100 * 1e18;
        rewardAmounts[1] = 200 * 1e18;
        rewardAmounts[2] = 300 * 1e18;

        // Alice stakes
        vm.prank(alice);
        stakingRewardsManager.stake(stakeAmount);

        // Simulate decay factor update on mock governor
        MockSummerGovernor(address(stakingRewardsManager.governor()))
            .updateDecayFactor(alice);

        // Notify rewards for all three tokens
        vm.startPrank(address(mockGovernor));
        for (uint i = 0; i < rewardTokens.length; i++) {
            stakingRewardsManager.notifyRewardAmount(
                IERC20(address(rewardTokens[i])),
                rewardAmounts[i]
            );
        }
        vm.stopPrank();

        // Fast forward time beyond decay-free window
        // 7 days is the decay-free window, 36 days is the decay period (where 1% decay is applied)
        vm.warp(block.timestamp + 7 days + 36 days);

        // Check earned amounts
        for (uint i = 0; i < rewardTokens.length; i++) {
            uint256 earnedAmount = stakingRewardsManager.earned(
                alice,
                IERC20(address(rewardTokens[i]))
            );
            uint256 expectedEarnedAmount = (rewardAmounts[i] * 0.99e18) / 1e18; // Approximate 1% decay

            assertApproxEqRel(
                earnedAmount,
                expectedEarnedAmount,
                0.01e18, // 1% tolerance
                string(
                    abi.encodePacked(
                        "Earned amount should be adjusted by decay factor for token ",
                        i
                    )
                )
            );
        }
    }
}
