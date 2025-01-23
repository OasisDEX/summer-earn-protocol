// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {SummerGovernorTestBase} from "../governor/SummerGovernorTestBase.sol";
import {IGovernanceRewardsManagerErrors} from "../../src/errors/IGovernanceRewardsManagerErrors.sol";
import {IStakingRewardsManagerBaseErrors} from "@summerfi/rewards-contracts/interfaces/IStakingRewardsManagerBaseErrors.sol";
import {GovernanceRewardsManager} from "../../src/contracts/GovernanceRewardsManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GovernanceRewardsManagerTest is SummerGovernorTestBase {
    GovernanceRewardsManager public stakingRewardsManager;
    IERC20[] public rewardTokens;

    uint256 constant INITIAL_REWARD_AMOUNT = 1000000 * 1e18;
    uint256 constant INITIAL_STAKE_AMOUNT = 100000 * 1e18;

    function setUp() public override {
        super.setUp();

        // Deploy reward tokens
        for (uint i = 0; i < 3; i++) {
            rewardTokens.push(aSummerToken);
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

        // Approve staking
        vm.prank(alice);
        aSummerToken.approve(address(stakingRewardsManager), type(uint256).max);
        vm.prank(bob);
        aSummerToken.approve(address(stakingRewardsManager), type(uint256).max);

        // In the test setup
        deal(
            address(rewardTokens[0]),
            address(mockGovernor),
            100000000000000000000000
        ); // Mint 100_000 tokens
    }

    // https://basescan.org/address/0xDDc68f9dE415ba2fE2FD84bc62Be2d2CFF1098dA
    // From: https://basescan.org/tx/0xab2f50ae5d285ea69575e353b795e24917f7e72695e23aa263d9bdba3c04b10b
    // To: https://basescan.org/tx/0x7c8f1fd4905d66900504e86c57af5faf43f62ed05a6d08f5024d5896b8113702
    function test_Regression_DelegateAndStakeSequence() public {
        // Setup
        vm.startPrank(address(mockGovernor));

        IERC20(aSummerToken).approve(
            address(stakingRewardsManager),
            type(uint256).max
        );
        stakingRewardsManager.notifyRewardAmount(
            IERC20(aSummerToken),
            100000000000000000000000,
            604800
        );
        vm.stopPrank();
        vm.warp(block.timestamp + 43 hours - 18 hours);

        // https://dashboard.tenderly.co/oazoapps/earn-protocol/simulator/81c050cb-51c7-49e8-b09b-111421dfc6ce
        deal(address(aSummerToken), alice, 3172125315636558134358);

        // Initial delegate to self
        vm.startPrank(alice);
        aSummerToken.delegate(alice);

        // First stake
        // https://basescan.org/tx/0xab2f50ae5d285ea69575e353b795e24917f7e72695e23aa263d9bdba3c04b10b
        stakingRewardsManager.stake(122 * 1e18);

        // First claim
        // https://basescan.org/tx/0x2f72d99fbe3edbdc2f484e3ec723e3f03390c71ed6fa2781b30d3f5867b3b301#eventlog
        vm.warp(block.timestamp + 5 minutes);
        stakingRewardsManager.getReward(address(aSummerToken));

        // Second stake
        // https://basescan.org/tx/0xeaa675bb1466b8d9880dc5704b5b0b62d6da1bc46d5f9decbd847a4118962296
        vm.warp(block.timestamp + 5 minutes);
        stakingRewardsManager.stake(3049 * 1e18);

        // Claim
        // https://basescan.org/tx/0x396fa4adba1c54cdfa9384e212d0897d030c5f761924c733b07888d1660d279b#eventlog
        vm.warp(block.timestamp + 1 hours);
        stakingRewardsManager.getReward(address(aSummerToken));

        // Claim
        // https://basescan.org/tx/0x7ff24be92b9bd02485d9a002ee7a129a3bb50f2e666acb2590f1a360ed105dbc#eventlog
        vm.warp(block.timestamp + 30 minutes);
        stakingRewardsManager.getReward(address(aSummerToken));

        // https://basescan.org/tx/0x80ab953ac9593495a383912f55624e80e1e8f46296dcfcb0144fc53a4186fdff
        vm.warp(block.timestamp + 15 hours);
        stakingRewardsManager.stake(1105 * 1e18);

        // Unstake
        // https://basescan.org/tx/0x731798d5be3f4898cece88824d8da62681904c02b1c61715a10ce75a88f2e8fd
        vm.warp(block.timestamp + 30 minutes);
        stakingRewardsManager.unstake(8 * 1e18);

        // Stake
        // https://basescan.org/tx/0x8f6ad66f15206e12e45074513df330b279e114ac447893f482bae71dec96876e
        stakingRewardsManager.stake(8 * 1e18);

        // Finally, failed undelegate
        // https://basescan.org/tx/0x7c8f1fd4905d66900504e86c57af5faf43f62ed05a6d08f5024d5896b8113702
        aSummerToken.delegate(address(0));
        vm.stopPrank();

        assertEq(aSummerToken.getVotes(alice), 0);
        assertEq(aSummerToken.delegates(alice), address(0));
    }
}
