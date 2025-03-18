// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "../../src/contracts/arks/MoonwellArk.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

contract MoonwellArkTestFork is Test, ArkTestBase {
    MoonwellArk public ark;

    address public constant MTOKEN_ADDRESS =
        0xb682c840B5F4FC58B20769E691A6fa1305A501a2;
    address public constant UNDERLYING_ASSET =
        0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42;
    address public constant WELL_ADDRESS =
        0xA88594D404727625A9437C3f886C7643872296AE;

    IERC20 public asset;

    uint256 forkBlock = 27282449; // Block number for the fork
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("base"), forkBlock);

        asset = IERC20(UNDERLYING_ASSET);

        ArkParams memory params = ArkParams({
            name: "MoonwellArk",
            details: "MoonwellArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(asset),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new MoonwellArk(MTOKEN_ADDRESS, params);

        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(ark), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();
    }

    function test_Board_MoonwellArk_fork() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 6;
        deal(address(asset), commander, amount);

        vm.startPrank(commander);
        asset.approve(address(ark), amount);

        // Expect the deposit call to Moonwell
        vm.expectCall(
            MTOKEN_ADDRESS,
            abi.encodeWithSelector(IMToken.mint.selector, amount)
        );

        // Act
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Assert
        uint256 assetsAfterDeposit = ark.totalAssets();
        assertEq(
            assetsAfterDeposit,
            amount - 1,
            "Total assets should equal deposited amount"
        );

        // Warp time to simulate interest accrual
        vm.warp(block.timestamp + 1 days);

        uint256 assetsAfterAccrual = ark.totalAssets();
        assertTrue(
            assetsAfterAccrual >= assetsAfterDeposit,
            "Assets should not decrease after accrual"
        );
        console.log("assetsAfterAccrual", assetsAfterAccrual);
        console.log("assetsAfterDeposit", assetsAfterDeposit);
    }

    function test_Disembark_MoonwellArk_fork() public {
        // First, board some assets
        test_Board_MoonwellArk_fork();

        uint256 initialBalance = asset.balanceOf(commander);
        uint256 amountToWithdraw = 1000110094;

        vm.prank(commander);

        ark.disembark(amountToWithdraw, bytes(""));

        uint256 finalBalance = asset.balanceOf(commander);
        assertEq(
            finalBalance - initialBalance,
            amountToWithdraw,
            "Commander should receive withdrawn amount"
        );

        uint256 remainingAssets = ark.totalAssets();
        assertTrue(
            remainingAssets == 0,
            "Remaining assets should be less than initial deposit"
        );
        assertEq(IERC20(MTOKEN_ADDRESS).balanceOf(address(ark)), 0);
    }

    function test_ClaimReward_MoonwellArk_fork() public {
        // First, board some assets
        test_Board_MoonwellArk_fork();

        // Act
        vm.prank(raft);
        ark.harvest(bytes(""));

        // Assert
        uint256 wellBalance = IERC20(WELL_ADDRESS).balanceOf(address(raft));
        assertTrue(wellBalance > 0, "Well balance should be greater than 0");
    }
}
