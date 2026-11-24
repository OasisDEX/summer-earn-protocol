// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/CapArk.sol";
import {Test, console} from "forge-std/Test.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IArkEvents} from "../../src/events/IArkEvents.sol";

contract CapArkTestFork is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;

    CapArk public ark;

    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant cUSD = 0xcCcc62962d17b8914c62D74FfB843d73B2a3cccC;
    address public constant stcUSD = 0x88887bE419578051FF9F4eb6C858A951921D8888;

    uint256 forkId;

    function setUp() public {
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"));
        initializeCoreContracts();

        ArkParams memory params = ArkParams({
            name: "CapArk",
            details: "Cap.app Ark",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new CapArk(cUSD, stcUSD, params);

        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(ark), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();
    }

    function test_CapArk_Board_fork() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC, commander, amount);

        vm.startPrank(commander);
        IERC20(USDC).forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 totalAssets = ark.totalAssets();
        // totalAssets should be roughly 1000e6 (minus mint fees)
        assertApproxEqAbs(totalAssets, amount, 2 * 1e6); // Allow 0.2% fee
        assertGt(totalAssets, 0);

        // Verify we hold stcUSD shares
        assertGt(IERC20(stcUSD).balanceOf(address(ark)), 0);
    }

    function test_CapArk_Disembark_Full_fork() public {
        uint256 amount = 1000 * 1e6;
        deal(USDC, commander, amount);

        vm.startPrank(commander);
        IERC20(USDC).forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));

        uint256 assetsBefore = ark.totalAssets();
        ark.disembark(assetsBefore, bytes(""));
        vm.stopPrank();

        assertEq(IERC20(stcUSD).balanceOf(address(ark)), 0);
        assertApproxEqAbs(IERC20(USDC).balanceOf(commander), amount, 4 * 1e6); // Allow for mint/burn fees
    }

    function test_CapArk_Disembark_Partial_fork() public {
        uint256 amount = 1000 * 1e6;
        deal(USDC, commander, amount);

        vm.startPrank(commander);
        IERC20(USDC).forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));

        uint256 withdrawAmount = 500 * 1e6;
        ark.disembark(withdrawAmount, bytes(""));
        vm.stopPrank();

        assertApproxEqAbs(
            IERC20(USDC).balanceOf(commander),
            withdrawAmount,
            5 * 1e6
        );
        assertGt(IERC20(stcUSD).balanceOf(address(ark)), 0);
    }
}
