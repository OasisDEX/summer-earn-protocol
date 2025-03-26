// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "../../src/contracts/arks/MoonwellArk.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

contract MoonwellArkTestFork is Test, ArkTestBase {
    MoonwellArk public eurcArk;
    MoonwellArk public usdsArk;
    address public constant MTOKEN_ADDRESS_EURC =
        0xb682c840B5F4FC58B20769E691A6fa1305A501a2;
    address public constant MTOKEN_ADDRESS_USDS =
        0xb6419c6C2e60c4025D6D06eE4F913ce89425a357;
    address public constant UNDERLYING_ASSET_EURC =
        0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42;
    address public constant UNDERLYING_ASSET_USDS =
        0x820C137fa70C8691f0e44Dc420a5e53c168921Dc;
    address public constant WELL_ADDRESS =
        0xA88594D404727625A9437C3f886C7643872296AE;

    IERC20 public eurcAsset;
    IERC20 public usdsAsset;

    uint256 forkBlock = 27282449; // Block number for the fork
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("base"), forkBlock);

        eurcAsset = IERC20(UNDERLYING_ASSET_EURC);
        usdsAsset = IERC20(UNDERLYING_ASSET_USDS);
        ArkParams memory eurcParams = ArkParams({
            name: "MoonwellArk",
            details: "MoonwellArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(eurcAsset),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ArkParams memory usdsParams = ArkParams({
            name: "MoonwellArk",
            details: "MoonwellArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(usdsAsset),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        eurcArk = new MoonwellArk(MTOKEN_ADDRESS_EURC, eurcParams);
        usdsArk = new MoonwellArk(MTOKEN_ADDRESS_USDS, usdsParams);

        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(eurcArk), address(commander));
        accessManager.grantCommanderRole(address(usdsArk), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        eurcArk.registerFleetCommander();
        usdsArk.registerFleetCommander();
        vm.stopPrank();
    }

    function test_Board_EurcMoonwellArk_fork() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 6;
        deal(address(eurcAsset), commander, amount);

        vm.startPrank(commander);
        eurcAsset.approve(address(eurcArk), amount);

        // Expect the deposit call to Moonwell
        vm.expectCall(
            MTOKEN_ADDRESS_EURC,
            abi.encodeWithSelector(IMToken.mint.selector, amount)
        );

        // Act
        eurcArk.board(amount, bytes(""));
        vm.stopPrank();

        // Assert
        uint256 assetsAfterDeposit = eurcArk.totalAssets();
        assertEq(
            assetsAfterDeposit,
            amount - 1,
            "Total assets should equal deposited amount"
        );

        // Warp time to simulate interest accrual
        vm.warp(block.timestamp + 1 days);

        uint256 assetsAfterAccrual = eurcArk.totalAssets();
        assertTrue(
            assetsAfterAccrual >= assetsAfterDeposit,
            "Assets should not decrease after accrual"
        );
        console.log("assetsAfterAccrual", assetsAfterAccrual);
        console.log("assetsAfterDeposit", assetsAfterDeposit);
    }
    function test_Board_DaiMoonwellArk_fork() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 18;
        deal(address(usdsAsset), commander, amount);

        vm.startPrank(commander);
        usdsAsset.approve(address(usdsArk), amount);

        // Expect the deposit call to Moonwell
        vm.expectCall(
            MTOKEN_ADDRESS_USDS,
            abi.encodeWithSelector(IMToken.mint.selector, amount)
        );

        // Act
        usdsArk.board(amount, bytes(""));
        vm.stopPrank();

        // Assert
        uint256 assetsAfterDeposit = usdsArk.totalAssets();
        assertApproxEqRel(
            assetsAfterDeposit,
            amount,
            1e5,
            "Total assets should equal deposited amount"
        );

        // Warp time to simulate interest accrual
        vm.warp(block.timestamp + 1 days);

        uint256 assetsAfterAccrual = usdsArk.totalAssets();

        assertTrue(
            assetsAfterAccrual >= assetsAfterDeposit,
            "Assets should not decrease after accrual"
        );

        console.log("assetsAfterAccrual", assetsAfterAccrual);
        console.log("assetsAfterDeposit", assetsAfterDeposit);
    }
    function test_Disembark_EurcMoonwellArk_fork() public {
        // First, board some assets
        test_Board_EurcMoonwellArk_fork();

        uint256 initialBalance = eurcAsset.balanceOf(commander);
        uint256 amountToWithdraw = 1000110094;

        vm.prank(commander);

        eurcArk.disembark(amountToWithdraw, bytes(""));

        uint256 finalBalance = eurcAsset.balanceOf(commander);
        assertEq(
            finalBalance - initialBalance,
            amountToWithdraw,
            "Commander should receive withdrawn amount"
        );

        uint256 remainingAssets = eurcArk.totalAssets();
        assertTrue(
            remainingAssets == 0,
            "Remaining assets should be less than initial deposit"
        );
        assertEq(IERC20(MTOKEN_ADDRESS_EURC).balanceOf(address(eurcArk)), 0);
    }
    function test_Disembark_DaiMoonwellArk_fork() public {
        // First, board some assets
        test_Board_DaiMoonwellArk_fork();

        uint256 initialBalance = usdsAsset.balanceOf(commander);

        uint256 amountToWithdraw = 1000074007253723359172;

        vm.prank(commander);

        usdsArk.disembark(amountToWithdraw, bytes(""));

        uint256 finalBalance = usdsAsset.balanceOf(commander);
        assertEq(
            finalBalance - initialBalance,
            amountToWithdraw,
            "Commander should receive withdrawn amount"
        );

        uint256 remainingAssets = usdsArk.totalAssets();
        assertTrue(
            remainingAssets == 0,
            "Remaining assets should be less than initial deposit"
        );
        assertEq(IERC20(MTOKEN_ADDRESS_USDS).balanceOf(address(usdsArk)), 0);
    }

    function test_ClaimReward_EurcMoonwellArk_fork() public {
        // First, board some assets
        test_Board_EurcMoonwellArk_fork();

        // Act
        vm.prank(raft);
        eurcArk.harvest(bytes(""));

        // Assert
        uint256 wellBalance = IERC20(WELL_ADDRESS).balanceOf(address(raft));
        assertTrue(wellBalance > 0, "Well balance should be greater than 0");
    }
}
