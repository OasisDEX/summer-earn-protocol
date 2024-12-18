// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/SkyUsdsArk.sol";

import {IArkEvents} from "../../src/events/IArkEvents.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";

contract USDSArkTestFork is Test, IArkEvents, ArkTestBase {
    SkyUsdsArk public ark;
    SkyUsdsArk public nextArk;

    // Known contract addresses
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address public constant STAKED_USDS =
        0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address public constant LITE_PSM =
        0xA188EEC8F81263234dA3622A406892F3D630f98c;

    IERC20 public usdc;
    IERC20 public usds;
    IERC4626 public stakedUsds;
    ILitePSM public litePsm;

    uint256 forkBlock = 20842109;
    uint256 futureBlock = 21243306;
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        usdc = IERC20(USDC);
        usds = IERC20(USDS);
        stakedUsds = IERC4626(STAKED_USDS);
        litePsm = ILitePSM(LITE_PSM);

        ArkParams memory params = ArkParams({
            name: "USDSArk",
            details: "USDC to stakedUSDS Ark",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new SkyUsdsArk(LITE_PSM, USDS, STAKED_USDS, params);

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
        vm.makePersistent(STAKED_USDS);
        vm.makePersistent(LITE_PSM);
        vm.makePersistent(address(accessManager));
    }

    function test_Board_USDSArk_fork() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 6; // USDC has 6 decimals
        deal(address(usdc), commander, amount);

        vm.startPrank(commander);
        usdc.approve(address(ark), amount);

        // Expect the Boarded event
        vm.expectEmit();
        emit Boarded(commander, address(usdc), amount);

        // Act
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Assert
        assertGt(ark.totalAssets(), 0, "Should have assets after boarding");

        // Check yield accrual
        uint256 assetsAfterDeposit = ark.totalAssets();
        vm.warp(block.timestamp + 10000);
        uint256 assetsAfterAccrual = ark.totalAssets();
        assertGt(
            assetsAfterAccrual,
            assetsAfterDeposit,
            "Should accrue yield over time"
        );
    }

    function test_Disembark_USDSArk_fork() public {
        // First board some assets so we have something to disembark
        uint256 boardAmount = 1000 * 10 ** 6; // 1000 USDC
        deal(address(usdc), commander, boardAmount);

        vm.startPrank(commander);
        usdc.approve(address(ark), boardAmount);
        ark.board(boardAmount, bytes(""));

        // Wait some time to accrue yield
        vm.warp(block.timestamp + 1000);

        // Get current balance before disembark
        uint256 commanderUsdcBefore = usdc.balanceOf(commander);
        uint256 arkTotalBefore = ark.totalAssets();

        // Calculate amount to disembark (half of total)
        uint256 disembarkAmount = arkTotalBefore / 2;
        // Expect the Disembarked event
        vm.expectEmit();
        emit Disembarked(commander, address(usdc), disembarkAmount);

        // Act
        ark.disembark(disembarkAmount, bytes(""));
        vm.stopPrank();

        // Assert
        uint256 commanderUsdcAfter = usdc.balanceOf(commander);
        uint256 arkTotalAfter = ark.totalAssets();

        assertEq(
            arkTotalAfter,
            arkTotalBefore - disembarkAmount,
            "Ark total assets should decrease by disembark amount"
        );
        assertGt(
            commanderUsdcAfter,
            commanderUsdcBefore,
            "Commander should receive USDC"
        );
    }

    function test_Disembark_AfterYieldAccrual_CheckLeftovers() public {
        // Arrange - Initial deposit
        uint256 boardAmount = 1000 * 10 ** 6; // 1000 USDC
        deal(address(usdc), commander, boardAmount);

        vm.startPrank(commander);
        usdc.approve(address(ark), boardAmount);
        ark.board(boardAmount, bytes(""));
        vm.stopPrank();

        // Simulate yield accrual by moving to future block
        vm.rollFork(futureBlock);

        // Record balances before withdrawal
        uint256 totalAssetsBeforeWithdraw = ark.totalAssets();
        uint256 commanderUsdcBefore = usdc.balanceOf(commander);

        // Withdraw all assets
        vm.startPrank(commander);
        ark.disembark(totalAssetsBeforeWithdraw, bytes(""));
        vm.stopPrank();

        // Assert
        uint256 arkUsdcBalance = usdc.balanceOf(address(ark));
        uint256 arkTotalAssets = ark.totalAssets();
        uint256 commanderUsdcAfter = usdc.balanceOf(commander);

        // Check that commander received more than deposited due to yield
        assertGt(
            commanderUsdcAfter - commanderUsdcBefore,
            boardAmount,
            "Should receive more than deposited due to yield"
        );

        // Check for any leftover balances
        assertEq(
            arkUsdcBalance,
            0,
            "Ark should have no USDC balance after full withdrawal"
        );
        assertEq(
            arkTotalAssets,
            0,
            "Ark should report 0 total assets after full withdrawal"
        );
    }
}
