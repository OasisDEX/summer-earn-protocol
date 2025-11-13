// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/SiUSDArk.sol";
import {IInfiniFiGateway} from "../../src/interfaces/infinifi/IInfiniFiGateway.sol";

import {IArkEvents} from "../../src/events/IArkEvents.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/**
 * @title SiUSDArkTestFork
 * @notice Mainnet fork tests for SiUSDArk
 *
 * ✅ These tests use the real InfiniFi Gateway contract deployed on mainnet
 */
contract SiUSDArkTestFork is Test, IArkEvents, ArkTestBase {
    SiUSDArk public ark;

    // Known contract addresses on mainnet
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant IUSD = 0x48f9e38f3070AD8945DFEae3FA70987722E3D89c;
    address public constant SIUSD_VAULT =
        0xDBDC1Ef57537E34680B898E1FEBD3D68c7389bCB;

    // InfiniFi Gateway V2 - the actual contract we interact with
    address public constant INFINIFI_GATEWAY =
        0x3f04b65Ddbd87f9CE0A2e7Eb24d80e7fb87625b5;

    IERC20 public usdc;
    IERC20 public iusd;
    IERC4626 public siusdVault;

    uint256 forkBlock = 23400000; // Block where siUSD contracts are deployed
    uint256 futureBlock = 23450000;
    uint256 forkId;

    function setUp() public {
        // Create fork first
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        // Then initialize contracts on the fork
        initializeCoreContracts();

        usdc = IERC20(USDC);
        iusd = IERC20(IUSD);
        siusdVault = IERC4626(SIUSD_VAULT);

        ArkParams memory params = ArkParams({
            name: "SiUSDArk",
            details: "USDC to siUSD Ark via InfiniFi",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        // Deploy the ark with the real InfiniFi Gateway
        ark = new SiUSDArk(INFINIFI_GATEWAY, SIUSD_VAULT, params);

        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(ark), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();

        vm.makePersistent(address(ark));
        vm.makePersistent(USDC);
        vm.makePersistent(IUSD);
        vm.makePersistent(SIUSD_VAULT);
        vm.makePersistent(INFINIFI_GATEWAY);
        vm.makePersistent(address(accessManager));
    }

    function test_Constructor() public {
        ArkParams memory params = ArkParams({
            name: "SiUSDArk",
            details: "Test Ark",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        // Test invalid Gateway address
        vm.expectRevert(abi.encodeWithSignature("InvalidGatewayAddress()"));
        new SiUSDArk(address(0), SIUSD_VAULT, params);

        // Test invalid siUSD address
        vm.expectRevert(abi.encodeWithSignature("InvalidSiUSDAddress()"));
        new SiUSDArk(INFINIFI_GATEWAY, address(0), params);

        // Test valid constructor
        SiUSDArk testArk = new SiUSDArk(INFINIFI_GATEWAY, SIUSD_VAULT, params);

        assertEq(
            address(testArk.gateway()),
            INFINIFI_GATEWAY,
            "Gateway address should match"
        );
        assertEq(
            address(testArk.siUSD()),
            SIUSD_VAULT,
            "siUSD address should match"
        );
        assertEq(address(testArk.asset()), USDC, "Asset should be USDC");
    }

    function test_Integration_Board() public {
        // Test with real InfiniFi gateway contract
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(address(usdc), commander, amount);

        vm.startPrank(commander);
        usdc.approve(address(ark), amount);

        uint256 totalAssetsBefore = ark.totalAssets();

        // Board USDC through real InfiniFi gateway
        ark.board(amount, bytes(""));

        uint256 totalAssetsAfter = ark.totalAssets();

        // Assert that we have assets after boarding
        assertGt(
            totalAssetsAfter,
            totalAssetsBefore,
            "Should have more assets after boarding"
        );
        assertGt(totalAssetsAfter, 0, "Should have assets after boarding");

        vm.stopPrank();
    }

    function test_Integration_BoardAndDisembark() public {
        // Test full lifecycle: board USDC -> get siUSD -> disembark back to USDC
        uint256 boardAmount = 1000 * 10 ** 6; // 1000 USDC
        deal(address(usdc), commander, boardAmount);

        vm.startPrank(commander);
        usdc.approve(address(ark), boardAmount);

        // Initial state
        uint256 commanderUsdcBefore = usdc.balanceOf(commander);
        uint256 totalAssetsBefore = ark.totalAssets();

        // BOARD: Deposit USDC into the ark
        ark.board(boardAmount, bytes(""));

        uint256 totalAssetsAfterBoard = ark.totalAssets();
        uint256 commanderUsdcAfterBoard = usdc.balanceOf(commander);

        // Verify boarding worked
        assertGt(
            totalAssetsAfterBoard,
            totalAssetsBefore,
            "Total assets should increase after boarding"
        );
        assertEq(
            commanderUsdcBefore - commanderUsdcAfterBoard,
            boardAmount,
            "Commander should have spent the board amount"
        );

        // Roll forward some blocks to simulate time passing and potential yield accrual
        vm.rollFork(futureBlock);

        uint256 totalAssetsBeforeDisembark = ark.totalAssets();

        // DISEMBARK: Withdraw back to USDC
        // Disembark all assets
        ark.disembark(totalAssetsBeforeDisembark, bytes(""));

        uint256 totalAssetsAfterDisembark = ark.totalAssets();
        uint256 commanderUsdcAfterDisembark = usdc.balanceOf(commander);

        // Verify disembark worked
        assertLt(
            totalAssetsAfterDisembark,
            totalAssetsBeforeDisembark,
            "Total assets should decrease after disembark"
        );
        assertGt(
            commanderUsdcAfterDisembark,
            commanderUsdcAfterBoard,
            "Commander should have received USDC back"
        );

        // The amount received should be approximately the amount boarded
        // (might be slightly different due to rounding or yield)
        uint256 usdcReceived = commanderUsdcAfterDisembark -
            commanderUsdcAfterBoard;
        assertApproxEqRel(
            usdcReceived,
            boardAmount,
            0.01e18, // 1% tolerance for potential fees/slippage
            "Should receive approximately the same amount back"
        );

        vm.stopPrank();
    }
}
