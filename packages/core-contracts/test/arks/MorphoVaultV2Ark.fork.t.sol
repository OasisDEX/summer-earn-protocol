// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ConfigurationManager} from "@summerfi/config-contracts/contracts/ConfigurationManager.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Test, console} from "forge-std/Test.sol";

import {ConfigurationManagerParams} from "@summerfi/config-contracts/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";

import "../../src/contracts/arks/ERC4626Ark.sol";
import "../../src/events/IArkEvents.sol";

import {IArk} from "../../src/interfaces/IArk.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MorphoVaultV2ArkTestFork is Test, IArkEvents, ArkTestBase {
    ERC4626Ark public ark;

    address public constant VAULT_ADDRESS =
        0x9a1D6bd5b8642C41F25e0958129B85f8E1176F3e;
    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    IERC4626 public vault;
    IERC20 public asset;
    uint256 forkBlock = 24296733; // Block number on mainnet
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        vault = IERC4626(VAULT_ADDRESS);
        asset = IERC20(vault.asset());

        ArkParams memory params = ArkParams({
            name: "MorphoVaultV2TestArk",
            details: "MorphoVaultV2TestArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(asset),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new ERC4626Ark(VAULT_ADDRESS, params);

        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(address(ark)),
            address(commander)
        );
        vm.stopPrank();

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();
    }

    function test_Board_MorphoVaultV2Ark_fork() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 6;
        deal(address(asset), commander, amount);

        vm.startPrank(commander);
        asset.approve(address(ark), amount);

        // Expect the deposit call to ERC4626 vault
        vm.expectCall(
            VAULT_ADDRESS,
            abi.encodeWithSelector(
                IERC4626.deposit.selector,
                amount,
                address(ark)
            )
        );

        // Expect the Boarded event to be emitted
        vm.expectEmit();
        emit Boarded(commander, address(asset), amount);

        // Act
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Assert
        uint256 assetsAfterDeposit = ark.totalAssets();
        assertApproxEqRel(
            assetsAfterDeposit,
            amount,
            1e10, // 0.00000001% tolerance
            "Total assets should equal deposited amount"
        );

        // Warp time to simulate interest accrual
        vm.warp(block.timestamp + 1 days);

        uint256 assetsAfterAccrual = ark.totalAssets();
        assertTrue(
            assetsAfterAccrual >= assetsAfterDeposit,
            "Assets should not decrease after accrual"
        );
    }

    function test_Disembark_MorphoVaultV2Ark_fork() public {
        // First, board some assets
        test_Board_MorphoVaultV2Ark_fork();

        uint256 initialBalance = asset.balanceOf(commander);
        uint256 amountToWithdraw = 500 * 10 ** 6;

        vm.prank(commander);

        // Expect the withdraw call to ERC4626 vault
        vm.expectCall(
            VAULT_ADDRESS,
            abi.encodeWithSelector(
                IERC4626.withdraw.selector,
                amountToWithdraw,
                address(ark),
                address(ark)
            )
        );

        // Expect the Disembarked event to be emitted
        vm.expectEmit();
        emit Disembarked(commander, address(asset), amountToWithdraw);

        ark.disembark(amountToWithdraw, bytes(""));

        uint256 finalBalance = asset.balanceOf(commander);
        assertApproxEqRel(
            finalBalance - initialBalance,
            amountToWithdraw,
            1e10, // 0.00000001% tolerance
            "Commander should receive withdrawn amount"
        );

        uint256 remainingAssets = ark.totalAssets();
        assertTrue(
            remainingAssets < 1000 * 10 ** 6,
            "Remaining assets should be less than initial deposit"
        );
    }

    function test_TotalAssets_MorphoVaultV2Ark_fork() public {
        // Deposit some assets first
        test_Board_MorphoVaultV2Ark_fork();

        uint256 initialTotalAssets = ark.totalAssets();

        // Warp time to simulate interest accrual
        vm.warp(block.timestamp + 30 days);

        uint256 newTotalAssets = ark.totalAssets();

        // Total assets should not decrease over time (assuming no withdrawals)
        assertTrue(
            newTotalAssets >= initialTotalAssets,
            "Total assets should increase or stay the same over time"
        );
    }

    function test_WithdrawableAssets_MorphoVaultV2Ark_fork() public {
        // Arrange - deposit some assets first
        uint256 amount = 1000 * 10 ** 6;
        deal(address(asset), commander, amount);

        // Check withdrawable assets before deposit (should be 0)
        uint256 withdrawableBefore = ark.withdrawableTotalAssets();
        assertEq(
            withdrawableBefore,
            0,
            "Withdrawable assets should be 0 before deposit"
        );

        vm.startPrank(commander);
        asset.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Assert - withdrawable assets should be above 0 after deposit
        uint256 withdrawableAfter = ark.withdrawableTotalAssets();
        assertTrue(
            withdrawableAfter > 0,
            "Withdrawable assets should be above 0 after deposit"
        );

        // For ERC4626Ark, withdrawable assets should be approximately equal to total assets
        // (since ERC4626 vaults are typically fully withdrawable)
        uint256 totalAssets = ark.totalAssets();
        assertApproxEqRel(
            withdrawableAfter,
            totalAssets,
            1e10, // 0.00000001% tolerance
            "Withdrawable assets should be approximately equal to total assets for ERC4626 vaults"
        );
    }

    function test_Constructor_MorphoVaultV2Ark_AddressZero_fork() public {
        // Arrange
        ArkParams memory params = ArkParams({
            name: "TestArk",
            details: "TestArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(asset),
            depositCap: 1000,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        // Act
        vm.expectRevert(abi.encodeWithSignature("InvalidVaultAddress()"));
        new ERC4626Ark(address(0), params);
    }

    function test_Harvest_MorphoVaultV2Ark_fork() public {
        // Arrange - deposit some assets first
        uint256 amount = 1000 * 10 ** 6;
        deal(address(asset), commander, amount);

        vm.startPrank(commander);
        asset.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Warp time to simulate interest accrual
        vm.warp(block.timestamp + 365 days);

        // Act - harvest (ERC4626Ark harvest is a no-op for auto-compounding vaults)
        vm.prank(address(raft));
        (address[] memory rewardTokens, uint256[] memory rewardAmounts) = ark
            .harvest("");

        // Assert - ERC4626Ark returns empty rewards for auto-compounding vaults
        assertEq(
            rewardTokens.length,
            1,
            "Should return one reward token entry"
        );
        assertEq(
            rewardAmounts.length,
            1,
            "Should return one reward amount entry"
        );
        assertEq(
            rewardTokens[0],
            address(0),
            "Reward token should be zero address for auto-compounding"
        );
        assertEq(
            rewardAmounts[0],
            0,
            "Reward amount should be zero for auto-compounding"
        );

        // Verify that assets have increased due to auto-compounding
        uint256 totalAssetsAfterYear = ark.totalAssets();
        assertTrue(
            totalAssetsAfterYear >= amount,
            "Total assets should have increased after a year due to auto-compounding"
        );
    }
}
