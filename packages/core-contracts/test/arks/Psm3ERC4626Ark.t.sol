// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/Psm3ERC4626Ark.sol";

import {IArkEvents} from "../../src/events/IArkEvents.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";

contract Psm3ERC4626ArkTestFork is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;
    Psm3ERC4626Ark public susdsArk;
    Psm3ERC4626Ark public usdsArk;

    // Known contract addresses on Base
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant USDS = 0x820C137fa70C8691f0e44Dc420a5e53c168921Dc;
    address public constant SUSDS = 0x5875eEE11Cf8398102FdAd704C9E96607675467a;
    address public constant PSM3 = 0x1601843c5E9bC251A3272907010AFa41Fa18347E;
    address public constant SUSDS_VAULT =
        0xB17B070A56043e1a5a1AB7443AfAFDEbcc1168D7;
    address public constant USDS_VAULT =
        0x556d518FDFDCC4027A3A1388699c5E11AC201D8b;

    IERC20 public usdc;
    IERC20 public susds;
    IPsm3 public psm;

    uint256 forkBlock = 29352160; // A recent block number on Base
    uint256 forkId;
    ArkParams params;
    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("base"), forkBlock);

        usdc = IERC20(USDC);
        susds = IERC20(SUSDS);
        psm = IPsm3(PSM3);

        params = ArkParams({
            name: "USDC PSM3 Ark",
            details: "USDC to sUSDS PSM3 Ark on Base",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        susdsArk = new Psm3ERC4626Ark(PSM3, USDS, SUSDS, SUSDS_VAULT, params);

        usdsArk = new Psm3ERC4626Ark(PSM3, USDS, SUSDS, USDS_VAULT, params);

        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(susdsArk), address(commander));
        accessManager.grantCommanderRole(address(usdsArk), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        susdsArk.registerFleetCommander();
        usdsArk.registerFleetCommander();
        vm.stopPrank();

        vm.makePersistent(address(susdsArk));
        vm.makePersistent(USDC);
        vm.makePersistent(SUSDS);
        vm.makePersistent(PSM3);
        vm.makePersistent(address(accessManager));
        vm.makePersistent(USDS_VAULT);
        vm.makePersistent(SUSDS_VAULT);

        vm.label(USDC, "USDC");
        vm.label(USDS, "USDS");
        vm.label(SUSDS, "sUSDS");
        vm.label(PSM3, "PSM3");
        vm.label(USDS_VAULT, "USDS_VAULT");
        vm.label(SUSDS_VAULT, "SUSDS_VAULT");
    }

    function test_Constructor() public {
        // Invalid PSM address
        vm.expectRevert();
        susdsArk = new Psm3ERC4626Ark(
            address(0),
            USDS,
            SUSDS,
            SUSDS_VAULT,
            params
        );

        // Invalid sUSDS address
        vm.expectRevert();
        susdsArk = new Psm3ERC4626Ark(
            PSM3,
            USDS,
            address(0),
            SUSDS_VAULT,
            params
        );

        // Valid constructor
        susdsArk = new Psm3ERC4626Ark(PSM3, USDS, SUSDS, SUSDS_VAULT, params);

        assertEq(address(susdsArk.psm()), PSM3, "PSM address should match");
        assertEq(
            address(susdsArk.susds()),
            SUSDS,
            "sUSDS address should match"
        );
    }

    function test_Board_SUSDS() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(susdsArk), amount);

        uint256 initialArkAssets = susdsArk.totalAssets();

        vm.expectEmit(true, true, true, true);
        emit Boarded(commander, USDC, amount);

        susdsArk.board(amount, bytes(""));
        vm.stopPrank();

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

        vm.warp(block.timestamp + 1 days);

        uint256 initialUsdcBalance = usdc.balanceOf(commander);
        uint256 amountToDisembark = susdsArk.withdrawableTotalAssets();

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

    function test_Board_USDS() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(usdsArk), amount);
        usdsArk.board(amount, bytes(""));
        vm.stopPrank();

        uint256 initialArkAssets = usdsArk.totalAssets();
        assertGt(initialArkAssets, 0, "Ark assets should increase");
    }

    function test_Disembark_USDS() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(usdsArk), amount);
        usdsArk.board(amount, bytes(""));
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        uint256 initialUsdcBalance = usdc.balanceOf(commander);
        uint256 amountToDisembark = usdsArk.withdrawableTotalAssets();

        vm.expectEmit();
        emit Disembarked(commander, USDC, amountToDisembark);

        vm.prank(commander);
        usdsArk.disembark(amountToDisembark, bytes(""));
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
        usdc.forceApprove(address(susdsArk), amount);
        susdsArk.board(amount, bytes(""));
        vm.stopPrank();

        uint256 totalAssets = susdsArk.totalAssets();
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
        usdc.forceApprove(address(susdsArk), amount);
        susdsArk.board(amount, bytes(""));
        vm.stopPrank();

        vm.warp(block.timestamp + 365 days); // Fast forward 1 year

        vm.prank(address(raft));
        (, uint256[] memory rewardAmounts) = susdsArk.harvest("");
        assertEq(
            rewardAmounts[0],
            0,
            "Harvested amount should be 0 for auto-compounding vaults"
        );

        uint256 totalAssetsAfterYear = susdsArk.totalAssets();
        assertGt(
            totalAssetsAfterYear,
            amount,
            "Total assets should have increased after a year"
        );
    }
}
