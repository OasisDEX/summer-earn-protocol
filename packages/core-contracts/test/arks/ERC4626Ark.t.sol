// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";

import "../../src/contracts/arks/ERC4626Ark.sol";
import "../../src/events/IArkEvents.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";

import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";

import {ArkTestBase} from "./ArkTestBase.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";

contract ERC4626ArkTestFork is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;
    ERC4626Ark public ark;
    IERC4626 public vault;
    IERC20 public usdt;
    ArkParams public params;

    address public constant VAULT_ADDRESS =
        0x05A811275fE9b4DE503B3311F51edF6A856D936e;
    address public constant USDT_ADDRESS =
        0xdAC17F958D2ee523a2206206994597C13D831ec7;

    uint256 forkBlock = 21666256; // A recent block number
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        usdt = IERC20(USDT_ADDRESS);
        vault = IERC4626(VAULT_ADDRESS);

        params = ArkParams({
            name: "USDT ERC4626 Ark",
            details: "USDT ERC4626 Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDT_ADDRESS,
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

    function test_Constructor() public {
        // Invalid vault address
        vm.expectRevert(abi.encodeWithSignature("InvalidVaultAddress()"));
        ark = new ERC4626Ark(address(0), params);

        // Asset mismatch
        vm.mockCall(
            VAULT_ADDRESS,
            abi.encodeWithSelector(IERC4626.asset.selector),
            abi.encode(address(9))
        );
        vm.expectRevert(abi.encodeWithSignature("ERC4626AssetMismatch()"));
        ark = new ERC4626Ark(VAULT_ADDRESS, params);
        vm.clearMockedCalls();

        // Valid constructor
        ark = new ERC4626Ark(VAULT_ADDRESS, params);

        assertEq(
            address(ark.vault()),
            VAULT_ADDRESS,
            "Vault address should match"
        );
        assertEq(
            address(ark.asset()),
            USDT_ADDRESS,
            "Token address should match USDT"
        );
        assertEq(ark.name(), "USDT ERC4626 Ark", "Ark name should match");
    }

    function test_Board() public {
        uint256 amount = 1000 * 1e6; // 1000 USDT
        deal(USDT_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdt.forceApprove(address(ark), amount);

        uint256 initialVaultBalance = vault.balanceOf(address(ark));

        vm.expectEmit(true, true, true, true);
        emit Boarded(commander, USDT_ADDRESS, amount);

        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 finalVaultBalance = vault.balanceOf(address(ark));
        assertGt(
            finalVaultBalance,
            initialVaultBalance,
            "Vault balance should increase"
        );
    }

    function test_Disembark() public {
        uint256 amount = 1000 * 1e6; // 1000 USDT
        deal(USDT_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdt.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));

        uint256 initialUSDCBalance = usdt.balanceOf(commander);
        uint256 amountToDisembark = IERC4626(VAULT_ADDRESS).maxWithdraw(
            address(ark)
        );

        vm.expectEmit();
        emit Disembarked(commander, USDT_ADDRESS, amountToDisembark);

        ark.disembark(amountToDisembark, bytes(""));
        vm.stopPrank();

        uint256 finalUSDCBalance = usdt.balanceOf(commander);
        assertEq(
            finalUSDCBalance,
            initialUSDCBalance + amountToDisembark,
            "USDT balance should increase by disembarked amount"
        );
    }

    function test_TotalAssets() public {
        uint256 amount = 1000 * 1e6; // 1000 USDT
        deal(USDT_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdt.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 totalAssets = ark.totalAssets();
        assertApproxEqRel(
            totalAssets,
            amount,
            1e10,
            "Total assets should be at least the deposited amount"
        );
    }

    function test_Harvest() public {
        uint256 amount = 1000 * 1e6; // 1000 USDT
        deal(USDT_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdt.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        vm.warp(block.timestamp + 365 days); // Fast forward 1 year

        vm.prank(address(raft));
        (, uint256[] memory rewardAmounts) = ark.harvest("");
        assertEq(
            rewardAmounts[0],
            0,
            "Harvested amount should be 0 for auto-compounding vaults"
        );

        uint256 totalAssetsAfterYear = ark.totalAssets();
        assertGt(
            totalAssetsAfterYear,
            amount,
            "Total assets should have increased after a year"
        );
    }
}
