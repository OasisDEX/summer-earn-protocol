// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/PsmLiteERC4626Ark.sol";

import {IArkEvents} from "../../src/events/IArkEvents.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";

contract PsmLiteERC4626ArkTestFork_Mainnet is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;

    PsmLiteERC4626Ark public ark;

    // Mainnet addresses (from deployment config index.json lines 494-498)
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address public constant SUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    // Sky PSM Lite
    address public constant LITE_PSM =
        0xA188EEC8F81263234dA3622A406892F3D630f98c;
    // Target ERC4626 vault
    address public constant VAULT = 0x99CD4Ec3f88A45940936F469E4bB72A2A701EEB9;

    IERC20 public usdc;
    IPsmLite public psmLite;

    uint256 forkBlock = 23658323; // Requested block number on mainnet
    uint256 forkId;
    ArkParams params;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        usdc = IERC20(USDC);
        psmLite = IPsmLite(LITE_PSM);

        params = ArkParams({
            name: "USDC PSM_LITE Ark (Mainnet 23658323)",
            details: "USDC to USDS/sUSDS via PSM Lite, deposit into ERC4626 vault",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new PsmLiteERC4626Ark(LITE_PSM, USDS, SUSDS, VAULT, params);

        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(ark), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();

        vm.makePersistent(address(ark));
        vm.makePersistent(USDC);
        vm.makePersistent(USDS);
        vm.makePersistent(SUSDS);
        vm.makePersistent(LITE_PSM);
        vm.makePersistent(address(accessManager));
        vm.makePersistent(VAULT);

        vm.label(USDC, "USDC");
        vm.label(USDS, "USDS");
        vm.label(SUSDS, "sUSDS");
        vm.label(LITE_PSM, "LITE_PSM");
        vm.label(VAULT, "ERC4626_VAULT");
    }

    function test_Constructor() public {
        // Invalid PSM address
        vm.expectRevert();
        ark = new PsmLiteERC4626Ark(address(0), USDS, SUSDS, VAULT, params);

        // Invalid sUSDS address
        vm.expectRevert();
        ark = new PsmLiteERC4626Ark(LITE_PSM, USDS, address(0), VAULT, params);

        // Valid constructor
        ark = new PsmLiteERC4626Ark(LITE_PSM, USDS, SUSDS, VAULT, params);

        assertEq(
            address(ark.psmLite()),
            LITE_PSM,
            "PSM Lite address should match"
        );
    }

    function test_Board() public {
        uint256 amount = 1_000 * 1e6; // 1000 USDC
        deal(USDC, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);

        uint256 initialArkAssets = ark.totalAssets();

        vm.expectEmit(true, true, true, true);
        emit Boarded(commander, USDC, amount);

        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 finalArkAssets = ark.totalAssets();
        assertGt(
            finalArkAssets,
            initialArkAssets,
            "Ark assets should increase"
        );
    }

    function test_Disembark() public {
        uint256 amount = 1_000 * 1e6; // 1000 USDC
        deal(USDC, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));

        vm.warp(block.timestamp + 1 days);

        uint256 initialUsdcBalance = usdc.balanceOf(commander);
        uint256 amountToDisembark = ark.withdrawableTotalAssets();

        vm.expectEmit();
        emit Disembarked(commander, USDC, amountToDisembark);

        ark.disembark(amountToDisembark, bytes(""));
        vm.stopPrank();

        uint256 finalUsdcBalance = usdc.balanceOf(commander);
        assertEq(
            finalUsdcBalance,
            initialUsdcBalance + amountToDisembark,
            "USDC balance should increase by disembarked amount"
        );
    }

    function test_TotalAssets() public {
        uint256 amount = 1_000 * 1e6; // 1000 USDC
        deal(USDC, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 totalAssets = ark.totalAssets();
        assertGt(totalAssets, 0, "Total assets should be positive");
    }

    function test_Harvest() public {
        uint256 amount = 1_000 * 1e6; // 1000 USDC
        deal(USDC, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        vm.warp(block.timestamp + 365 days); // Fast forward 1 year

        vm.prank(address(raft));
        (, uint256[] memory rewardAmounts) = ark.harvest("");
        assertEq(rewardAmounts[0], 0, "Harvested amount should be 0");

        uint256 totalAssetsAfterYear = ark.totalAssets();
        assertGt(totalAssetsAfterYear, amount, "Total assets should increase");
    }
}
