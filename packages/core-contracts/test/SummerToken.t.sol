// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../src/contracts/SummerToken.sol";
import "forge-std/Test.sol";

contract SummerTokenTest is Test {
    SummerToken public summerToken;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        summerToken = new SummerToken();
    }

    function testInitialSupply() public view {
        assertEq(summerToken.totalSupply(), 1000000000 * 10 ** 18);
    }

    function testOwnerBalance() public view {
        assertEq(summerToken.balanceOf(owner), 1000000000 * 10 ** 18);
    }

    function testTokenNameAndSymbol() public view {
        assertEq(summerToken.name(), "SummerToken");
        assertEq(summerToken.symbol(), "SUMMER");
    }

    function testTransfer() public {
        uint256 amount = 1000 * 10 ** 18;
        summerToken.transfer(user1, amount);
        assertEq(summerToken.balanceOf(user1), amount);
        assertEq(
            summerToken.balanceOf(owner),
            (1000000000 * 10 ** 18) - amount
        );
    }

    function testFailTransferInsufficientBalance() public {
        uint256 amount = 1000000001 * 10 ** 18;
        summerToken.transfer(user1, amount);
    }

    function testApproveAndTransferFrom() public {
        uint256 amount = 1000 * 10 ** 18;
        summerToken.approve(user1, amount);
        assertEq(summerToken.allowance(owner, user1), amount);

        vm.prank(user1);
        summerToken.transferFrom(owner, user2, amount);
        assertEq(summerToken.balanceOf(user2), amount);
        assertEq(summerToken.allowance(owner, user1), 0);
    }

    function testFailTransferFromInsufficientAllowance() public {
        uint256 amount = 1000 * 10 ** 18;
        summerToken.approve(user1, amount - 1);

        vm.prank(user1);
        summerToken.transferFrom(owner, user2, amount);
    }

    function testBurn() public {
        uint256 amount = 1000 * 10 ** 18;
        uint256 initialSupply = summerToken.totalSupply();

        summerToken.burn(amount);
        assertEq(summerToken.balanceOf(owner), initialSupply - amount);
        assertEq(summerToken.totalSupply(), initialSupply - amount);
    }

    function testFailBurnInsufficientBalance() public {
        uint256 amount = 1000000001 * 10 ** 18;
        summerToken.burn(amount);
    }

    function testBurnFrom() public {
        uint256 amount = 1000 * 10 ** 18;
        summerToken.approve(user1, amount);

        vm.prank(user1);
        summerToken.burnFrom(owner, amount);

        assertEq(
            summerToken.balanceOf(owner),
            (1000000000 * 10 ** 18) - amount
        );
        assertEq(summerToken.totalSupply(), (1000000000 * 10 ** 18) - amount);
        assertEq(summerToken.allowance(owner, user1), 0);
    }

    function testFailBurnFromInsufficientAllowance() public {
        uint256 amount = 1000 * 10 ** 18;
        summerToken.approve(user1, amount - 1);

        vm.prank(user1);
        summerToken.burnFrom(owner, amount);
    }
}
