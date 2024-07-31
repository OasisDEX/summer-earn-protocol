// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {ArkTestHelpers} from "../helpers/ArkHelpers.sol";
import "../../src/errors/FleetCommanderErrors.sol";
import {RebalanceData} from "../../src/types/FleetCommanderTypes.sol";
import {IArk} from "../../src/interfaces/IArk.sol";
import {FleetCommanderStorageWriter} from "../helpers/FleetCommanderStorageWriter.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";
import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {PercentageUtils} from "../../src/libraries/PercentageUtils.sol";

/**
 * @title Withdraw test suite for FleetCommander
 * @dev Test suite for the FleetCommander contract's withdraw functionality
 *
 * @dev TODO : add more tests
 *
 * Test coverage:
 * - Withdraw
 * - Error cases and edge scenarios
 */
contract WithdrawTest is Test, ArkTestHelpers, FleetCommanderTestBase {
    using PercentageUtils for uint256;

    uint256 constant DEPOSIT_AMOUNT = 1000 * 10 ** 6;

    function setUp() public {
        uint256 initialTipRate = 0;
        initializeFleetCommanderWithMockArks(initialTipRate);

        // Arrange (Deposit first)
        mockToken.mint(mockUser, DEPOSIT_AMOUNT);

        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), DEPOSIT_AMOUNT);
        fleetCommander.deposit(DEPOSIT_AMOUNT, mockUser);
        vm.stopPrank();
    }

    function test_UserCanWithdrawTokens() public {
        // Arrange - confirm user has deposited
        assertEq(
            DEPOSIT_AMOUNT,
            fleetCommander.balanceOf(mockUser),
            "User has not deposited"
        );

        // Act
        vm.prank(mockUser);
        uint256 withdrawalAmount = DEPOSIT_AMOUNT / 10;
        fleetCommander.withdraw(DEPOSIT_AMOUNT / 10, mockUser, mockUser);
        console.log("deposit amount", DEPOSIT_AMOUNT);
        console.log("withdrawal amount", withdrawalAmount);
        console.log("balanceOf(mockUser)", fleetCommander.balanceOf(mockUser));
        // Assert
        assertEq(
            DEPOSIT_AMOUNT - withdrawalAmount,
            fleetCommander.balanceOf(mockUser)
        );
    }

    function test_RevertIfArkMaxAllocationNotZero() public {
        // Act & Assert
        vm.prank(governor);
        mockArkMaxAllocation(ark1, 100);
        vm.expectRevert(
            abi.encodeWithSelector(
                FleetCommanderArkMaxAllocationGreaterThanZero.selector,
                ark1
            )
        );
        fleetCommander.removeArk(ark1);
    }

    function test_RevertIfArkTotalAssetsNotZero() public {
        // Act & Assert
        vm.prank(governor);
        mockArkTotalAssets(ark1, 100);
        mockArkMaxAllocation(ark1, 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                FleetCommanderArkAssetsNotZero.selector,
                ark1
            )
        );
        fleetCommander.removeArk(ark1);
    }

    function test_WithdrawZeroAmount() public {
        vm.prank(mockUser);
        fleetCommander.withdraw(0, mockUser, mockUser);
    }

    function test_WithdrawToOtherReceiver() public {
        address receiver = address(0xdeadbeef);
        uint256 withdrawAmount = DEPOSIT_AMOUNT / 2;

        vm.prank(mockUser);
        fleetCommander.withdraw(withdrawAmount, receiver, mockUser);

        assertEq(
            mockToken.balanceOf(receiver),
            withdrawAmount,
            "Receiver should have received the assets"
        );
        assertEq(
            mockToken.balanceOf(mockUser),
            0,
            "Owner should not have received any assets"
        );
    }

    function test_WithdrawMultipleTimes() public {
        uint256 withdrawAmount = DEPOSIT_AMOUNT / 3;

        vm.startPrank(mockUser);
        fleetCommander.withdraw(withdrawAmount, mockUser, mockUser);
        fleetCommander.withdraw(withdrawAmount, mockUser, mockUser);
        fleetCommander.withdraw(
            fleetCommander.maxWithdraw(mockUser),
            mockUser,
            mockUser
        );
        vm.stopPrank();

        assertEq(
            fleetCommander.balanceOf(mockUser),
            0,
            "User should have no remaining shares"
        );
        assertEq(
            mockToken.balanceOf(mockUser),
            DEPOSIT_AMOUNT,
            "User should have received all assets back"
        );
    }

    function test_WithdrawExceedingBalance() public {
        uint256 excessAmount = DEPOSIT_AMOUNT + 1;

        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC4626ExceededMaxWithdraw(address,uint256,uint256)",
                mockUser,
                excessAmount,
                fleetCommander.maxWithdraw(mockUser)
            )
        );
        vm.prank(mockUser);
        fleetCommander.withdraw(excessAmount, mockUser, mockUser);
    }

    function test_WithdrawByNonOwner() public {
        address nonOwner = address(0xdeadbeef);

        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderUnauthorizedWithdrawal(address,address)",
                nonOwner,
                mockUser
            )
        );

        vm.prank(nonOwner);
        fleetCommander.withdraw(DEPOSIT_AMOUNT - 1, nonOwner, mockUser);
    }

    function test_WithdrawByNonOwnerWithSufficientAllowance() public {
        address nonOwner = address(0xdeadbeef);

        vm.prank(mockUser);
        fleetCommander.approve(nonOwner, DEPOSIT_AMOUNT);

        vm.prank(nonOwner);
        fleetCommander.withdraw(DEPOSIT_AMOUNT - 1, nonOwner, mockUser);
    }

    function test_WithdrawByNonOwnerWithInsufficientAllowance() public {
        address nonOwner = address(0xdeadbeef);

        vm.prank(mockUser);
        fleetCommander.approve(nonOwner, DEPOSIT_AMOUNT - 2);

        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderUnauthorizedWithdrawal(address,address)",
                nonOwner,
                mockUser
            )
        );

        vm.prank(nonOwner);
        fleetCommander.withdraw(DEPOSIT_AMOUNT - 1, nonOwner, mockUser);
    }

    function test_WithdrawEventEmission() public {
        uint256 withdrawAmount = DEPOSIT_AMOUNT / 2;

        vm.expectEmit(true, true, true, true);
        emit IERC4626.Withdraw(
            mockUser,
            mockUser,
            mockUser,
            withdrawAmount,
            withdrawAmount
        );

        vm.prank(mockUser);
        fleetCommander.withdraw(withdrawAmount, mockUser, mockUser);
    }

    function test_WithdrawUpdatesBufferBalance() public {
        uint256 withdrawAmount = DEPOSIT_AMOUNT / 2;
        uint256 initialBufferBalance = IArk(fleetCommander.bufferArk())
            .totalAssets();

        vm.prank(mockUser);
        fleetCommander.withdraw(withdrawAmount, mockUser, mockUser);

        uint256 finalBufferBalance = IArk(fleetCommander.bufferArk())
            .totalAssets();
        assertEq(
            finalBufferBalance,
            initialBufferBalance - withdrawAmount,
            "Buffer balance should decrease by withdrawn amount"
        );
    }

    function test_ForceWithdraw() public {
        uint256 withdrawAmount = DEPOSIT_AMOUNT;

        // Move some funds to different arks
        vm.warp(block.timestamp + INITIAL_REBALANCE_COOLDOWN);
        vm.startPrank(keeper);
        fleetCommander.rebalance(
            generateRebalanceData(
                address(fleetCommander.bufferArk()),
                ark1,
                DEPOSIT_AMOUNT / 3
            )
        );

        vm.warp(block.timestamp + INITIAL_REBALANCE_COOLDOWN);
        fleetCommander.rebalance(
            generateRebalanceData(
                address(fleetCommander.bufferArk()),
                ark2,
                DEPOSIT_AMOUNT / 3
            )
        );
        vm.stopPrank();

        vm.prank(mockUser);
        fleetCommander.forceWithdraw(withdrawAmount, mockUser, mockUser);

        assertEq(
            fleetCommander.balanceOf(mockUser),
            0,
            "User should have no remaining shares"
        );
        assertEq(
            mockToken.balanceOf(mockUser),
            DEPOSIT_AMOUNT,
            "User should have received all assets back"
        );
    }

    function test_ForceWithdrawExceedingBalance() public {
        uint256 excessAmount = DEPOSIT_AMOUNT + 1;

        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC4626ExceededMaxWithdraw(address,uint256,uint256)",
                mockUser,
                excessAmount,
                fleetCommander.maxWithdraw(mockUser)
            )
        );
        vm.prank(mockUser);
        fleetCommander.forceWithdraw(excessAmount, mockUser, mockUser);
    }

    function test_ForceWithdrawByNonOwner() public {
        address nonOwner = address(0xdeadbeef);

        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderUnauthorizedWithdrawal(address,address)",
                nonOwner,
                mockUser
            )
        );
        vm.prank(nonOwner);
        fleetCommander.forceWithdraw(DEPOSIT_AMOUNT, nonOwner, mockUser);
    }

    function test_ForceWithdrawByNonOwnerWithSufficientAllowance() public {
        address nonOwner = address(0xdeadbeef);

        vm.prank(mockUser);
        fleetCommander.approve(nonOwner, DEPOSIT_AMOUNT);

        vm.prank(nonOwner);
        fleetCommander.forceWithdraw(DEPOSIT_AMOUNT - 1, nonOwner, mockUser);
    }

    function test_ForceWithdrawByNonOwnerWithInsufficientAllowance() public {
        address nonOwner = address(0xdeadbeef);

        vm.prank(mockUser);
        fleetCommander.approve(nonOwner, DEPOSIT_AMOUNT - 2);

        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderUnauthorizedWithdrawal(address,address)",
                nonOwner,
                mockUser
            )
        );

        vm.prank(nonOwner);
        fleetCommander.forceWithdraw(DEPOSIT_AMOUNT - 1, nonOwner, mockUser);
    }

    function generateRebalanceData(
        address fromArk,
        address toArk,
        uint256 amount
    ) internal pure returns (RebalanceData[] memory) {
        RebalanceData[] memory data = new RebalanceData[](1);
        data[0] = RebalanceData({
            fromArk: fromArk,
            toArk: toArk,
            amount: amount
        });
        return data;
    }
}
