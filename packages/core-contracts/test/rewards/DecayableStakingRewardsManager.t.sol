// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IStakingRewardsManager} from "../../src/interfaces/IStakingRewardsManager.sol";
import {IStakingRewardsManagerErrors} from "../../src/errors/IStakingRewardsManagerErrors.sol";
import {MockSummerGovernor} from "../mocks/MockSummerGovernor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test, console} from "forge-std/Test.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";
import {DecayableStakingRewardsManager} from "../../src/contracts/DecayableStakingRewardsManager.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/src/VotingDecayLibrary.sol";

contract DecayableStakingRewardsManagerTest is Test {
    DecayableStakingRewardsManager public stakingRewardsManager;
    MockERC20 public stakingToken;
    MockERC20[] public rewardTokens;
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
        stakingToken = new MockERC20("Staking Token", "STK", 18);
        for (uint i = 0; i < 3; i++) {
            rewardTokens.push(
                new MockERC20(
                    string(abi.encodePacked("Reward Token ", i)),
                    string(abi.encodePacked("RT", i)),
                    18
                )
            );
        }

        // Deploy mock governor with initial decay settings
        mockGovernor = new MockSummerGovernor(
            7 days, // initialDecayFreeWindow
            1e16, // initialDecayRate (1% per day)
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
                rewardsTokens: rewardTokenAddresses,
                accessManager: address(accessManager),
                governor: address(mockGovernor)
            }),
            address(mockGovernor)
        );

        vm.prank(address(mockGovernor));
        stakingRewardsManager.initializeStakingToken(stakingToken);

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
        stakingRewardsManager.stake(alice, stakeAmount);

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
        stakingRewardsManager.stake(alice, stakeAmount);

        // Fast forward time beyond decay-free window
        vm.warp(block.timestamp + 8 days);

        // Alice stakes again, triggering decay factor update
        vm.prank(alice);
        stakingRewardsManager.stake(alice, stakeAmount);

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
        stakingRewardsManager.stake(alice, stakeAmount);

        // Notify reward
        vm.prank(address(mockGovernor));
        stakingRewardsManager.notifyRewardAmount(
            IERC20(address(rewardTokens[0])),
            rewardAmount
        );

        // Fast forward time beyond decay-free window
        vm.warp(block.timestamp + 8 days);

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
        stakingRewardsManager.stake(alice, stakeAmount);

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
        vm.warp(block.timestamp + 8 days);

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
