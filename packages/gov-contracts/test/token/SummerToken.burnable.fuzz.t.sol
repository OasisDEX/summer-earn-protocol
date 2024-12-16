// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerTokenTestBase} from "./SummerTokenTestBase.sol";
import {ISummerToken} from "../../src/interfaces/ISummerToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SummerTokenBurnableFuzzTest is SummerTokenTestBase {
    event Transfer(address indexed from, address indexed to, uint256 value);

    address public user1 = address(0x1);
    address public user2 = address(0x2);

    function setUp() public virtual override {
        super.setUp();
        enableTransfers();
    }

    // ======== burn() fuzz tests ========

    function testFuzz_burn(uint256 burnAmount) public {
        // Bound burnAmount to be within reasonable limits
        burnAmount = bound(burnAmount, 0, aSummerToken.balanceOf(owner));

        uint256 initialBalance = aSummerToken.balanceOf(owner);
        uint256 initialSupply = aSummerToken.totalSupply();

        vm.expectEmit(true, true, false, true);
        emit Transfer(owner, address(0), burnAmount);

        aSummerToken.burn(burnAmount);

        assertEq(aSummerToken.balanceOf(owner), initialBalance - burnAmount);
        assertEq(aSummerToken.totalSupply(), initialSupply - burnAmount);
    }

    function testFuzz_burnFailMoreThanBalance(uint256 burnAmount) public {
        burnAmount = bound(
            burnAmount,
            aSummerToken.balanceOf(owner) + 1,
            type(uint256).max
        );
        vm.expectRevert();
        aSummerToken.burn(burnAmount);
    }

    // ======== burnFrom() fuzz tests ========

    function testFuzz_burnFrom(
        uint256 burnAmount,
        uint256 initialBalance
    ) public {
        // Bound the values to reasonable ranges
        initialBalance = bound(initialBalance, 1, 1000000 ether);
        burnAmount = bound(burnAmount, 0, initialBalance);

        // Setup initial state
        aSummerToken.transfer(user1, initialBalance);

        vm.startPrank(user1);
        aSummerToken.approve(owner, burnAmount);
        vm.stopPrank();

        uint256 initialSupply = aSummerToken.totalSupply();

        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, address(0), burnAmount);

        aSummerToken.burnFrom(user1, burnAmount);

        assertEq(aSummerToken.balanceOf(user1), initialBalance - burnAmount);
        assertEq(aSummerToken.totalSupply(), initialSupply - burnAmount);
        assertEq(aSummerToken.allowance(user1, owner), 0);
    }

    function testFuzz_burnFromWithInfiniteAllowance(
        uint256 burnAmount,
        uint256 initialBalance
    ) public {
        // Bound the values
        initialBalance = bound(initialBalance, 1, 1000000 ether);
        burnAmount = bound(burnAmount, 0, initialBalance);

        aSummerToken.transfer(user1, initialBalance);

        vm.startPrank(user1);
        aSummerToken.approve(owner, type(uint256).max);
        vm.stopPrank();

        uint256 initialSupply = aSummerToken.totalSupply();

        aSummerToken.burnFrom(user1, burnAmount);

        assertEq(aSummerToken.balanceOf(user1), initialBalance - burnAmount);
        assertEq(aSummerToken.totalSupply(), initialSupply - burnAmount);
        assertEq(aSummerToken.allowance(user1, owner), type(uint256).max);
    }

    function testFuzz_multipleBurnsFromSameAccount(
        uint256 firstBurnAmount,
        uint256 secondBurnAmount,
        uint256 initialBalance
    ) public {
        // Bound the values
        initialBalance = bound(initialBalance, 2, 1000000 ether);
        firstBurnAmount = bound(firstBurnAmount, 1, initialBalance / 2);
        secondBurnAmount = bound(
            secondBurnAmount,
            1,
            initialBalance - firstBurnAmount
        );

        aSummerToken.transfer(user1, initialBalance);

        vm.startPrank(user1);
        aSummerToken.approve(owner, firstBurnAmount + secondBurnAmount);
        vm.stopPrank();

        // First burn
        aSummerToken.burnFrom(user1, firstBurnAmount);
        assertEq(
            aSummerToken.balanceOf(user1),
            initialBalance - firstBurnAmount
        );
        assertEq(aSummerToken.allowance(user1, owner), secondBurnAmount);

        // Second burn
        aSummerToken.burnFrom(user1, secondBurnAmount);
        assertEq(
            aSummerToken.balanceOf(user1),
            initialBalance - firstBurnAmount - secondBurnAmount
        );
        assertEq(aSummerToken.allowance(user1, owner), 0);
    }

    function testFuzz_burnAndVotingPower(
        uint256 burnAmount,
        uint256 initialBalance
    ) public {
        // Bound the values
        initialBalance = bound(initialBalance, 1, 1000000 ether);
        burnAmount = bound(burnAmount, 0, initialBalance);

        aSummerToken.transfer(user1, initialBalance);

        vm.startPrank(user1);
        aSummerToken.delegate(user1);
        vm.stopPrank();

        vm.roll(block.number + 1);

        uint256 initialVotes = aSummerToken.getVotes(user1);
        assertEq(
            initialVotes,
            initialBalance,
            "Initial voting power should match balance"
        );

        vm.prank(user1);
        aSummerToken.burn(burnAmount);

        assertEq(
            aSummerToken.getVotes(user1),
            initialBalance - burnAmount,
            "Voting power should be reduced by burn amount"
        );
    }

    // ======== Failure cases with fuzz ========

    function testFuzz_burnFromFailWithoutAllowance(
        uint256 burnAmount,
        uint256 initialBalance
    ) public {
        // Bound the values
        initialBalance = bound(initialBalance, 1, 1000000 ether);
        burnAmount = bound(burnAmount, 1, initialBalance);

        aSummerToken.transfer(user1, initialBalance);

        vm.expectRevert();
        aSummerToken.burnFrom(user1, burnAmount);
    }

    function testFuzz_burnFromFailMoreThanAllowance(
        uint256 burnAmount,
        uint256 allowance,
        uint256 initialBalance
    ) public {
        // Bound the values
        initialBalance = bound(initialBalance, 2, 1000000 ether);
        allowance = bound(allowance, 1, initialBalance - 1);
        burnAmount = bound(burnAmount, allowance + 1, initialBalance);

        aSummerToken.transfer(user1, initialBalance);

        vm.startPrank(user1);
        aSummerToken.approve(owner, allowance);
        vm.stopPrank();

        vm.expectRevert();
        aSummerToken.burnFrom(user1, burnAmount);
    }

    function testFuzz_burnFromFailMoreThanBalance(
        uint256 burnAmount,
        uint256 initialBalance
    ) public {
        // Bound the values
        initialBalance = bound(initialBalance, 1, 1000000 ether);
        burnAmount = bound(burnAmount, initialBalance + 1, type(uint256).max);

        aSummerToken.transfer(user1, initialBalance);

        vm.startPrank(user1);
        aSummerToken.approve(owner, burnAmount);
        vm.stopPrank();

        vm.expectRevert();
        aSummerToken.burnFrom(user1, burnAmount);
    }
}
