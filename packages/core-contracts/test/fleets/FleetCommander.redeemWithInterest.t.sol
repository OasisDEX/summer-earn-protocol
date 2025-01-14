// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {IArk} from "../../src/interfaces/IArk.sol";
import {TestHelpers} from "../helpers/TestHelpers.sol";

import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";

import {IFleetCommanderEvents} from "../../src/events/IFleetCommanderEvents.sol";

import {FleetConfig} from "../../src/types/FleetCommanderTypes.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

contract RedeemWithInterestTest is Test, TestHelpers, FleetCommanderTestBase {
    using PercentageUtils for uint256;

    uint256 constant DEPOSIT_AMOUNT = 1000 * 10 ** 6;
    uint256 constant INTEREST_AMOUNT = 100 * 10 ** 6; // 10% interest
    uint256 depositShares;
    uint256 initialConversionRate;

    function setUp() public {
        uint256 initialTipRate = 0;
        initializeFleetCommanderWithMockArks(initialTipRate);
        FleetConfig memory config = fleetCommander.getConfig();

        // Deposit for tests
        mockToken.mint(mockUser, DEPOSIT_AMOUNT);
        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), DEPOSIT_AMOUNT);
        depositShares = fleetCommander.deposit(DEPOSIT_AMOUNT, mockUser);
        vm.stopPrank();

        initialConversionRate = fleetCommander.convertToAssets(100000);

        // Simulate interest accrual
        mockToken.mint(address(config.bufferArk), INTEREST_AMOUNT);

        vm.prank(governor);
        fleetCommander.setMinimumBufferBalance(0);
    }

    function test_ConversionRateChange() public view {
        uint256 newConversionRate = fleetCommander.convertToAssets(100000);
        assertGt(
            newConversionRate,
            initialConversionRate,
            "Conversion rate should increase after interest accrual"
        );
    }

    function test_RedeemExactlyBufferLimit() public {
        uint256 maxBufferShares = fleetCommander.maxBufferRedeem(mockUser);
        console.log("maxBufferShares", maxBufferShares);

        vm.prank(mockUser);
        uint256 assetsReceived = fleetCommander.redeem(
            maxBufferShares,
            mockUser,
            mockUser
        );

        console.log("assetsReceived", assetsReceived);
        console.log("depositShares", depositShares);

        assertEq(
            mockToken.balanceOf(mockUser),
            assetsReceived,
            "User should receive exact buffer limit assets"
        );
        assertEq(
            fleetCommander.balanceOf(mockUser),
            depositShares - maxBufferShares,
            "User should have remaining shares"
        );
    }

    function test_RedeemBufferPlusOne() public {
        FleetConfig memory config = fleetCommander.getConfig();

        vm.startPrank(keeper);
        vm.warp(block.timestamp + INITIAL_REBALANCE_COOLDOWN);
        fleetCommander.rebalance(
            generateRebalanceData(
                address(config.bufferArk),
                ark1,
                DEPOSIT_AMOUNT / 2
            )
        );
        vm.stopPrank();

        uint256 maxBufferShares = fleetCommander.maxBufferRedeem(mockUser);
        uint256 redeemShares = maxBufferShares + 1;

        vm.expectEmit(true, true, true, true);
        emit IFleetCommanderEvents.FleetCommanderRedeemedFromArks(
            mockUser,
            mockUser,
            redeemShares
        );
        vm.prank(mockUser);
        fleetCommander.redeem(redeemShares, mockUser, mockUser);
    }

    function test_RedeemAllShares() public {
        uint256 totalUserShares = fleetCommander.balanceOf(mockUser);

        vm.prank(mockUser);
        uint256 assetsReceived = fleetCommander.redeem(
            totalUserShares,
            mockUser,
            mockUser
        );

        uint256 remainingAssets = fleetCommander.totalAssets();
        assertEq(
            assetsReceived,
            DEPOSIT_AMOUNT + INTEREST_AMOUNT - remainingAssets,
            "User should receive all assets including interest"
        );
        assertEq(
            fleetCommander.balanceOf(mockUser),
            0,
            "User should have no remaining shares"
        );
    }

    function test_RedeemPartialWithInterest() public {
        uint256 redeemShares = depositShares / 2;

        vm.prank(mockUser);
        uint256 assetsReceived = fleetCommander.redeem(
            redeemShares,
            mockUser,
            mockUser
        );

        assertGt(
            assetsReceived,
            DEPOSIT_AMOUNT / 2,
            "User should receive more assets due to interest"
        );
        assertEq(
            fleetCommander.balanceOf(mockUser),
            depositShares - redeemShares,
            "User should have half shares remaining"
        );
    }

    function test_MaxRedeemUnchangedWithInterest() public view {
        uint256 maxRedeem = fleetCommander.maxRedeem(mockUser);
        assertEq(
            maxRedeem,
            depositShares,
            "Max redeem should be equal to initial deposit shares"
        );
    }

    function test_RedeemAllWithForceRedeem() public {
        uint256 totalUserShares = fleetCommander.balanceOf(mockUser);

        vm.prank(mockUser);
        uint256 assetsReceived = fleetCommander.redeemFromArks(
            totalUserShares,
            mockUser,
            mockUser
        );

        uint256 remainingAssets = fleetCommander.totalAssets();
        assertEq(
            assetsReceived,
            DEPOSIT_AMOUNT + INTEREST_AMOUNT - remainingAssets,
            "User should receive all assets including interest"
        );
        assertEq(
            fleetCommander.balanceOf(mockUser),
            0,
            "User should have no remaining shares"
        );
        console.log(fleetCommander.totalAssets());
    }

    function test_RedeemToOtherReceiverWithInterest() public {
        address receiver = address(0x123);
        uint256 redeemShares = depositShares / 2;

        vm.prank(mockUser);
        uint256 assetsReceived = fleetCommander.redeem(
            redeemShares,
            receiver,
            mockUser
        );

        assertGt(
            assetsReceived,
            DEPOSIT_AMOUNT / 2,
            "Receiver should get more assets due to interest"
        );
        assertEq(
            mockToken.balanceOf(receiver),
            assetsReceived,
            "Receiver should get the assets"
        );
        assertEq(
            mockToken.balanceOf(mockUser),
            0,
            "User should not receive any assets"
        );
    }

    function test_RedeemAfterMultipleInterestAccruals() public {
        // Simulate multiple interest accruals
        for (uint256 i = 0; i < 3; i++) {
            mockToken.mint(ark2, INTEREST_AMOUNT / 3);
        }

        uint256 userShares = fleetCommander.balanceOf(mockUser);

        vm.prank(mockUser);
        uint256 assetsReceived = fleetCommander.redeem(
            userShares,
            mockUser,
            mockUser
        );

        assertGt(
            assetsReceived,
            DEPOSIT_AMOUNT + INTEREST_AMOUNT,
            "User should receive all assets including all interest"
        );
        assertEq(
            fleetCommander.balanceOf(mockUser),
            0,
            "User should have no remaining shares"
        );
    }

    function test_RedeemZeroShares() public {
        vm.prank(mockUser);
        vm.expectRevert(abi.encodeWithSignature("FleetCommanderZeroAmount()"));
        fleetCommander.redeem(0, mockUser, mockUser);

        assertEq(
            fleetCommander.balanceOf(mockUser),
            depositShares,
            "User shares should remain unchanged"
        );
    }

    function test_RedeemExceedingBalance() public {
        uint256 excessShares = depositShares + 1;

        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC4626ExceededMaxRedeem(address,uint256,uint256)",
                mockUser,
                excessShares,
                depositShares
            )
        );
        vm.prank(mockUser);
        fleetCommander.redeem(excessShares, mockUser, mockUser);
    }

    function test_TwoUsersRedeemAllShares() public {
        // Setup second user
        FleetConfig memory config = fleetCommander.getConfig();

        address secondUser = address(0x456);
        mockToken.mint(secondUser, DEPOSIT_AMOUNT);
        vm.startPrank(secondUser);
        mockToken.approve(address(fleetCommander), DEPOSIT_AMOUNT);
        uint256 user2Shares = fleetCommander.deposit(
            DEPOSIT_AMOUNT,
            secondUser
        );
        vm.stopPrank();

        // Simulate more interest accrual
        mockToken.mint(address(config.bufferArk), INTEREST_AMOUNT);

        uint256 totalAssets = fleetCommander.totalAssets();
        uint256 user1Shares = fleetCommander.balanceOf(mockUser);

        // First user redeems
        vm.prank(mockUser);
        uint256 user1AssetsReceived = fleetCommander.redeem(
            user1Shares,
            mockUser,
            mockUser
        );

        // Second user redeems
        vm.prank(secondUser);
        uint256 user2AssetsReceived = fleetCommander.redeem(
            user2Shares,
            secondUser,
            secondUser
        );

        // Verify results
        assertEq(
            fleetCommander.totalAssets() - 1,
            0,
            "FleetCommander should be empty"
        );
        assertEq(fleetCommander.totalSupply(), 0, "No shares should remain");
        assertEq(
            user1AssetsReceived + user2AssetsReceived,
            totalAssets - 1,
            "Users should have redeemed all assets"
        );
        assertEq(
            fleetCommander.balanceOf(mockUser),
            0,
            "First user should have no shares"
        );
        assertEq(
            fleetCommander.balanceOf(secondUser),
            0,
            "Second user should have no shares"
        );
    }
}
