// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {IArk} from "../../src/interfaces/IArk.sol";
import {TestHelpers} from "../helpers/TestHelpers.sol";

import {IArk} from "../../src/interfaces/IArk.sol";

import {FleetConfig} from "../../src/types/FleetCommanderTypes.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";
import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

contract MintTest is Test, TestHelpers, FleetCommanderTestBase {
    uint256 constant MINT_AMOUNT = 1000 * 10 ** 6;
    uint256 constant MAX_DEPOSIT_CAP = 100000 * 10 ** 6;

    function setUp() public {
        uint256 initialTipRate = 0;
        initializeFleetCommanderWithMockArks(initialTipRate);
        fleetCommanderStorageWriter.setDepositCap(MAX_DEPOSIT_CAP);
    }

    function test_Mint() public {
        uint256 shares = MINT_AMOUNT;
        uint256 assets = fleetCommander.previewMint(shares);
        mockToken.mint(mockUser, assets);

        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), assets);
        uint256 mintedAssets = fleetCommander.mint(shares, mockUser);
        vm.stopPrank();

        assertEq(
            shares,
            fleetCommander.balanceOf(mockUser),
            "User should have received correct shares"
        );
        assertEq(assets, mintedAssets, "Minted assets should match preview");
    }

    function test_MintZeroShares() public {
        vm.prank(mockUser);
        vm.expectRevert(abi.encodeWithSignature("FleetCommanderZeroAmount()"));
        fleetCommander.mint(0, mockUser);
    }

    function test_MintToOtherReceiver() public {
        address receiver = address(0xdeadbeef);
        uint256 shares = MINT_AMOUNT;
        uint256 assets = fleetCommander.previewMint(shares);

        mockToken.mint(mockUser, assets);
        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), assets);
        fleetCommander.mint(shares, receiver);
        vm.stopPrank();

        assertEq(
            fleetCommander.balanceOf(receiver),
            shares,
            "Receiver should have received the shares"
        );
        assertEq(
            fleetCommander.balanceOf(mockUser),
            0,
            "Minter should not have received any shares"
        );
    }

    function test_MintMultipleTimes() public {
        uint256 shares = MINT_AMOUNT;
        uint256 assets = fleetCommander.previewMint(shares);
        mockToken.mint(mockUser, assets * 3);

        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), assets * 3);

        fleetCommander.mint(shares, mockUser);
        fleetCommander.mint(shares, mockUser);
        fleetCommander.mint(shares, mockUser);

        vm.stopPrank();

        assertEq(
            fleetCommander.balanceOf(mockUser),
            shares * 3,
            "User should have received correct total shares"
        );
    }

    function test_MintExceedingAllowance() public {
        uint256 shares = MINT_AMOUNT;
        uint256 assets = fleetCommander.previewMint(shares);
        uint256 allowance = assets / 2;

        mockToken.mint(mockUser, assets);
        vm.prank(mockUser);
        mockToken.approve(address(fleetCommander), allowance);

        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientAllowance(address,uint256,uint256)",
                address(fleetCommander),
                allowance,
                assets
            )
        );
        vm.prank(mockUser);
        fleetCommander.mint(shares, mockUser);
    }

    function test_MintExceedingBalance() public {
        uint256 shares = MINT_AMOUNT;
        uint256 assets = fleetCommander.previewMint(shares);
        uint256 balance = assets / 2;

        mockToken.mint(mockUser, balance);
        vm.prank(mockUser);
        mockToken.approve(address(fleetCommander), assets);

        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC4626ExceededMaxMint(address,uint256,uint256)",
                mockUser,
                assets,
                balance
            )
        );

        vm.prank(mockUser);
        fleetCommander.mint(shares, mockUser);
    }

    function test_MintUpToDepositCap() public {
        uint256 depositCap = MAX_DEPOSIT_CAP / 2;
        fleetCommanderStorageWriter.setDepositCap(depositCap);

        uint256 shares = depositCap;
        uint256 assets = fleetCommander.previewMint(shares);

        mockToken.mint(mockUser, assets);
        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), assets);
        fleetCommander.mint(shares, mockUser);
        vm.stopPrank();

        assertEq(
            fleetCommander.balanceOf(mockUser),
            shares,
            "User should have received correct shares"
        );
    }

    function test_MintExceedingDepositCap() public {
        uint256 depositCap = MAX_DEPOSIT_CAP / 2;
        fleetCommanderStorageWriter.setDepositCap(depositCap);

        uint256 shares = depositCap + 1;
        uint256 assets = fleetCommander.previewMint(shares);

        mockToken.mint(mockUser, assets);
        vm.prank(mockUser);
        mockToken.approve(address(fleetCommander), assets);

        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC4626ExceededMaxMint(address,uint256,uint256)",
                mockUser,
                shares,
                depositCap
            )
        );
        vm.prank(mockUser);
        fleetCommander.mint(shares, mockUser);
    }

    function test_MintEventEmission() public {
        uint256 shares = MINT_AMOUNT;
        uint256 assets = fleetCommander.previewMint(shares);
        mockToken.mint(mockUser, assets);

        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), assets);

        vm.expectEmit(true, true, true, true);
        emit IERC4626.Deposit(mockUser, mockUser, assets, shares);
        fleetCommander.mint(shares, mockUser);

        vm.stopPrank();
    }

    function test_MintUpdatesBufferBalance() public {
        uint256 shares = MINT_AMOUNT;
        uint256 assets = fleetCommander.previewMint(shares);
        mockToken.mint(mockUser, assets);

        FleetConfig memory config = fleetCommander.getConfig();
        uint256 initialBufferBalance = config.bufferArk.totalAssets();

        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), assets);
        fleetCommander.mint(shares, mockUser);
        vm.stopPrank();

        uint256 finalBufferBalance = config.bufferArk.totalAssets();
        assertEq(
            finalBufferBalance,
            initialBufferBalance + assets,
            "Buffer balance should increase by minted assets"
        );
    }

    function test_RedeemExceedingBalance() public {
        uint256 excessAmount = 1000000000000 ether;

        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC4626ExceededMaxMint(address,uint256,uint256)",
                mockUser,
                excessAmount,
                fleetCommander.maxMint(mockUser)
            )
        );
        vm.prank(mockUser);
        fleetCommander.mint(excessAmount, mockUser);
    }

    function test_Mint_withTip() public {
        uint256 shares = MINT_AMOUNT;

        _mockArkTotalAssets(ark1, 0);
        _mockArkTotalAssets(ark2, 0);

        fleetCommanderStorageWriter.setTipRate(1e18);

        // First mint to establish initial state
        uint256 assets = fleetCommander.previewMint(shares);
        mockToken.mint(mockUser, assets * 10);

        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), assets);
        fleetCommander.mint(shares, mockUser);

        // Advance time to accrue tip
        vm.warp(block.timestamp + 10 days);

        // Second mint after tip accrual
        uint256 previewedAssets = fleetCommander.previewMint(shares);

        mockToken.approve(address(fleetCommander), previewedAssets);

        uint256 sharesBefore = fleetCommander.balanceOf(mockUser);
        uint256 mintedAssets = fleetCommander.mint(shares, mockUser);
        uint256 sharesAfter = fleetCommander.balanceOf(mockUser);
        vm.stopPrank();
        assertEq(
            mintedAssets,
            previewedAssets,
            "Minted assets should match preview"
        );
        assertEq(
            sharesAfter,
            sharesBefore + shares,
            "Shares should increase by minted shares"
        );
    }
}
