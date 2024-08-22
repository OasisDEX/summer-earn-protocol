// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {FleetCommanderTestBase} from "./fleets/FleetCommanderTestBase.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AdmiralsQuarters} from "../src/contracts/AdmiralsQuarters.sol";
import {OneInchHelpers} from "./helpers/OneInchHelpers.sol";
import {FleetCommander} from "../src/contracts/FleetCommander.sol";

contract AdmiralsQuartersTest is FleetCommanderTestBase, OneInchHelpers {
    AdmiralsQuarters public admiralsQuarters;

    address public constant ONE_INCH_ROUTER =
        0x111111125421cA6dc452d289314280a0f8842A65;
    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant DAI_ADDRESS =
        0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant UNISWAP_USDC_DAI_V3_POOL =
        0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168;
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    FleetCommander public usdcFleet;
    FleetCommander public daiFleet;

    uint256 constant FORK_BLOCK = 20576616;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), FORK_BLOCK);

        uint256 initialTipRate = 0;
        initializeFleetCommanderWithoutArks(USDC_ADDRESS, initialTipRate);
        usdcFleet = fleetCommander;
        vm.startPrank(governor);
        bufferArk.grantCommanderRole(address(fleetCommander));

        initializeFleetCommanderWithoutArks(DAI_ADDRESS, initialTipRate);
        daiFleet = fleetCommander;
        vm.startPrank(governor);
        bufferArk.grantCommanderRole(address(fleetCommander));

        admiralsQuarters = new AdmiralsQuarters(ONE_INCH_ROUTER);

        // Grant roles
        vm.startPrank(governor);
        accessManager.grantKeeperRole(address(this));
        vm.stopPrank();

        // Mint tokens for users
        deal(USDC_ADDRESS, user1, 1000e6);
        deal(USDC_ADDRESS, user2, 1000e6);

        // Approve AdmiralsQuarters to spend user tokens
        vm.startPrank(user1);
        IERC20(USDC_ADDRESS).approve(
            address(admiralsQuarters),
            type(uint256).max
        );
        IERC20(DAI_ADDRESS).approve(
            address(admiralsQuarters),
            type(uint256).max
        );
        vm.stopPrank();

        vm.startPrank(user2);
        IERC20(USDC_ADDRESS).approve(
            address(admiralsQuarters),
            type(uint256).max
        );
        IERC20(DAI_ADDRESS).approve(
            address(admiralsQuarters),
            type(uint256).max
        );
        vm.stopPrank();
        vm.label(address(daiFleet), "DAI Fleet");
        vm.label(address(usdcFleet), "USDC Fleet");

        vm.label(USDC_ADDRESS, "USDC");
        vm.label(DAI_ADDRESS, "DAI");
    }

    function test_EnterAndExitFleetsX() public {
        uint256 usdcAmount = 1000e6; // 1000 USDC
        uint256 minDaiAmount = 499e18; // Expecting at least 499 DAI

        // Encode unoswap data for USDC to DAI swap
        bytes memory usdcToDaiSwap = encodeUnoswapData(
            USDC_ADDRESS,
            usdcAmount / 2,
            minDaiAmount,
            UNISWAP_USDC_DAI_V3_POOL,
            Protocol.UniswapV3,
            false,
            false,
            false,
            false
        );

        vm.startPrank(user1);

        // Enter fleets using multicall
        bytes[] memory enterCalls = new bytes[](4);
        enterCalls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(USDC_ADDRESS), usdcAmount)
        );
        enterCalls[1] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(usdcFleet), IERC20(USDC_ADDRESS), usdcAmount / 2)
        );
        enterCalls[2] = abi.encodeCall(
            admiralsQuarters.swap,
            (
                IERC20(USDC_ADDRESS),
                IERC20(DAI_ADDRESS),
                usdcAmount / 2,
                0,
                usdcToDaiSwap
            )
        );
        enterCalls[3] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(daiFleet), IERC20(DAI_ADDRESS), 0)
        );

        uint256 gasBefore = gasleft();
        admiralsQuarters.multicall(enterCalls);

        // Check balances after entering
        uint256 usdcFleetShares = usdcFleet.balanceOf(user1);
        uint256 daiFleetShares = daiFleet.balanceOf(user1);
        uint256 daiAssets = daiFleet.convertToAssets(daiFleetShares);
        uint256 usdcAssets = usdcFleet.convertToAssets(usdcFleetShares);

        assertGt(usdcFleetShares, 0, "Should have USDC fleet shares");
        assertGt(daiFleetShares, 0, "Should have DAI fleet shares");

        // Encode unoswap data for DAI to USDC swap
        bytes memory daiToUsdcSwap = encodeUnoswapData(
            DAI_ADDRESS,
            daiAssets,
            1, // Set min return to 0 for simplicity, adjust in production
            UNISWAP_USDC_DAI_V3_POOL,
            Protocol.UniswapV3,
            false,
            false,
            true,
            false
        );

        usdcFleet.approve(address(admiralsQuarters), usdcFleetShares);
        daiFleet.approve(address(admiralsQuarters), daiFleetShares);

        // Exit fleets using multicall
        bytes[] memory exitCalls = new bytes[](4);
        exitCalls[0] = abi.encodeCall(
            admiralsQuarters.exitFleet,
            (address(usdcFleet), usdcAssets)
        );

        exitCalls[1] = abi.encodeCall(
            admiralsQuarters.exitFleet,
            (address(daiFleet), daiAssets)
        );
        exitCalls[2] = abi.encodeCall(
            admiralsQuarters.swap,
            (
                IERC20(DAI_ADDRESS),
                IERC20(USDC_ADDRESS),
                daiAssets,
                0,
                daiToUsdcSwap
            )
        );
        exitCalls[3] = abi.encodeCall(
            admiralsQuarters.withdrawTokens,
            (IERC20(USDC_ADDRESS), 0)
        );

        gasBefore = gasleft();
        admiralsQuarters.multicall(exitCalls);

        // Check balances after exiting
        uint256 finalUsdcBalance = IERC20(USDC_ADDRESS).balanceOf(user1);

        assertGt(
            finalUsdcBalance,
            0,
            "Should have received USDC after exiting"
        );
        assertLt(
            finalUsdcBalance,
            usdcAmount,
            "Should have less USDC due to fees and slippage"
        );

        vm.stopPrank();
    }

    function test_MoveFleetsX() public {
        uint256 usdcAmount = 1000e6; // 1000 USDC
        uint256 minDaiAmount = 999e18; // Expecting at least 999 DAI

        // First, depositTokens USDC into the USDC fleet
        vm.startPrank(user1);
        IERC20(USDC_ADDRESS).approve(address(usdcFleet), usdcAmount);
        uint256 usdcShares = usdcFleet.deposit(usdcAmount, user1);

        // Check initial balances
        assertEq(
            usdcFleet.balanceOf(user1),
            usdcShares,
            "Should have USDC fleet shares"
        );
        assertEq(
            daiFleet.balanceOf(user1),
            0,
            "Should have no DAI fleet shares initially"
        );

        // Encode unoswap data for USDC to DAI swap
        bytes memory usdcToDaiSwap = encodeUnoswapData(
            USDC_ADDRESS,
            usdcAmount,
            minDaiAmount,
            UNISWAP_USDC_DAI_V3_POOL,
            Protocol.UniswapV3,
            false,
            false,
            false,
            false
        );

        // Approve AdmiralsQuarters to spend user's USDC fleet shares
        usdcFleet.approve(address(admiralsQuarters), usdcShares);

        // Move from USDC fleet to DAI fleet using multicall
        bytes[] memory moveCalls = new bytes[](3);
        moveCalls[0] = abi.encodeCall(
            admiralsQuarters.exitFleet,
            (address(usdcFleet), usdcShares)
        );
        moveCalls[1] = abi.encodeCall(
            admiralsQuarters.swap,
            (
                IERC20(USDC_ADDRESS),
                IERC20(DAI_ADDRESS),
                usdcAmount,
                0,
                usdcToDaiSwap
            )
        );
        moveCalls[2] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(daiFleet), IERC20(DAI_ADDRESS), 0)
        );

        uint256 gasBefore = gasleft();
        admiralsQuarters.multicall(moveCalls);

        // Check final balances
        assertEq(
            usdcFleet.balanceOf(user1),
            0,
            "Should have no USDC fleet shares after move"
        );
        uint256 daiFleetShares = daiFleet.balanceOf(user1);
        assertGt(daiFleetShares, 0, "Should have DAI fleet shares after move");

        uint256 daiAssets = daiFleet.convertToAssets(daiFleetShares);

        assertGe(
            daiAssets,
            minDaiAmount,
            "Should have received at least the minimum DAI amount"
        );

        vm.stopPrank();
    }
}
