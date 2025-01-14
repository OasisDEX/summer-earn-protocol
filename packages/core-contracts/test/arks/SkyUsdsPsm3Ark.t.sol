// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/SkyUsdsPsm3Ark.sol";

import {IArkEvents} from "../../src/events/IArkEvents.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";

contract USDSPsm3ArkTestFork is Test, IArkEvents, ArkTestBase {
    SkyUsdsPsm3Ark public ark;
    SkyUsdsPsm3Ark public nextArk;

    // Known contract addresses on Base
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant SUSDS = 0x5875eEE11Cf8398102FdAd704C9E96607675467a;
    address public constant PSM3 = 0x1601843c5E9bC251A3272907010AFa41Fa18347E;

    IERC20 public usdc;
    IERC20 public susds;
    IPSM3 public psm;

    // both blocks are in the past so we can get the correct blockchain state
    uint256 forkBlock = 22847317;
    uint256 futureBlock = 24555788;
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("base"), forkBlock);

        usdc = IERC20(USDC);
        susds = IERC20(SUSDS);
        psm = IPSM3(PSM3);

        ArkParams memory params = ArkParams({
            name: "USDSPsm3Ark",
            details: "USDC to sUSDS Ark on Base",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new SkyUsdsPsm3Ark(PSM3, SUSDS, params);

        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(ark), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();

        vm.makePersistent(address(ark));
        vm.makePersistent(USDC);
        vm.makePersistent(SUSDS);
        vm.makePersistent(PSM3);
        vm.makePersistent(address(accessManager));
    }

    function test_Board_USDSPsm3Ark_fork() public {
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
        vm.rollFork(futureBlock);
        uint256 assetsAfterAccrual = ark.totalAssets();
        assertGt(
            assetsAfterAccrual,
            assetsAfterDeposit,
            "Should accrue yield over time"
        );
    }

    function test_Disembark_USDSPsm3Ark_fork() public {
        // First board some assets so we have something to disembark
        uint256 boardAmount = 1000 * 10 ** 6; // 1000 USDC
        deal(address(usdc), commander, boardAmount);

        vm.startPrank(commander);
        usdc.approve(address(ark), boardAmount);
        ark.board(boardAmount, bytes(""));

        // Wait some time to accrue yield
        vm.rollFork(futureBlock);

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
        uint256 arkSusdsBalance = susds.balanceOf(address(ark));
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
        assertEq(
            arkSusdsBalance,
            0,
            "Ark should have no sUSDS balance after full withdrawal"
        );
    }
}
