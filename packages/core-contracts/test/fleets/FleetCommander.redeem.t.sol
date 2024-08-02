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

contract RedeemTest is Test, ArkTestHelpers, FleetCommanderTestBase {
    using PercentageUtils for uint256;

    uint256 constant DEPOSIT_AMOUNT = 1000 * 10 ** 6;

    function setUp() public {
        uint256 initialTipRate = 0;
        initializeFleetCommanderWithMockArks(initialTipRate);
        // Deposit for tests
        mockToken.mint(mockUser, DEPOSIT_AMOUNT);
        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), DEPOSIT_AMOUNT);
        fleetCommander.deposit(DEPOSIT_AMOUNT, mockUser);
        vm.stopPrank();
    }

    function test_UserCanRedeemShares() public {
        assertEq(
            DEPOSIT_AMOUNT,
            fleetCommander.balanceOf(mockUser),
            "User has not deposited"
        );

        uint256 redeemAmount = DEPOSIT_AMOUNT / 10;
        vm.prank(mockUser);
        uint256 assets = fleetCommander.redeem(
            redeemAmount,
            mockUser,
            mockUser
        );

        assertEq(
            DEPOSIT_AMOUNT - redeemAmount,
            fleetCommander.balanceOf(mockUser),
            "Incorrect remaining balance"
        );
        assertEq(assets, redeemAmount, "Incorrect assets returned");
    }

    function test_RedeemMultipleTimes() public {
        uint256 redeemAmount = DEPOSIT_AMOUNT / 3;

        vm.startPrank(mockUser);
        fleetCommander.redeem(redeemAmount, mockUser, mockUser);
        fleetCommander.redeem(redeemAmount, mockUser, mockUser);
        fleetCommander.redeem(
            fleetCommander.balanceOf(mockUser),
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

    function test_RedeemZero() public {
        vm.prank(mockUser);
        uint256 redeemedAmount = fleetCommander.redeem(0, mockUser, mockUser);

        assertEq(redeemedAmount, 0, "Should redeem zero amount");
        assertEq(
            fleetCommander.balanceOf(mockUser),
            DEPOSIT_AMOUNT,
            "User balance should remain unchanged"
        );
    }

    function test_RedeemExceedingBalance() public {
        uint256 excessAmount = DEPOSIT_AMOUNT + 1;

        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC4626ExceededMaxRedeem(address,uint256,uint256)",
                mockUser,
                excessAmount,
                fleetCommander.maxRedeem(mockUser)
            )
        );
        vm.prank(mockUser);
        fleetCommander.redeem(excessAmount, mockUser, mockUser);
    }

    function test_RedeemByNonOwner() public {
        uint256 sharesToRedeem = fleetCommander.maxRedeem(mockUser);

        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderUnauthorizedRedemption(address,address)",
                nonOwner,
                mockUser
            )
        );

        vm.prank(nonOwner);
        fleetCommander.redeem(sharesToRedeem, nonOwner, mockUser);
    }

    function test_RedeemByNonOwnerWithSufficientAllowance() public {
        uint256 sharesToRedeem = fleetCommander.maxRedeem(mockUser);

        vm.prank(mockUser);
        fleetCommander.approve(nonOwner, sharesToRedeem);

        vm.prank(nonOwner);
        fleetCommander.redeem(sharesToRedeem, nonOwner, mockUser);
    }

    function test_RedeemByNonOwnerWithInsufficientAllowance() public {
        uint256 sharesToRedeem = fleetCommander.maxRedeem(mockUser);

        vm.prank(mockUser);
        fleetCommander.approve(nonOwner, sharesToRedeem - 2);

        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderUnauthorizedRedemption(address,address)",
                nonOwner,
                mockUser
            )
        );

        vm.prank(nonOwner);
        fleetCommander.redeem(sharesToRedeem - 1, nonOwner, mockUser);
    }

    function test_RedeemToOtherReceiver() public {
        address receiver = nonOwner;
        uint256 redeemAmount = fleetCommander.maxRedeem(mockUser) / 2;

        vm.prank(mockUser);
        fleetCommander.redeem(redeemAmount, receiver, mockUser);

        assertEq(
            mockToken.balanceOf(receiver),
            redeemAmount,
            "Receiver should have received the assets"
        );
        assertEq(
            mockToken.balanceOf(mockUser),
            0,
            "Owner should not have received any assets"
        );
    }

    function test_RedeemToOtherReceiverCalledByNonOwner() public {
        address receiver = address(9999999);
        uint256 redeemAmount = fleetCommander.maxRedeem(mockUser) / 2;

        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderUnauthorizedRedemption(address,address)",
                nonOwner,
                mockUser
            )
        );
        vm.prank(nonOwner);
        fleetCommander.redeem(redeemAmount, receiver, mockUser);

        assertEq(
            mockToken.balanceOf(receiver),
            0,
            "Receiver should not have received the assets"
        );
        assertEq(
            mockToken.balanceOf(mockUser),
            0,
            "Owner should not have received any assets"
        );
    }

    function test_RedeemEventEmission() public {
        uint256 redeemAmount = DEPOSIT_AMOUNT / 2;
        uint256 assets = fleetCommander.previewRedeem(redeemAmount);

        vm.expectEmit(true, true, true, true);
        emit IERC4626.Withdraw(
            mockUser,
            mockUser,
            mockUser,
            assets,
            redeemAmount
        );

        vm.prank(mockUser);
        fleetCommander.redeem(redeemAmount, mockUser, mockUser);
    }

    function test_RedeemUpdatesBufferBalance() public {
        uint256 redeemAmount = fleetCommander.maxRedeem(mockUser) / 2;
        uint256 initialBufferBalance = IArk(fleetCommander.bufferArk())
            .totalAssets();

        vm.prank(mockUser);
        uint256 assets = fleetCommander.redeem(
            redeemAmount,
            mockUser,
            mockUser
        );

        uint256 finalBufferBalance = IArk(fleetCommander.bufferArk())
            .totalAssets();
        assertEq(
            finalBufferBalance,
            initialBufferBalance - assets,
            "Buffer balance should decrease by redeemed assets"
        );
    }

    function test_RedeemWithRebalancedFunds() public {
        uint256 userShares = fleetCommander.balanceOf(mockUser);

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

        uint256 redeemAmount = fleetCommander.maxRedeem(mockUser);
        uint256 assetsAmount = fleetCommander.maxWithdraw(mockUser);

        vm.prank(mockUser);
        fleetCommander.redeem(redeemAmount, mockUser, mockUser);

        assertEq(
            fleetCommander.balanceOf(mockUser),
            userShares - redeemAmount,
            "User should have reduced amount of shares"
        );
        assertEq(
            assetsAmount,
            mockToken.balanceOf(mockUser),
            "User should have received all assets back"
        );
    }

    function test_RedeemAll() public {
        vm.prank(mockUser);
        uint256 redeemedAmount = fleetCommander.redeem(
            type(uint256).max,
            mockUser,
            mockUser
        );

        assertEq(
            redeemedAmount,
            DEPOSIT_AMOUNT,
            "Contract should return correct amount of withdrawn assets"
        );
        assertEq(
            fleetCommander.balanceOf(mockUser),
            0,
            "User should have no remaining shares"
        );
        assertEq(
            mockToken.balanceOf(mockUser),
            DEPOSIT_AMOUNT,
            "User should receive all assets"
        );
    }

    function test_RedeemFromBuffer() public {
        uint256 userShares = fleetCommander.balanceOf(mockUser);
        uint256 redeemShares = fleetCommander.maxRedeem(mockUser) / 2;
        uint256 assetsToWithdraw = fleetCommander.maxWithdraw(mockUser) / 2;

        vm.prank(mockUser);
        uint256 withdrawnAssets = fleetCommander.redeem(
            redeemShares,
            mockUser,
            mockUser
        );

        assertEq(
            withdrawnAssets,
            assetsToWithdraw,
            "Should redeem requested amount from buffer"
        );
        assertEq(
            fleetCommander.balanceOf(mockUser),
            userShares - redeemShares,
            "User should have remaining shares"
        );
        assertEq(
            mockToken.balanceOf(mockUser),
            withdrawnAssets,
            "User should receive redeemed assets"
        );
    }

    function test_RedeemFromArks() public {
        // Move some funds to arks
        vm.startPrank(keeper);
        vm.warp(block.timestamp + INITIAL_REBALANCE_COOLDOWN);
        fleetCommander.rebalance(
            generateRebalanceData(
                address(fleetCommander.bufferArk()),
                ark1,
                DEPOSIT_AMOUNT / 2
            )
        );
        vm.stopPrank();

        uint256 userShares = fleetCommander.balanceOf(mockUser);
        uint256 redeemShares = (fleetCommander.maxRedeem(mockUser) * 3) / 4;
        uint256 assetsToWithdraw = (fleetCommander.maxWithdraw(mockUser) * 3) /
            4;

        vm.prank(mockUser);
        uint256 withdrawnAssets = fleetCommander.redeem(
            redeemShares,
            mockUser,
            mockUser
        );

        assertEq(
            withdrawnAssets,
            assetsToWithdraw,
            "Should redeem requested amount from buffer and arks"
        );
        assertEq(
            fleetCommander.balanceOf(mockUser),
            userShares - redeemShares,
            "User should have remaining shares"
        );
        assertEq(
            mockToken.balanceOf(mockUser),
            assetsToWithdraw,
            "User should receive redeemed assets"
        );
    }

    function test_MaxBufferRedeem() public {
        uint256 maxBufferRedeem = fleetCommander.maxBufferRedeem(mockUser);
        uint256 userShares = fleetCommander.convertToShares(DEPOSIT_AMOUNT);

        assertEq(
            userShares,
            fleetCommander.balanceOf(mockUser),
            "User should have deposited"
        );
        assertEq(
            maxBufferRedeem,
            fleetCommander.convertToShares(DEPOSIT_AMOUNT),
            "Max buffer redeem should equal to depoit shares"
        );

        // Move some funds to arks
        vm.startPrank(keeper);
        vm.warp(block.timestamp + INITIAL_REBALANCE_COOLDOWN);
        fleetCommander.rebalance(
            generateRebalanceData(
                address(fleetCommander.bufferArk()),
                ark1,
                DEPOSIT_AMOUNT / 2
            )
        );
        vm.stopPrank();

        maxBufferRedeem = fleetCommander.maxBufferRedeem(mockUser);
        assertEq(
            maxBufferRedeem,
            userShares / 2,
            "Max buffer redeem should equal remaining buffer amount"
        );
    }

    function test_ValidateForceRedeem() public {
        uint256 userShares = fleetCommander.balanceOf(mockUser);
        // Test unauthorized redemption
        vm.prank(nonOwner);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderUnauthorizedRedemption(address,address)",
                nonOwner,
                mockUser
            )
        );
        fleetCommander.redeemFromArks(DEPOSIT_AMOUNT, nonOwner, mockUser);

        // Test exceeding max redeem
        vm.prank(mockUser);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC4626ExceededMaxRedeem(address,uint256,uint256)",
                mockUser,
                userShares + 1,
                userShares
            )
        );
        fleetCommander.redeemFromArks(DEPOSIT_AMOUNT + 1, mockUser, mockUser);

        // Test successful force redeem
        vm.prank(mockUser);
        uint256 withdrawnAmount = fleetCommander.redeemFromArks(
            userShares,
            mockUser,
            mockUser
        );
        assertEq(
            withdrawnAmount,
            DEPOSIT_AMOUNT,
            "Should force redeem full amount"
        );
    }
}
