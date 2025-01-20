// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/SparkArk.sol";
import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

contract SparkArkForkTest is Test, ArkTestBase {
    SparkArk public ark;

    address public constant SPARK_POOL =
        0xC13e21B648A5Ee794902342038FF3aDAB66BE987;
    address public constant SPARK_REWARDS =
        0x4370D3b6C9588E02ce9D22e684387859c7Ff5b34;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint256 public constant FORK_BLOCK = 18_897_488;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), FORK_BLOCK);
        initializeCoreContracts();

        ArkParams memory params = ArkParams({
            name: "TestArk",
            details: "TestArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new SparkArk(SPARK_POOL, SPARK_REWARDS, params);

        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(ark), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();
    }

    function test_Fork_Board() public {
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(USDC, commander, amount);

        vm.startPrank(commander);
        IERC20(USDC).approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        assertEq(ark.totalAssets(), amount);
    }

    function test_Fork_DisembarkS() public {
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(USDC, commander, amount);

        vm.startPrank(commander);
        IERC20(USDC).approve(address(ark), amount);
        ark.board(amount, bytes(""));
        ark.disembark(amount, bytes(""));
        vm.stopPrank();

        assertEq(ark.totalAssets(), 0);
        assertEq(IERC20(USDC).balanceOf(commander), amount);
    }

    function test_Fork_Harvest() public {
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(USDC, commander, amount);

        vm.startPrank(commander);
        IERC20(USDC).approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Wait for some rewards to accrue
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1);

        vm.prank(address(raft));
        ark.harvest("");
    }
}
