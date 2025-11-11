// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/PsmLiteERC4626Ark.sol";

import {IArkEvents} from "../../src/events/IArkEvents.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";

contract PsmLiteERC4626ArkTestFork is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;
    PsmLiteERC4626Ark public usdsArk;
    PsmLiteERC4626Ark public susdsArk;

    // Known contract addresses on Base
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address public constant SUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address public constant LITE_PSM =
        0xA188EEC8F81263234dA3622A406892F3D630f98c;
    address public constant USDS_VAULT =
        0x07F9A54Dc5135B9878d6745E267625BF0E206840;
    address public constant SUSDS_VAULT =
        0x1cA03621265D9092dC0587e1b50aB529f744aacB;

    IERC20 public usdc;
    IERC20 public susds;
    IPsmLite public psmLite;

    uint256 forkBlock = 22338830; // A recent block number on Base
    uint256 forkId;
    ArkParams params;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        usdc = IERC20(USDC);
        susds = IERC20(SUSDS);
        psmLite = IPsmLite(LITE_PSM);

        params = ArkParams({
            name: "USDC LITE_PSM Ark",
            details: "USDC to sUSDS LITE_PSM Ark on Base",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        usdsArk = new PsmLiteERC4626Ark(
            LITE_PSM,
            USDS,
            SUSDS,
            USDS_VAULT,
            params
        );

        susdsArk = new PsmLiteERC4626Ark(
            LITE_PSM,
            USDS,
            SUSDS,
            SUSDS_VAULT,
            params
        );

        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(usdsArk), address(commander));
        accessManager.grantCommanderRole(address(susdsArk), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        usdsArk.registerFleetCommander();
        susdsArk.registerFleetCommander();
        vm.stopPrank();

        vm.makePersistent(address(usdsArk));
        vm.makePersistent(USDC);
        vm.makePersistent(USDS);
        vm.makePersistent(SUSDS);
        vm.makePersistent(LITE_PSM);
        vm.makePersistent(address(accessManager));
        vm.makePersistent(USDS_VAULT);
        vm.makePersistent(SUSDS_VAULT);

        vm.label(USDC, "USDC");
        vm.label(USDS, "USDS");
        vm.label(SUSDS, "sUSDS");
        vm.label(LITE_PSM, "LITE_PSM");
        vm.label(USDS_VAULT, "USDS_VAULT");
        vm.label(SUSDS_VAULT, "SUSDS_VAULT");
    }

    function test_Constructor() public {
        // Invalid PSM address
        vm.expectRevert();
        usdsArk = new PsmLiteERC4626Ark(
            address(0),
            USDS,
            SUSDS,
            USDS_VAULT,
            params
        );

        // Invalid sUSDS address
        vm.expectRevert();
        usdsArk = new PsmLiteERC4626Ark(
            LITE_PSM,
            USDS,
            address(0),
            USDS_VAULT,
            params
        );

        // Valid constructor
        usdsArk = new PsmLiteERC4626Ark(
            LITE_PSM,
            USDS,
            SUSDS,
            USDS_VAULT,
            params
        );

        assertEq(
            address(usdsArk.psmLite()),
            LITE_PSM,
            "PSM address should match"
        );
        assertEq(address(usdsArk.susds()), SUSDS, "sUSDS address should match");
    }

    function test_Board_USDS() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(usdsArk), amount);

        uint256 initialArkAssets = usdsArk.totalAssets();

        vm.expectEmit(true, true, true, true);
        emit Boarded(commander, USDC, amount);

        usdsArk.board(amount, bytes(""));
        vm.stopPrank();

        uint256 finalArkAssets = usdsArk.totalAssets();
        assertGt(
            finalArkAssets,
            initialArkAssets,
            "Ark assets should increase"
        );
    }

    function test_Disembark_USDS() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(usdsArk), amount);
        usdsArk.board(amount, bytes(""));
        vm.warp(block.timestamp + 1 days);
        uint256 initialUsdcBalance = usdc.balanceOf(commander);
        uint256 amountToDisembark = usdsArk.withdrawableTotalAssets();

        vm.expectEmit();
        emit Disembarked(commander, USDC, amountToDisembark);

        usdsArk.disembark(amountToDisembark, bytes(""));
        vm.stopPrank();

        uint256 finalUsdcBalance = usdc.balanceOf(commander);
        assertEq(
            finalUsdcBalance,
            initialUsdcBalance + amountToDisembark,
            "USDC balance should increase by disembarked amount"
        );
    }

    function test_Board_SUSDS() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(susdsArk), amount);
        susdsArk.board(amount, bytes(""));
        vm.stopPrank();

        uint256 initialArkAssets = susdsArk.totalAssets();

        vm.warp(block.timestamp + 1 days);

        uint256 finalArkAssets = susdsArk.totalAssets();
        assertGt(
            finalArkAssets,
            initialArkAssets,
            "Ark assets should increase"
        );
    }

    function test_Disembark_SUSDS() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(susdsArk), amount);
        susdsArk.board(amount, bytes(""));
        vm.warp(block.timestamp + 2 days);

        uint256 initialUsdcBalance = usdc.balanceOf(commander);
        uint256 amountToDisembark = susdsArk.withdrawableTotalAssets();
        console.log("amountToDisembark", amountToDisembark);

        vm.expectEmit();
        emit Disembarked(commander, USDC, amountToDisembark);

        susdsArk.disembark(amountToDisembark, bytes(""));
        vm.stopPrank();

        uint256 finalUsdcBalance = usdc.balanceOf(commander);
        assertEq(
            finalUsdcBalance,
            initialUsdcBalance + amountToDisembark,
            "USDC balance should increase by disembarked amount"
        );
    }

    function test_TotalAssets() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(usdsArk), amount);
        usdsArk.board(amount, bytes(""));
        vm.stopPrank();

        uint256 totalAssets = usdsArk.totalAssets();
        assertApproxEqRel(
            totalAssets,
            amount,
            1e10,
            "Total assets should be at least the deposited amount"
        );
    }

    function test_Harvest() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(usdsArk), amount);
        usdsArk.board(amount, bytes(""));
        vm.stopPrank();

        vm.warp(block.timestamp + 365 days); // Fast forward 1 year

        vm.prank(address(raft));
        (, uint256[] memory rewardAmounts) = usdsArk.harvest("");
        assertEq(
            rewardAmounts[0],
            0,
            "Harvested amount should be 0 for auto-compounding vaults"
        );

        uint256 totalAssetsAfterYear = usdsArk.totalAssets();
        assertGt(
            totalAssetsAfterYear,
            amount,
            "Total assets should have increased after a year"
        );
    }
}
