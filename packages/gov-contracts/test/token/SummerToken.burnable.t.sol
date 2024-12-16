// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerTokenTestBase} from "./SummerTokenTestBase.sol";
import {ISummerToken} from "../../src/interfaces/ISummerToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SummerTokenBurnableTest is SummerTokenTestBase {
    // Define the Transfer event
    event Transfer(address indexed from, address indexed to, uint256 value);

    address public user1 = address(0x1);
    address public user2 = address(0x2);

    function setUp() public virtual override {
        super.setUp();
        enableTransfers(); // Enable transfers for testing
    }

    // ======== burn() tests ========

    function test_burn() public {
        uint256 burnAmount = 100 ether;
        uint256 initialBalance = aSummerToken.balanceOf(owner);
        uint256 initialSupply = aSummerToken.totalSupply();

        vm.expectEmit(true, true, false, true);
        emit Transfer(owner, address(0), burnAmount);

        aSummerToken.burn(burnAmount);

        assertEq(aSummerToken.balanceOf(owner), initialBalance - burnAmount);
        assertEq(aSummerToken.totalSupply(), initialSupply - burnAmount);

        // Test bSummerToken as well
        bSummerToken.mint(owner, burnAmount);
        initialBalance = bSummerToken.balanceOf(owner);
        initialSupply = bSummerToken.totalSupply();

        bSummerToken.burn(burnAmount);

        assertEq(bSummerToken.balanceOf(owner), initialBalance - burnAmount);
        assertEq(bSummerToken.totalSupply(), initialSupply - burnAmount);
    }

    function testFail_burnMoreThanBalance() public {
        uint256 burnAmount = aSummerToken.balanceOf(owner) + 1;
        aSummerToken.burn(burnAmount);
    }

    function test_burnZeroAmount() public {
        uint256 initialBalance = aSummerToken.balanceOf(owner);
        uint256 initialSupply = aSummerToken.totalSupply();

        aSummerToken.burn(0);

        assertEq(aSummerToken.balanceOf(owner), initialBalance);
        assertEq(aSummerToken.totalSupply(), initialSupply);
    }

    // ======== burnFrom() tests ========

    function test_burnFrom() public {
        uint256 burnAmount = 100 ether;
        aSummerToken.transfer(user1, burnAmount);
        uint256 initialBalance = aSummerToken.balanceOf(user1);
        uint256 initialSupply = aSummerToken.totalSupply();

        vm.startPrank(user1);
        aSummerToken.approve(owner, burnAmount);
        vm.stopPrank();

        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, address(0), burnAmount);

        aSummerToken.burnFrom(user1, burnAmount);

        assertEq(aSummerToken.balanceOf(user1), initialBalance - burnAmount);
        assertEq(aSummerToken.totalSupply(), initialSupply - burnAmount);
        assertEq(aSummerToken.allowance(user1, owner), 0);

        // Test bSummerToken as well
        bSummerToken.mint(user1, burnAmount);
        initialBalance = bSummerToken.balanceOf(user1);
        initialSupply = bSummerToken.totalSupply();

        vm.prank(user1);
        bSummerToken.approve(owner, burnAmount);

        bSummerToken.burnFrom(user1, burnAmount);

        assertEq(bSummerToken.balanceOf(user1), initialBalance - burnAmount);
        assertEq(bSummerToken.totalSupply(), initialSupply - burnAmount);
        assertEq(bSummerToken.allowance(user1, owner), 0);
    }

    function testFail_burnFromWithoutAllowance() public {
        aSummerToken.transfer(user1, 100 ether);
        aSummerToken.burnFrom(user1, 100 ether);
    }

    function testFail_burnFromMoreThanAllowance() public {
        uint256 burnAmount = 100 ether;
        aSummerToken.transfer(user1, burnAmount);

        vm.startPrank(user1);
        aSummerToken.approve(owner, burnAmount / 2);
        vm.stopPrank();

        aSummerToken.burnFrom(user1, burnAmount);
    }

    function testFail_burnFromMoreThanBalance() public {
        uint256 burnAmount = 100 ether;
        aSummerToken.transfer(user1, burnAmount);

        vm.startPrank(user1);
        aSummerToken.approve(owner, burnAmount * 2);
        vm.stopPrank();

        aSummerToken.burnFrom(user1, burnAmount * 2);
    }

    function test_burnFromWithInfiniteAllowance() public {
        uint256 burnAmount = 100 ether;
        aSummerToken.transfer(user1, burnAmount);
        uint256 initialBalance = aSummerToken.balanceOf(user1);
        uint256 initialSupply = aSummerToken.totalSupply();

        vm.startPrank(user1);
        aSummerToken.approve(owner, type(uint256).max);
        vm.stopPrank();

        aSummerToken.burnFrom(user1, burnAmount);

        assertEq(aSummerToken.balanceOf(user1), initialBalance - burnAmount);
        assertEq(aSummerToken.totalSupply(), initialSupply - burnAmount);
        assertEq(aSummerToken.allowance(user1, owner), type(uint256).max);
    }

    function test_multipleBurnsFromSameAccount() public {
        uint256 burnAmount = 50 ether;
        uint256 totalAmount = burnAmount * 2;
        aSummerToken.transfer(user1, totalAmount);
        uint256 initialBalance = aSummerToken.balanceOf(user1);

        vm.startPrank(user1);
        aSummerToken.approve(owner, totalAmount);
        vm.stopPrank();

        // First burn
        aSummerToken.burnFrom(user1, burnAmount);
        assertEq(aSummerToken.balanceOf(user1), initialBalance - burnAmount);
        assertEq(aSummerToken.allowance(user1, owner), burnAmount);

        // Second burn
        aSummerToken.burnFrom(user1, burnAmount);
        assertEq(aSummerToken.balanceOf(user1), initialBalance - totalAmount);
        assertEq(aSummerToken.allowance(user1, owner), 0);
    }

    // ======== Edge cases ========

    function test_burnFromZeroAmount() public {
        aSummerToken.transfer(user1, 100 ether);

        vm.startPrank(user1);
        aSummerToken.approve(owner, 100 ether);
        vm.stopPrank();

        uint256 initialBalance = aSummerToken.balanceOf(user1);
        uint256 initialAllowance = aSummerToken.allowance(user1, owner);
        uint256 initialSupply = aSummerToken.totalSupply();

        aSummerToken.burnFrom(user1, 0);

        assertEq(aSummerToken.balanceOf(user1), initialBalance);
        assertEq(aSummerToken.allowance(user1, owner), initialAllowance);
        assertEq(aSummerToken.totalSupply(), initialSupply);
    }

    function test_burnAndVotingPower() public {
        uint256 burnAmount = 100 ether;
        aSummerToken.transfer(user1, burnAmount);

        vm.startPrank(user1);
        aSummerToken.delegate(user1);
        vm.stopPrank();

        // Move forward one block to ensure delegation is active
        vm.roll(block.number + 1);

        uint256 initialVotes = aSummerToken.getVotes(user1);
        assertEq(
            initialVotes,
            burnAmount,
            "Initial voting power should match amount"
        );

        vm.prank(user1);
        aSummerToken.burn(burnAmount);

        assertEq(
            aSummerToken.getVotes(user1),
            0,
            "Voting power should be zero after burn"
        );
    }

    function testFail_burnFromZeroAddress() public {
        aSummerToken.burnFrom(address(0), 100 ether);
    }
}
