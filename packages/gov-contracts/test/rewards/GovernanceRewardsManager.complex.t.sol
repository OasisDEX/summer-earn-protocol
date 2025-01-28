// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerGovernorTestBase} from "../governor/SummerGovernorTestBase.sol";
import {IGovernanceRewardsManagerErrors} from "../../src/errors/IGovernanceRewardsManagerErrors.sol";
import {IGovernanceRewardsManager} from "../../src/interfaces/IGovernanceRewardsManager.sol";
import {IStakingRewardsManagerBaseErrors} from "@summerfi/rewards-contracts/interfaces/IStakingRewardsManagerBaseErrors.sol";
import {ISummerToken} from "../../src/interfaces/ISummerToken.sol";
import {SummerToken} from "../../src/contracts/SummerToken.sol";
import {SupplyControlSummerToken} from "../utils/SupplyControlSummerToken.sol";
import {GovernanceRewardsManager} from "../../src/contracts/GovernanceRewardsManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {stdStorage, StdStorage} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {WrappedStakingToken} from "../../src/contracts/WrappedStakingToken.sol";

contract GovernanceRewardsManagerTest is SummerGovernorTestBase {
    using stdStorage for StdStorage;

    IGovernanceRewardsManager public workingStakingRewardsManager;
    BuggedGovernanceRewardsManager public buggedStakingRewardsManager;
    BuggedSummerToken public buggedSummerToken;

    IERC20[] public rewardTokens;

    uint256 constant INITIAL_REWARD_AMOUNT = 1000000 * 1e18;
    uint256 constant INITIAL_STAKE_AMOUNT = 100000 * 1e18;

    function setUp() public override {
        super.setUp();

        // Deploy bugged token with the same parameters as aSummerToken
        (
            ISummerToken.ConstructorParams memory constructorParams,
            ISummerToken.InitializeParams memory initParams
        ) = _getDefaultTokenParams();

        // Deploy our bugged version
        vm.startPrank(owner);
        buggedSummerToken = new BuggedSummerToken(constructorParams);
        buggedSummerToken.initialize(initParams);
        vm.stopPrank();

        uint256 transferEnableDate = buggedSummerToken.transferEnableDate() + 1;
        vm.warp(transferEnableDate);
        vm.prank(owner);
        buggedSummerToken.enableTransfers();

        // Set up access control for the bugged token
        vm.startPrank(address(timelockA));
        accessManagerA.grantDecayControllerRole(address(mockGovernor));
        accessManagerA.grantDecayControllerRole(
            address(buggedSummerToken.rewardsManager())
        );
        accessManagerA.grantDecayControllerRole(address(buggedSummerToken));
        vm.stopPrank();

        // Deploy reward tokens array
        for (uint i = 0; i < 3; i++) {
            rewardTokens.push(aSummerToken);
        }

        workingStakingRewardsManager = IGovernanceRewardsManager(
            aSummerToken.rewardsManager()
        );
        buggedStakingRewardsManager = new BuggedGovernanceRewardsManager(
            address(buggedSummerToken),
            address(accessManagerA)
        );

        // Grant roles
        vm.startPrank(address(timelockA));
        accessManagerA.grantDecayControllerRole(
            address(workingStakingRewardsManager)
        );
        accessManagerA.grantDecayControllerRole(
            address(buggedStakingRewardsManager)
        );
        accessManagerA.grantGovernorRole(address(mockGovernor));
        vm.stopPrank();

        // Approve staking
        vm.startPrank(alice);
        aSummerToken.approve(
            address(workingStakingRewardsManager),
            type(uint256).max
        );
        buggedSummerToken.approve(
            address(buggedStakingRewardsManager),
            type(uint256).max
        );
        vm.stopPrank();

        vm.startPrank(bob);
        aSummerToken.approve(
            address(workingStakingRewardsManager),
            type(uint256).max
        );
        buggedSummerToken.approve(
            address(buggedStakingRewardsManager),
            type(uint256).max
        );
        vm.stopPrank();

        // In the test setup
        deal(
            address(buggedSummerToken),
            address(mockGovernor),
            100000000000000000000000
        ); // Mint 100_000 tokens

        deal(
            address(aSummerToken),
            address(mockGovernor),
            100000000000000000000000
        ); // Mint 100_000 tokens
    }

    // https://basescan.org/address/0xDDc68f9dE415ba2fE2FD84bc62Be2d2CFF1098dA
    // From: https://basescan.org/tx/0xab2f50ae5d285ea69575e353b795e24917f7e72695e23aa263d9bdba3c04b10b
    // To: https://basescan.org/tx/0x7c8f1fd4905d66900504e86c57af5faf43f62ed05a6d08f5024d5896b8113702
    function test_Regression_DelegateAndStakeSequence() public {
        stdstore
            .target(address(buggedSummerToken))
            .sig("rewardsManager()")
            .checked_write(address(buggedStakingRewardsManager));

        // Setup
        vm.startPrank(address(mockGovernor));
        IERC20(buggedSummerToken).approve(
            address(buggedStakingRewardsManager),
            type(uint256).max
        );
        buggedStakingRewardsManager.notifyRewardAmount(
            address(buggedSummerToken),
            100000000000000000000000,
            604800
        );
        vm.stopPrank();
        vm.warp(block.timestamp + 43 hours - 18 hours);

        // https://dashboard.tenderly.co/oazoapps/earn-protocol/simulator/81c050cb-51c7-49e8-b09b-111421dfc6ce
        deal(address(buggedSummerToken), alice, 3172125315636558134358);

        // Initial delegate to self
        vm.startPrank(alice);
        buggedSummerToken.delegate(alice);

        // First stake
        // https://basescan.org/tx/0xab2f50ae5d285ea69575e353b795e24917f7e72695e23aa263d9bdba3c04b10b
        buggedStakingRewardsManager.stake(122 * 1e18);

        // First claim
        // https://basescan.org/tx/0x2f72d99fbe3edbdc2f484e3ec723e3f03390c71ed6fa2781b30d3f5867b3b301#eventlog
        vm.warp(block.timestamp + 5 minutes);
        buggedStakingRewardsManager.getReward(address(buggedSummerToken));

        // Second stake
        // https://basescan.org/tx/0xeaa675bb1466b8d9880dc5704b5b0b62d6da1bc46d5f9decbd847a4118962296
        vm.warp(block.timestamp + 5 minutes);
        buggedStakingRewardsManager.stake(3049 * 1e18);

        // Claim
        // https://basescan.org/tx/0x396fa4adba1c54cdfa9384e212d0897d030c5f761924c733b07888d1660d279b#eventlog
        vm.warp(block.timestamp + 1 hours);
        buggedStakingRewardsManager.getReward(address(buggedSummerToken));

        // Claim
        // https://basescan.org/tx/0x7ff24be92b9bd02485d9a002ee7a129a3bb50f2e666acb2590f1a360ed105dbc#eventlog
        vm.warp(block.timestamp + 30 minutes);
        buggedStakingRewardsManager.getReward(address(buggedSummerToken));

        // https://basescan.org/tx/0x80ab953ac9593495a383912f55624e80e1e8f46296dcfcb0144fc53a4186fdff
        vm.warp(block.timestamp + 15 hours);
        buggedStakingRewardsManager.stake(993188807700050195903); // Used different amount because of updateReward on _staked fix from 1105 * 1e18

        // Unstake
        // https://basescan.org/tx/0x731798d5be3f4898cece88824d8da62681904c02b1c61715a10ce75a88f2e8fd
        vm.warp(block.timestamp + 30 minutes);
        buggedStakingRewardsManager.unstake(8 * 1e18);

        // Stake
        // https://basescan.org/tx/0x8f6ad66f15206e12e45074513df330b279e114ac447893f482bae71dec96876e
        buggedStakingRewardsManager.stake(8 * 1e18);

        // Finally, failed undelegate
        // https://basescan.org/tx/0x7c8f1fd4905d66900504e86c57af5faf43f62ed05a6d08f5024d5896b8113702
        vm.expectRevert();
        buggedSummerToken.delegate(address(0));
        vm.stopPrank();
    }

    function test_Regression_DelegateAndStakeSequence_WithFix() public {
        // Setup
        vm.startPrank(address(mockGovernor));
        IERC20(aSummerToken).approve(
            address(workingStakingRewardsManager),
            type(uint256).max
        );
        workingStakingRewardsManager.notifyRewardAmount(
            address(aSummerToken),
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
        workingStakingRewardsManager.stake(122 * 1e18);

        // First claim
        // https://basescan.org/tx/0x2f72d99fbe3edbdc2f484e3ec723e3f03390c71ed6fa2781b30d3f5867b3b301#eventlog
        vm.warp(block.timestamp + 5 minutes);
        workingStakingRewardsManager.getReward(address(aSummerToken));

        // Second stake
        // https://basescan.org/tx/0xeaa675bb1466b8d9880dc5704b5b0b62d6da1bc46d5f9decbd847a4118962296
        vm.warp(block.timestamp + 5 minutes);
        workingStakingRewardsManager.stake(3049 * 1e18);

        // Claim
        // https://basescan.org/tx/0x396fa4adba1c54cdfa9384e212d0897d030c5f761924c733b07888d1660d279b#eventlog
        vm.warp(block.timestamp + 1 hours);
        workingStakingRewardsManager.getReward(address(aSummerToken));

        // Claim
        // https://basescan.org/tx/0x7ff24be92b9bd02485d9a002ee7a129a3bb50f2e666acb2590f1a360ed105dbc#eventlog
        vm.warp(block.timestamp + 30 minutes);
        workingStakingRewardsManager.getReward(address(aSummerToken));

        // https://basescan.org/tx/0x80ab953ac9593495a383912f55624e80e1e8f46296dcfcb0144fc53a4186fdff
        vm.warp(block.timestamp + 15 hours);
        workingStakingRewardsManager.stake(993188807700050195903); // Used different amount because of updateReward on _staked fix

        // Unstake
        // https://basescan.org/tx/0x731798d5be3f4898cece88824d8da62681904c02b1c61715a10ce75a88f2e8fd
        vm.warp(block.timestamp + 30 minutes);
        workingStakingRewardsManager.unstake(8 * 1e18);

        // Stake
        // https://basescan.org/tx/0x8f6ad66f15206e12e45074513df330b279e114ac447893f482bae71dec96876e
        workingStakingRewardsManager.stake(8 * 1e18);

        workingStakingRewardsManager.unstake(
            workingStakingRewardsManager.balanceOf(alice)
        );
        // Finally, failed undelegate - should work now
        // https://basescan.org/tx/0x7c8f1fd4905d66900504e86c57af5faf43f62ed05a6d08f5024d5896b8113702
        aSummerToken.delegate(address(0));
        vm.stopPrank();

        assertEq(aSummerToken.getVotes(alice), 0);
        assertEq(aSummerToken.delegates(alice), address(0));
    }
}

contract BuggedGovernanceRewardsManager is GovernanceRewardsManager {
    constructor(
        address _stakingToken,
        address accessManager
    ) GovernanceRewardsManager(_stakingToken, accessManager) {}

    function _unstake(
        address from,
        address receiver,
        uint256 amount
    ) internal override {
        if (amount == 0) revert CannotUnstakeZero();

        totalSupply -= amount;
        _balances[from] -= amount;

        WrappedStakingToken(wrappedStakingToken).withdrawTo(
            address(this),
            amount
        );

        // Transfer the unwrapped tokens to the receiver after voting power is properly adjusted
        IERC20(stakingToken).transfer(receiver, amount);

        emit Unstaked(from, receiver, amount);
    }
}

contract BuggedSummerToken is SupplyControlSummerToken {
    constructor(
        ISummerToken.ConstructorParams memory params
    ) SupplyControlSummerToken(params) {}

    function _handleRewardsManagerVotingTransfer(
        address from,
        address to
    ) internal view override returns (bool) {
        if (from == address(rewardsManager) || to == address(rewardsManager)) {
            return true;
        }
        return false;
    }
}
