// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {SummerGovernorTestBase} from "../governor/SummerGovernorTestBase.sol";
import {IGovernanceRewardsManagerErrors} from "../../src/errors/IGovernanceRewardsManagerErrors.sol";
import {IStakingRewardsManagerBaseErrors} from "@summerfi/rewards-contracts/interfaces/IStakingRewardsManagerBaseErrors.sol";
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

    // https://basescan.org/address/0xDDc68f9dE415ba2fE2FD84bc62Be2d2CFF1098dA
    // From: https://basescan.org/tx/0xab2f50ae5d285ea69575e353b795e24917f7e72695e23aa263d9bdba3c04b10b
    // To: https://basescan.org/tx/0x7c8f1fd4905d66900504e86c57af5faf43f62ed05a6d08f5024d5896b8113702
    function test_Regression_DelegateAndStakeSequence() public {
        // Setup
        // address bob = makeAddr("bob");
        // address carol = makeAddr("carol");
        // address dave = makeAddr("dave");

        // https://dashboard.tenderly.co/oazoapps/earn-protocol/simulator/81c050cb-51c7-49e8-b09b-111421dfc6ce
        deal(address(aSummerToken), alice, 3172125315636558134358);

        // Initial delegate to self
        vm.startPrank(alice);
        aSummerToken.delegate(alice);

        // First stake
        // https://basescan.org/tx/0xab2f50ae5d285ea69575e353b795e24917f7e72695e23aa263d9bdba3c04b10b
        stakingRewardsManager.stake(122 * 1e18);

        // Second stake
        // https://basescan.org/tx/0xeaa675bb1466b8d9880dc5704b5b0b62d6da1bc46d5f9decbd847a4118962296
        stakingRewardsManager.stake(3049 * 1e18);

        // Fast forward time
        vm.warp(block.timestamp + 15 hours);

        vm.expectRevert();
        stakingRewardsManager.stake(1105 * 1e18); // FAILED HERE (INSUFFICIENT BALANCE)

        vm.warp(block.timestamp + 1 hours);

        stakingRewardsManager.unstake(8 * 1e18);

        stakingRewardsManager.stake(8 * 1e18);

        // Finally, undelegate
        aSummerToken.delegate(address(0));
        vm.stopPrank();

        assertEq(aSummerToken.getVotes(alice), 0);
        assertEq(aSummerToken.delegates(alice), address(0));
    }
}
