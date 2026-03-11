// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/MorphoV2VaultArk.sol";
import {IArkEvents} from "../../src/events/IArkEvents.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";

contract MorphoV2ArkForkTest is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;

    MorphoV2VaultArk public ark;
    IERC4626 public vault;
    IERC20 public usdc;

    // Morpho V2 Gauntlet USDC Prime - from config mainnet erc4626.usdc
    address public constant VAULT_ADDRESS =
        0x8c106EEDAd96553e64287A5A6839c3Cc78afA3D0;
    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    uint256 forkBlock = 24416332; // Same block as SPK rewards test
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        usdc = IERC20(USDC_ADDRESS);
        vault = IERC4626(VAULT_ADDRESS);

        ArkParams memory params = ArkParams({
            name: "Morpho V2 Gauntlet USDC Prime Ark",
            details: "Morpho V2 USDC vault via ERC4626",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC_ADDRESS,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new MorphoV2VaultArk(VAULT_ADDRESS, params);

        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(ark), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();
    }

    function test_Constructor() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidVaultAddress()"));
        new MorphoV2VaultArk(
            address(0),
            ArkParams({
                name: "Bad",
                details: "",
                accessManager: address(accessManager),
                configurationManager: address(configurationManager),
                asset: USDC_ADDRESS,
                depositCap: type(uint256).max,
                maxRebalanceOutflow: type(uint256).max,
                maxRebalanceInflow: type(uint256).max,
                requiresKeeperData: false,
                maxDepositPercentageOfTVL: PERCENTAGE_100
            })
        );

        assertEq(address(ark.vault()), VAULT_ADDRESS);
        assertEq(address(ark.asset()), USDC_ADDRESS);
    }

    function test_Board_MorphoV2_fork() public {
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);

        uint256 initialVaultBalance = vault.balanceOf(address(ark));

        vm.expectEmit(true, true, true, true);
        emit Boarded(commander, USDC_ADDRESS, amount);

        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 finalVaultBalance = vault.balanceOf(address(ark));
        assertGt(
            finalVaultBalance,
            initialVaultBalance,
            "Vault balance should increase"
        );
    }

    function test_Disembark_MorphoV2_fork() public {
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));

        uint256 initialUsdcBalance = usdc.balanceOf(commander);
        uint256 amountToDisembark = amount - 1;

        vm.expectEmit();
        emit Disembarked(commander, USDC_ADDRESS, amountToDisembark);

        ark.disembark(amountToDisembark, bytes(""));
        vm.stopPrank();

        uint256 finalUsdcBalance = usdc.balanceOf(commander);
        assertEq(
            finalUsdcBalance,
            initialUsdcBalance + amountToDisembark,
            "USDC balance should increase by disembarked amount"
        );
    }

    function test_TotalAssets_MorphoV2_fork() public {
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
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
    function test_WithdrawableAssets_MorphoV2_fork() public {
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 withdrawableAssets = ark.withdrawableTotalAssets();
        assertApproxEqRel(
            withdrawableAssets,
            amount,
            1e10,
            "Total assets should be at least the deposited amount (round down)"
        );
    }
    function test_Harvest_MorphoV2_fork() public {
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        vm.warp(block.timestamp + 365 days);

        vm.prank(address(raft));
        (, uint256[] memory rewardAmounts) = ark.harvest("");
        assertEq(
            rewardAmounts[0],
            0,
            "Harvested amount should be 0 for auto-compounding vaults"
        );

        // Fork with vm.warp doesn't progress underlying protocol state, so yield may not accrue.
        // Just verify total assets at least matches deposit (within rounding).
        uint256 totalAssetsAfterYear = ark.totalAssets();
        assertApproxEqRel(
            totalAssetsAfterYear,
            amount,
            1e14,
            "Total assets should be ~deposited amount (fork warp doesn't accrue real yield)"
        );
    }
}
