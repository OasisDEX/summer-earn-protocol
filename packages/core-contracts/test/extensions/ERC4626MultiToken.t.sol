// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC4626MultiTokenMock} from "../mocks/ERC4626MultiTokenMock.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626MultiTokenEvents} from "../../src/interfaces/extensions/ERC4626MultiToken/IERC4626MultiTokenEvents.sol";
import {IERC4626MultiTokenErrors} from "../../src/interfaces/extensions/ERC4626MultiToken/IERC4626MultiTokenErrors.sol";

contract ERC4626MultiTokenTest is Test, IERC4626MultiTokenEvents {
    ERC4626MultiTokenMock public vault;
    MockERC20 public assetToken;

    address public unprivilegedAccount = address(0x1);
    address public unprivilegedAccount2 = address(0x2);

    function setUp() public {
        assetToken = new MockERC20();
        assetToken.initialize("AssetToken", "AST", 18);

        vault = new ERC4626MultiTokenMock(address(assetToken), "SomeURI");

        // Setup accounts with tokens
        vm.startPrank(unprivilegedAccount);
        assetToken.mint(unprivilegedAccount, 1 ether);
        assetToken.approve(address(vault), 1 ether);
        vm.stopPrank();

        vm.startPrank(unprivilegedAccount2);
        assetToken.mint(unprivilegedAccount2, 1 ether);
        assetToken.approve(address(vault), 1 ether);
        vm.stopPrank();
    }

    function test_VWR0001_DefaultValue() public view {
        assertEq(vault.asset(), address(assetToken));
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.maxDeposit(unprivilegedAccount), type(uint256).max);
        assertEq(vault.maxRedeem(unprivilegedAccount), 0);
    }

    function test_VWR0002_Deposit() public {
        vm.startPrank(unprivilegedAccount);

        vm.expectEmit(true, true, true, true);
        emit DepositWithReceipt(
            unprivilegedAccount,
            unprivilegedAccount,
            0,
            0.5 ether
        );
        vault.deposit(0.5 ether, unprivilegedAccount);

        vm.stopPrank();

        assertEq(assetToken.balanceOf(address(vault)), 0.5 ether);
        assertEq(assetToken.balanceOf(unprivilegedAccount), 0.5 ether);

        assertEq(vault.totalAssets(), 0.5 ether);
        assertEq(vault.maxDeposit(unprivilegedAccount), type(uint256).max);
        assertEq(vault.maxRedeem(unprivilegedAccount), 0.5 ether);

        assertTrue(vault.exists(0));
        assertEq(vault.totalSupply(0), 0.5 ether);

        assertEq(vault.balanceOfAll(unprivilegedAccount), 0.5 ether);
        assertEq(vault.balanceOf(unprivilegedAccount, 0), 0.5 ether);
    }

    function test_VWR0003_Redeem() public {
        vm.startPrank(unprivilegedAccount);
        vault.deposit(0.5 ether, unprivilegedAccount);

        assertEq(vault.maxRedeem(unprivilegedAccount), 0.5 ether);

        vm.expectEmit(true, true, true, true);
        emit RedeemReceipt(
            unprivilegedAccount,
            unprivilegedAccount,
            unprivilegedAccount,
            0,
            0.5 ether
        );
        vault.redeem(0, 0.5 ether, unprivilegedAccount, unprivilegedAccount);

        vm.stopPrank();

        assertFalse(vault.exists(0));
        assertEq(vault.totalSupply(0), 0);

        assertEq(vault.balanceOfAll(unprivilegedAccount), 0);
        assertEq(vault.balanceOf(unprivilegedAccount, 0), 0);
    }

    function test_VWR0004_RedeemBatch() public {
        vm.startPrank(unprivilegedAccount);
        vault.deposit(0.2 ether, unprivilegedAccount);

        vault.mockSetMintId(1);
        vault.deposit(0.2 ether, unprivilegedAccount);

        vault.mockSetMintId(2);
        vault.deposit(0.2 ether, unprivilegedAccount);

        assertEq(vault.maxRedeem(unprivilegedAccount), 0.6 ether);

        assertTrue(vault.exists(0));
        assertTrue(vault.exists(1));
        assertTrue(vault.exists(2));

        uint256[] memory ids = new uint256[](3);
        ids[0] = 0;
        ids[1] = 1;
        ids[2] = 2;
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 0.2 ether;
        amounts[1] = 0.2 ether;
        amounts[2] = 0.2 ether;

        vm.expectEmit(true, true, true, true);
        emit RedeemReceiptBatch(
            unprivilegedAccount,
            unprivilegedAccount,
            unprivilegedAccount,
            ids,
            amounts
        );
        vault.redeemBatch(
            ids,
            amounts,
            unprivilegedAccount,
            unprivilegedAccount
        );

        vm.stopPrank();

        assertFalse(vault.exists(0));
        assertFalse(vault.exists(1));
        assertFalse(vault.exists(2));
        assertEq(vault.totalSupply(0), 0);
        assertEq(vault.totalSupply(1), 0);
        assertEq(vault.totalSupply(2), 0);

        assertEq(vault.balanceOfAll(unprivilegedAccount), 0);
        assertEq(vault.balanceOf(unprivilegedAccount, 0), 0);
        assertEq(vault.balanceOf(unprivilegedAccount, 1), 0);
        assertEq(vault.balanceOf(unprivilegedAccount, 2), 0);
    }

    function test_VWR0005_RedeemPartial() public {
        vm.startPrank(unprivilegedAccount);
        vault.deposit(0.5 ether, unprivilegedAccount);

        assertEq(vault.maxRedeem(unprivilegedAccount), 0.5 ether);

        vm.expectEmit(true, true, true, true);
        emit RedeemReceipt(
            unprivilegedAccount,
            unprivilegedAccount,
            unprivilegedAccount,
            0,
            0.3 ether
        );
        vault.redeem(0, 0.3 ether, unprivilegedAccount, unprivilegedAccount);

        vm.stopPrank();

        assertTrue(vault.exists(0));
        assertEq(vault.totalSupply(0), 0.2 ether);

        assertEq(vault.balanceOfAll(unprivilegedAccount), 0.2 ether);
        assertEq(vault.balanceOf(unprivilegedAccount, 0), 0.2 ether);
    }

    function test_VWR0006_RedeemPartialBatch() public {
        vm.startPrank(unprivilegedAccount);
        vault.deposit(0.3 ether, unprivilegedAccount);

        vault.mockSetMintId(1);
        vault.deposit(0.3 ether, unprivilegedAccount);

        vault.mockSetMintId(2);
        vault.deposit(0.3 ether, unprivilegedAccount);

        assertEq(vault.maxRedeem(unprivilegedAccount), 0.9 ether);

        assertTrue(vault.exists(0));
        assertTrue(vault.exists(1));
        assertTrue(vault.exists(2));

        uint256[] memory ids = new uint256[](3);
        ids[0] = 0;
        ids[1] = 1;
        ids[2] = 2;
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 0.1 ether;
        amounts[1] = 0.2 ether;
        amounts[2] = 0.3 ether;

        vm.expectEmit(true, true, true, true);
        emit RedeemReceiptBatch(
            unprivilegedAccount,
            unprivilegedAccount,
            unprivilegedAccount,
            ids,
            amounts
        );
        vault.redeemBatch(
            ids,
            amounts,
            unprivilegedAccount,
            unprivilegedAccount
        );

        vm.stopPrank();

        assertTrue(vault.exists(0));
        assertTrue(vault.exists(1));
        assertFalse(vault.exists(2));

        assertEq(vault.totalSupply(0), 0.2 ether);
        assertEq(vault.totalSupply(1), 0.1 ether);
        assertEq(vault.totalSupply(2), 0);

        assertEq(vault.balanceOfAll(unprivilegedAccount), 0.3 ether);
        assertEq(vault.balanceOf(unprivilegedAccount, 0), 0.2 ether);
        assertEq(vault.balanceOf(unprivilegedAccount, 1), 0.1 ether);
        assertEq(vault.balanceOf(unprivilegedAccount, 2), 0);
    }

    function test_VWR0007_TwoParticipants() public {
        vm.startPrank(unprivilegedAccount);
        vault.deposit(0.3 ether, unprivilegedAccount);
        vm.stopPrank();

        vm.startPrank(unprivilegedAccount2);
        vault.deposit(0.2 ether, unprivilegedAccount2);
        vm.stopPrank();

        vault.mockSetMintId(1);

        vm.startPrank(unprivilegedAccount);
        vault.deposit(0.3 ether, unprivilegedAccount);
        vm.stopPrank();

        vm.startPrank(unprivilegedAccount2);
        vault.deposit(0.5 ether, unprivilegedAccount2);
        vm.stopPrank();

        assertEq(vault.maxRedeem(unprivilegedAccount), 0.6 ether);
        assertEq(vault.maxRedeem(unprivilegedAccount2), 0.7 ether);

        assertEq(vault.balanceOfAll(unprivilegedAccount), 0.6 ether);
        assertEq(vault.balanceOf(unprivilegedAccount, 0), 0.3 ether);
        assertEq(vault.balanceOf(unprivilegedAccount, 1), 0.3 ether);

        assertEq(vault.balanceOfAll(unprivilegedAccount2), 0.7 ether);
        assertEq(vault.balanceOf(unprivilegedAccount2, 0), 0.2 ether);
        assertEq(vault.balanceOf(unprivilegedAccount2, 1), 0.5 ether);

        assertTrue(vault.exists(0));
        assertEq(vault.totalSupply(0), 0.5 ether);
        assertTrue(vault.exists(1));
        assertEq(vault.totalSupply(1), 0.8 ether);

        // Redeem partially from each participant
        vm.startPrank(unprivilegedAccount);
        vm.expectEmit(true, true, true, true);
        emit RedeemReceipt(
            unprivilegedAccount,
            unprivilegedAccount,
            unprivilegedAccount,
            0,
            0.1 ether
        );
        vault.redeem(0, 0.1 ether, unprivilegedAccount, unprivilegedAccount);
        vm.stopPrank();

        assertTrue(vault.exists(0));

        vm.startPrank(unprivilegedAccount2);
        vm.expectEmit(true, true, true, true);
        emit RedeemReceipt(
            unprivilegedAccount2,
            unprivilegedAccount2,
            unprivilegedAccount2,
            1,
            0.2 ether
        );
        vault.redeem(1, 0.2 ether, unprivilegedAccount2, unprivilegedAccount2);
        vm.stopPrank();

        assertTrue(vault.exists(0));
        assertTrue(vault.exists(1));

        assertEq(vault.maxRedeem(unprivilegedAccount), 0.5 ether);
        assertEq(vault.maxRedeem(unprivilegedAccount2), 0.5 ether);

        assertEq(vault.balanceOfAll(unprivilegedAccount), 0.5 ether);
        assertEq(vault.balanceOf(unprivilegedAccount, 0), 0.2 ether);
        assertEq(vault.balanceOf(unprivilegedAccount, 1), 0.3 ether);

        assertEq(vault.balanceOfAll(unprivilegedAccount2), 0.5 ether);
        assertEq(vault.balanceOf(unprivilegedAccount2, 0), 0.2 ether);
        assertEq(vault.balanceOf(unprivilegedAccount2, 1), 0.3 ether);

        assertEq(vault.totalSupply(0), 0.4 ether);
        assertEq(vault.totalSupply(1), 0.6 ether);
    }


    function test_Negative_MaxDepositExceeded() public {
        vm.startPrank(unprivilegedAccount);
        vault.mockSetMaxDeposit(0.1 ether);
        
        vm.expectRevert(abi.encodeWithSelector(IERC4626MultiTokenErrors.MaxDepositExceeded.selector, unprivilegedAccount, 0.5 ether, 0.1 ether));
        vault.deposit(0.5 ether, unprivilegedAccount);
        vm.stopPrank();
    }

    function test_Negative_MaxRedeemExceeded() public {
        vm.startPrank(unprivilegedAccount);
        vault.deposit(0.5 ether, unprivilegedAccount);
        
        vm.expectRevert(abi.encodeWithSelector(IERC4626MultiTokenErrors.MaxRedeemExceeded.selector, unprivilegedAccount, unprivilegedAccount, 0, 0.6 ether, 0.5 ether));
        vault.redeem(0, 0.6 ether, unprivilegedAccount, unprivilegedAccount);
        vm.stopPrank();
    }

    function test_Negative_BadRedeemBatchParameters() public {
        vm.startPrank(unprivilegedAccount);
        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0.2 ether;
        
        vm.expectRevert(abi.encodeWithSelector(IERC4626MultiTokenErrors.BadRedeemBatchParameters.selector, 2, 1));
        vault.redeemBatch(ids, amounts, unprivilegedAccount, unprivilegedAccount);
        vm.stopPrank();
    }

    function test_Negative_MaxRedeemBatchExceeded() public {
        vm.startPrank(unprivilegedAccount);
        vault.deposit(0.2 ether, unprivilegedAccount);
        
        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0.3 ether;
        
        vm.expectRevert(abi.encodeWithSelector(IERC4626MultiTokenErrors.MaxRedeemBatchExceeded.selector, unprivilegedAccount, unprivilegedAccount, ids, 0.3 ether, 0.2 ether));
        vault.redeemBatch(ids, amounts, unprivilegedAccount, unprivilegedAccount);
        vm.stopPrank();
    }

    function test_Negative_CallerCannotRedeem() public {
        vm.prank(unprivilegedAccount);
        vault.deposit(0.5 ether, unprivilegedAccount);
        
        vm.prank(unprivilegedAccount2);
        vm.expectRevert(abi.encodeWithSelector(IERC4626MultiTokenErrors.CallerCannotRedeem.selector, unprivilegedAccount2, unprivilegedAccount, 0, 0.5 ether));
        vault.redeem(0, 0.5 ether, unprivilegedAccount2, unprivilegedAccount);
    }

    function test_Negative_CallerCannotRedeemBatch() public {
        vm.prank(unprivilegedAccount);
        vault.deposit(0.5 ether, unprivilegedAccount);
        
        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0.5 ether;
        
        vm.prank(unprivilegedAccount2);
        vm.expectRevert(abi.encodeWithSelector(IERC4626MultiTokenErrors.CallerCannotRedeemBatch.selector, unprivilegedAccount2, unprivilegedAccount, ids, amounts));
        vault.redeemBatch(ids, amounts, unprivilegedAccount2, unprivilegedAccount);
    }
}
