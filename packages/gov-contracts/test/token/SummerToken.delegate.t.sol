// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerTokenTestBase} from "./SummerTokenTestBase.sol";
import {ISummerToken} from "../../src/interfaces/ISummerToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IGovernanceRewardsManager} from "../../src/interfaces/IGovernanceRewardsManager.sol";
import {ISummerTokenErrors} from "../../src/errors/ISummerTokenErrors.sol";

contract SummerTokenDelegateTest is SummerTokenTestBase {
    uint256 public constant WAD = 1e18;

    address public user1 = address(0x1);
    address public user2 = address(0x2);

    function setUp() public virtual override {
        super.setUp();
        enableTransfers(); // Enable transfers for testing
    }

    function test_CircularDelegation() public {
        uint256 user1InitialBalance = 200e18;
        uint256 user2InitialBalance = 100e18;

        // Setup initial balances
        deal(address(aSummerToken), user1, user1InitialBalance);
        deal(address(aSummerToken), user2, user2InitialBalance);

        // Create a circular delegation chain: user1 -> user2 -> user1
        vm.prank(user1);
        aSummerToken.delegate(user2); // User 1 and 2 initial decay factors are 1 WAD

        vm.prank(user2);
        aSummerToken.delegate(user1);

        vm.warp(block.timestamp + 15 days); // half way through decay window

        vm.prank(address(aSummerToken));
        aSummerToken.updateDecayFactor(user2); // Restart decay window for user2

        vm.warp(block.timestamp + 15 days + 1 days); // 1 day through first decay window

        assertLt(
            aSummerToken.getDecayFactor(user1),
            WAD,
            "user1's decay factor should be less than 1 WAD"
        );

        assertEq(
            aSummerToken.getDecayFactor(user2),
            WAD,
            "user2's decay factor should be 1 WAD"
        );

        // Verify delegation chain is set up correctly
        assertEq(
            aSummerToken.delegates(user1),
            user2,
            "user1 should delegate to user2"
        );
        assertEq(
            aSummerToken.delegates(user2),
            user1,
            "user2 should delegate to user1"
        );

        // The voting power should reflect user1's original decay factor
        // since the circular delegation resolves back to the original account
        uint256 user1Votes = aSummerToken.getVotes(user1);
        uint256 user2Votes = aSummerToken.getVotes(user2);

        assertEq(
            user1Votes,
            (user2InitialBalance * aSummerToken.getDecayFactor(user1)) / WAD,
            "user1's voting power should match their balance"
        );
        assertEq(
            user2Votes,
            (user1InitialBalance * aSummerToken.getDecayFactor(user2)) / WAD,
            "user2's voting power should match their balance"
        );
    }

    function test_RevertWhen_UndelegatingWhileStaked() public {
        // Setup initial balance and stake for user1
        uint256 initialBalance = 100e18;
        deal(address(aSummerToken), user1, initialBalance);

        IGovernanceRewardsManager rewardsManager = IGovernanceRewardsManager(
            aSummerToken.rewardsManager()
        );

        // User1 delegates to user2 first
        vm.startPrank(user1);
        aSummerToken.approve(address(rewardsManager), initialBalance);
        aSummerToken.delegate(user2);

        // Stake some tokens
        rewardsManager.stake(50e18);

        // Attempt to undelegate (delegate to address(0)) while staked
        vm.expectRevert(
            ISummerTokenErrors.CannotUndelegateWhileStaked.selector
        );
        aSummerToken.delegate(address(0));
        vm.stopPrank();

        // Verify delegation is still to user2
        assertEq(
            aSummerToken.delegates(user1),
            user2,
            "delegation should remain unchanged"
        );
    }
}
