// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {TestHelpers} from "../helpers/TestHelpers.sol";

import {IFleetCommanderEvents} from "../../src/events/IFleetCommanderEvents.sol";
import {IArk} from "../../src/interfaces/IArk.sol";
import {FleetConfig} from "../../src/types/FleetCommanderTypes.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";
import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

/**
 * @title Deposit test suite for FleetCommander
 * @dev Test suite for the FleetCommander contract's deposit functionality
 *
 * @dev TODO : add more tests
 *
 * Test coverage:
 * - Deposit
 * - Error cases and edge scenarios
 */
contract DepositTest is Test, TestHelpers, FleetCommanderTestBase {
    uint256 constant DEPOSIT_AMOUNT = 1000 * 10 ** 6;
    uint256 constant MAX_DEPOSIT_CAP = 100000 * 10 ** 6;

    function setUp() public {
        uint256 initialTipRate = 0;
        initializeFleetCommanderWithMockArks(initialTipRate);
        fleetCommanderStorageWriter.setDepositCap(MAX_DEPOSIT_CAP);
    }

    function test_Deposit_withTip() public {
        uint256 amount = 1000 * 10 ** 6;
        uint256 maxDepositCap = 100000 * 10 ** 6;

        _mockArkTotalAssets(ark1, 0);
        _mockArkTotalAssets(ark2, 0);

        fleetCommanderStorageWriter.setDepositCap(maxDepositCap);
        fleetCommanderStorageWriter.setTipRate(1e18);

        mockToken.mint(mockUser, amount * 10);

        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), amount);
        fleetCommander.deposit(amount, mockUser);

        vm.warp(block.timestamp + 10 days);

        uint256 previewedShares = fleetCommander.previewDeposit(amount);

        mockToken.approve(address(fleetCommander), amount);

        uint256 sharesBefore = fleetCommander.balanceOf(mockUser);
        uint256 receivedShares = fleetCommander.deposit(amount, mockUser);
        uint256 sharesAfter = fleetCommander.balanceOf(mockUser);
        vm.stopPrank();
        assertEq(receivedShares, previewedShares);
        assertEq(sharesAfter, sharesBefore + receivedShares);
    }

    function test_Deposit() public {
        uint256 amount = 1000 * 10 ** 6;
        uint256 maxDepositCap = 100000 * 10 ** 6;

        fleetCommanderStorageWriter.setDepositCap(maxDepositCap);
        mockToken.mint(mockUser, amount);

        vm.prank(mockUser);
        mockToken.approve(address(fleetCommander), amount);
        _mockArkTotalAssets(ark1, 0);
        _mockArkTotalAssets(ark2, 0);

        vm.prank(mockUser);
        fleetCommander.deposit(amount, mockUser);

        assertEq(amount, fleetCommander.balanceOf(mockUser));
    }

    function test_DepositWithReferral() public {
        uint256 amount = 1000 * 10 ** 6;
        uint256 maxDepositCap = 100000 * 10 ** 6;

        (address referrer, uint256 referrerPk) = makeAddrAndKey("1337");

        // The message to sign (in this case, the signer's address)
        string memory message = vm.toString(referrer);

        bytes memory signature = signMessage(referrerPk, message);

        fleetCommanderStorageWriter.setDepositCap(maxDepositCap);
        mockToken.mint(mockUser, amount);

        vm.prank(mockUser);
        mockToken.approve(address(fleetCommander), amount);
        _mockArkTotalAssets(ark1, 0);
        _mockArkTotalAssets(ark2, 0);

        vm.prank(mockUser);
        vm.expectEmit();
        emit IFleetCommanderEvents.FleetCommanderReferral(mockUser, signature);
        fleetCommander.deposit(amount, mockUser, signature);

        assertEq(
            verifySignature(message, signature, referrer),
            true,
            "Signature should be valid"
        );
        assertEq(amount, fleetCommander.balanceOf(mockUser));
    }

    function test_DepositZeroAmount() public {
        vm.prank(mockUser);
        vm.expectRevert(abi.encodeWithSignature("FleetCommanderZeroAmount()"));
        fleetCommander.deposit(0, mockUser);
    }

    function test_DepositToOtherReceiver() public {
        address receiver = address(0xdeadbeef);
        uint256 amount = DEPOSIT_AMOUNT;

        mockToken.mint(mockUser, amount);
        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), amount);
        fleetCommander.deposit(amount, receiver);
        vm.stopPrank();

        assertEq(
            fleetCommander.balanceOf(receiver),
            amount,
            "Receiver should have received the shares"
        );
        assertEq(
            fleetCommander.balanceOf(mockUser),
            0,
            "Depositor should not have received any shares"
        );
    }

    function test_DepositMultipleTimes() public {
        uint256 amount = DEPOSIT_AMOUNT;
        mockToken.mint(mockUser, amount * 3);

        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), amount * 3);

        fleetCommander.deposit(amount, mockUser);
        fleetCommander.deposit(amount, mockUser);
        fleetCommander.deposit(amount, mockUser);

        vm.stopPrank();

        assertEq(
            fleetCommander.balanceOf(mockUser),
            amount * 3,
            "User should have received correct total shares"
        );
    }

    function test_DepositExceedingAllowance() public {
        uint256 amount = DEPOSIT_AMOUNT;
        uint256 allowance = amount / 2;

        mockToken.mint(mockUser, amount);
        vm.prank(mockUser);
        mockToken.approve(address(fleetCommander), allowance);

        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientAllowance(address,uint256,uint256)",
                address(fleetCommander),
                allowance,
                amount
            )
        );
        vm.prank(mockUser);
        fleetCommander.deposit(amount, mockUser);
    }

    function test_DepositExceedingBalance() public {
        uint256 amount = DEPOSIT_AMOUNT;
        uint256 balance = amount / 2;

        mockToken.mint(mockUser, balance);
        vm.prank(mockUser);
        mockToken.approve(address(fleetCommander), amount);
        vm.startPrank(mockUser);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC4626ExceededMaxDeposit(address,uint256,uint256)",
                mockUser,
                amount,
                balance
            )
        );
        fleetCommander.deposit(amount, mockUser);
        vm.stopPrank();
    }

    function test_DepositUpToDepositCap() public {
        uint256 depositCap = MAX_DEPOSIT_CAP / 2;
        fleetCommanderStorageWriter.setDepositCap(depositCap);

        mockToken.mint(mockUser, depositCap);
        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), depositCap);
        fleetCommander.deposit(depositCap, mockUser);
        vm.stopPrank();

        assertEq(
            fleetCommander.balanceOf(mockUser),
            depositCap,
            "User should have received correct shares"
        );
    }

    function test_DepositExceedingDepositCap() public {
        uint256 depositCap = MAX_DEPOSIT_CAP / 2;
        fleetCommanderStorageWriter.setDepositCap(depositCap);

        uint256 amount = depositCap + 1;
        mockToken.mint(mockUser, amount);
        vm.prank(mockUser);
        mockToken.approve(address(fleetCommander), amount);

        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC4626ExceededMaxDeposit(address,uint256,uint256)",
                mockUser,
                amount,
                depositCap
            )
        );
        vm.prank(mockUser);
        fleetCommander.deposit(amount, mockUser);
    }

    function test_DepositEventEmission() public {
        uint256 amount = DEPOSIT_AMOUNT;
        mockToken.mint(mockUser, amount);

        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), amount);

        vm.expectEmit(true, true, true, true);
        emit IERC4626.Deposit(mockUser, mockUser, amount, amount);
        fleetCommander.deposit(amount, mockUser);

        vm.stopPrank();
    }

    function test_DepositUpdatesBufferBalance() public {
        uint256 amount = DEPOSIT_AMOUNT;
        mockToken.mint(mockUser, amount);

        FleetConfig memory config = fleetCommander.getConfig();
        uint256 initialBufferBalance = config.bufferArk.totalAssets();

        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), amount);
        fleetCommander.deposit(amount, mockUser);
        vm.stopPrank();

        uint256 finalBufferBalance = bufferArk.totalAssets();
        assertEq(
            finalBufferBalance,
            initialBufferBalance + amount,
            "Buffer balance should increase by deposited amount"
        );
    }
}
