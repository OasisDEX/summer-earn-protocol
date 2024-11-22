// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AdmiralsQuarters} from "../src/contracts/AdmiralsQuarters.sol";

import {FleetCommander} from "../src/contracts/FleetCommander.sol";
import {IAggregationRouterV6} from "../src/interfaces/1inch/IAggregationRouterV6.sol";
import {IFleetCommanderRewardsManager} from "../src/interfaces/IFleetCommanderRewardsManager.sol";
import {FleetCommanderTestBase} from "./fleets/FleetCommanderTestBase.sol";
import {OneInchTestHelpers} from "./helpers/OneInchTestHelpers.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ContractSpecificRoles} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {Test, console} from "forge-std/Test.sol";

contract AdmiralsQuartersTest is FleetCommanderTestBase, OneInchTestHelpers {
    AdmiralsQuarters public admiralsQuarters;
    IAggregationRouterV6 public oneInchRouter;

    address public constant ONE_INCH_ROUTER =
        0x111111125421cA6dc452d289314280a0f8842A65;
    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant DAI_ADDRESS =
        0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant UNISWAP_USDC_DAI_V3_POOL =
        0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168;
    address public user1 = address(0x1111);
    address public user2 = address(0x2222);
    FleetCommander public usdcFleet;
    FleetCommander public daiFleet;

    uint256 constant FORK_BLOCK = 20576616;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), FORK_BLOCK);
        oneInchRouter = IAggregationRouterV6(ONE_INCH_ROUTER);
        uint256 initialTipRate = 0;
        initializeFleetCommanderWithoutArks(USDC_ADDRESS, initialTipRate);
        usdcFleet = fleetCommander;
        console.log("usdcFleet", address(usdcFleet));
        console.log("bufferArk", address(bufferArk));
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(address(bufferArk)),
            address(fleetCommander)
        );
        vm.stopPrank();

        initializeFleetCommanderWithoutArks(DAI_ADDRESS, initialTipRate);
        daiFleet = fleetCommander;
        console.log("daiFleet", address(daiFleet));
        console.log("bufferArk", address(bufferArk));
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(address(bufferArk)),
            address(fleetCommander)
        );

        admiralsQuarters = new AdmiralsQuarters(
            ONE_INCH_ROUTER,
            address(configurationManager)
        );

        // Grant roles
        accessManager.grantContractSpecificRole(
            ContractSpecificRoles.KEEPER_ROLE,
            address(0),
            address(this)
        );
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

    function test_Constructor() public {
        vm.startPrank(governor);
        vm.expectRevert(abi.encodeWithSignature("InvalidRouterAddress()"));
        new AdmiralsQuarters(address(0), address(configurationManager));
        vm.expectRevert(
            abi.encodeWithSignature("ConfigurationManagerZeroAddress()")
        );
        new AdmiralsQuarters(ONE_INCH_ROUTER, address(0));
        admiralsQuarters = new AdmiralsQuarters(
            ONE_INCH_ROUTER,
            address(configurationManager)
        );
        assertEq(
            address(admiralsQuarters.owner()),
            governor,
            "Owner should be the governor"
        );
        assertEq(
            address(admiralsQuarters.oneInchRouter()),
            ONE_INCH_ROUTER,
            "OneInchRouter should be set"
        );
        vm.stopPrank();
    }

    function test_Deposit_Reverts() public {
        // RevertsOnInvalidToken
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("InvalidToken()"));
        admiralsQuarters.depositTokens(IERC20(address(0)), 1000e6);
        vm.stopPrank();
        // RevertsOnZeroAmount
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("ZeroAmount()"));
        admiralsQuarters.depositTokens(IERC20(USDC_ADDRESS), 0);
        vm.stopPrank();

        vm.startPrank(user1);
        admiralsQuarters.depositTokens(IERC20(USDC_ADDRESS), 1);
        vm.stopPrank();
    }

    function test_Withdraw_Reverts() public {
        // RevertsOnInvalidToken
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("InvalidToken()"));
        admiralsQuarters.withdrawTokens(IERC20(address(0)), 1000e6);
        vm.stopPrank();
    }

    function test_EnterFleet_Reverts() public {
        // RevertsOnInvalidFleetCommander
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("InvalidFleetCommander()"));
        admiralsQuarters.enterFleet(
            address(0),
            IERC20(USDC_ADDRESS),
            1000e6,
            user1
        );
        vm.stopPrank();
        // RevertsOnInvalidToken
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("InvalidToken()"));
        admiralsQuarters.enterFleet(
            address(usdcFleet),
            IERC20(address(0)),
            1000e6,
            user1
        );
        vm.stopPrank();
        // RevertsOnInsufficientOutputAmount
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("InsufficientOutputAmount()"));
        admiralsQuarters.enterFleet(
            address(usdcFleet),
            IERC20(USDC_ADDRESS),
            1000e6,
            user1
        );
        vm.stopPrank();
    }

    function test_ExitFleet_Reverts() public {
        // RevertsOnInvalidFleetCommander
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("InvalidFleetCommander()"));
        admiralsQuarters.exitFleet(address(0), 1000e6);
        vm.stopPrank();
    }

    function test_Swap_Reverts() public {
        // RevertsOnInvalidToken
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("InvalidToken()"));
        admiralsQuarters.swap(
            IERC20(address(0)),
            IERC20(DAI_ADDRESS),
            1000e6,
            0,
            new bytes(0)
        );
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("InvalidToken()"));
        admiralsQuarters.swap(
            IERC20(DAI_ADDRESS),
            IERC20(address(0)),
            1000e6,
            0,
            new bytes(0)
        );
        vm.stopPrank();

        // RevertsOnAssetMismatch
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("AssetMismatch()"));
        admiralsQuarters.swap(
            IERC20(DAI_ADDRESS),
            IERC20(DAI_ADDRESS),
            1000e6,
            0,
            new bytes(0)
        );
        vm.stopPrank();

        uint256 usdcAmount = 100e6; // 1000 USDC
        uint256 minDaiAmount = 500e18; // Expecting at least 499 DAI
        deal(USDC_ADDRESS, user1, usdcAmount);
        // Encode unoswap data for USDC to DAI swap
        bytes memory usdcToDaiSwap = encodeUnoswapData(
            USDC_ADDRESS,
            usdcAmount,
            0,
            UNISWAP_USDC_DAI_V3_POOL,
            Protocol.UniswapV3,
            false,
            false,
            false,
            false
        );

        bytes[] memory enterCalls = new bytes[](4);
        enterCalls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(USDC_ADDRESS), usdcAmount)
        );
        enterCalls[1] = abi.encodeCall(
            admiralsQuarters.swap,
            (
                IERC20(USDC_ADDRESS),
                IERC20(DAI_ADDRESS),
                minDaiAmount,
                100000 ether,
                usdcToDaiSwap
            )
        );
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("InsufficientOutputAmount()"));
        admiralsQuarters.multicall(enterCalls);
    }

    function test_Deposit_Enter_Stake() public {
        address rewardsManager = usdcFleet.getConfig().stakingRewardsManager;
        uint256 usdcAmount = 1000e6; // 1000 USDC
        vm.startPrank(user1);
        bytes[] memory enterCalls = new bytes[](3);
        enterCalls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(USDC_ADDRESS), usdcAmount)
        );
        enterCalls[1] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (
                address(usdcFleet),
                IERC20(USDC_ADDRESS),
                usdcAmount / 2,
                address(admiralsQuarters)
            )
        );
        enterCalls[2] = abi.encodeCall(
            admiralsQuarters.stakeFleetShares,
            (address(usdcFleet), 0)
        );
        admiralsQuarters.multicall(enterCalls);
        assertEq(
            IFleetCommanderRewardsManager(rewardsManager).balanceOf(user1),
            usdcAmount / 2,
            "Should have staked USDC fleet shares"
        );
        vm.stopPrank();
    }

    function test_Deposit_Enter_Stake_Reverts() public {
        address rewardsManager = usdcFleet.getConfig().stakingRewardsManager;
        uint256 usdcAmount = 1000e6; // 1000 USDC
        vm.startPrank(user1);
        bytes[] memory enterCalls = new bytes[](3);
        enterCalls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(USDC_ADDRESS), usdcAmount)
        );
        enterCalls[1] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (
                address(usdcFleet),
                IERC20(USDC_ADDRESS),
                usdcAmount / 2,
                address(admiralsQuarters)
            )
        );
        enterCalls[2] = abi.encodeCall(
            admiralsQuarters.stakeFleetShares,
            (address(usdcFleet), usdcAmount)
        );
        vm.expectRevert(abi.encodeWithSignature("InsufficientOutputAmount()"));
        admiralsQuarters.multicall(enterCalls);
        vm.stopPrank();
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
            (address(usdcFleet), IERC20(USDC_ADDRESS), usdcAmount / 2, user1)
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
            (address(daiFleet), IERC20(DAI_ADDRESS), 0, user1)
        );

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
            (address(daiFleet), IERC20(DAI_ADDRESS), 0, user1)
        );

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

    function test_DepositDAI_WithdrawPartialSwapToUSDC_DepositUSDC() public {
        uint256 daiAmount = 1000e18; // 1000 DAI
        uint256 minUsdcAmount = 990e6; // Expecting at least 990 USDC for half the DAI

        // Mint DAI for user1
        deal(DAI_ADDRESS, user1, daiAmount);

        vm.startPrank(user1);

        // Deposit DAI into DAI fleet
        bytes[] memory depositCalls = new bytes[](2);
        depositCalls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(DAI_ADDRESS), daiAmount)
        );
        depositCalls[1] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(daiFleet), IERC20(DAI_ADDRESS), daiAmount, user1)
        );
        admiralsQuarters.multicall(depositCalls);

        uint256 daiFleetShares = daiFleet.balanceOf(user1);
        assertGt(daiFleetShares, 0, "Should have DAI fleet shares");

        // Withdraw half of DAI, swap to USDC, and deposit into USDC fleet
        uint256 halfDaiShares = daiFleetShares / 2;
        uint256 halfDaiAmount = daiFleet.convertToAssets(halfDaiShares);

        // Encode unoswap data for DAI to USDC swap
        bytes memory daiToUsdcSwap = encodeUnoswapData(
            DAI_ADDRESS,
            halfDaiAmount,
            minUsdcAmount / 2,
            UNISWAP_USDC_DAI_V3_POOL,
            Protocol.UniswapV3,
            false,
            false,
            true,
            false
        );

        daiFleet.approve(address(admiralsQuarters), daiFleetShares);

        bytes[] memory withdrawAndSwapCalls = new bytes[](4);
        withdrawAndSwapCalls[0] = abi.encodeCall(
            admiralsQuarters.exitFleet,
            (address(daiFleet), daiFleetShares)
        );
        withdrawAndSwapCalls[1] = abi.encodeCall(
            admiralsQuarters.swap,
            (
                IERC20(DAI_ADDRESS),
                IERC20(USDC_ADDRESS),
                halfDaiAmount,
                minUsdcAmount / 2,
                daiToUsdcSwap
            )
        );
        withdrawAndSwapCalls[2] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(usdcFleet), IERC20(USDC_ADDRESS), 0, user1)
        );
        withdrawAndSwapCalls[3] = abi.encodeCall(
            admiralsQuarters.withdrawTokens,
            (IERC20(DAI_ADDRESS), halfDaiAmount)
        );

        admiralsQuarters.multicall(withdrawAndSwapCalls);

        // Check final balances
        uint256 finalDaiFleetShares = daiFleet.balanceOf(user1);
        uint256 usdcFleetShares = usdcFleet.balanceOf(user1);
        uint256 daiBalance = IERC20(DAI_ADDRESS).balanceOf(user1);

        assertEq(
            finalDaiFleetShares,
            0,
            "Should have no original DAI fleet shares"
        );
        assertGt(usdcFleetShares, 0, "Should have USDC fleet shares");
        assertEq(
            daiBalance,
            halfDaiAmount,
            "Should have withdrawn half of DAI"
        );

        vm.stopPrank();
    }

    function test_DepositUSDC_WithdrawAll_SwapHalfToDAI_DepositBoth() public {
        uint256 usdcAmount = 2000e6; // 2000 USDC
        uint256 minDaiAmount = 990e18; // Expecting at least 990 DAI for half the USDC

        // Mint USDC for user1
        deal(USDC_ADDRESS, user1, usdcAmount);

        vm.startPrank(user1);

        // Deposit USDC into USDC fleet
        bytes[] memory depositCalls = new bytes[](2);
        depositCalls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(USDC_ADDRESS), usdcAmount)
        );
        depositCalls[1] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(usdcFleet), IERC20(USDC_ADDRESS), usdcAmount, user1)
        );
        admiralsQuarters.multicall(depositCalls);

        uint256 usdcFleetShares = usdcFleet.balanceOf(user1);
        assertGt(usdcFleetShares, 0, "Should have USDC fleet shares");

        // Withdraw all USDC, swap half to DAI, and deposit both
        uint256 fullUsdcAmount = usdcFleet.convertToAssets(usdcFleetShares);
        uint256 halfUsdcAmount = fullUsdcAmount / 2;

        // Encode unoswap data for USDC to DAI swap
        bytes memory usdcToDaiSwap = encodeUnoswapData(
            USDC_ADDRESS,
            halfUsdcAmount,
            minDaiAmount,
            UNISWAP_USDC_DAI_V3_POOL,
            Protocol.UniswapV3,
            false,
            false,
            false,
            false
        );

        usdcFleet.approve(address(admiralsQuarters), usdcFleetShares);

        bytes[] memory withdrawSwapAndDepositCalls = new bytes[](5);
        withdrawSwapAndDepositCalls[0] = abi.encodeCall(
            admiralsQuarters.exitFleet,
            (address(usdcFleet), fullUsdcAmount)
        );
        withdrawSwapAndDepositCalls[1] = abi.encodeCall(
            admiralsQuarters.swap,
            (
                IERC20(USDC_ADDRESS),
                IERC20(DAI_ADDRESS),
                halfUsdcAmount,
                minDaiAmount,
                usdcToDaiSwap
            )
        );
        withdrawSwapAndDepositCalls[2] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(usdcFleet), IERC20(USDC_ADDRESS), halfUsdcAmount, user1)
        );
        withdrawSwapAndDepositCalls[3] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(daiFleet), IERC20(DAI_ADDRESS), 0, user1)
        );
        withdrawSwapAndDepositCalls[4] = abi.encodeCall(
            admiralsQuarters.withdrawTokens,
            (IERC20(USDC_ADDRESS), 0)
        );

        admiralsQuarters.multicall(withdrawSwapAndDepositCalls);

        // Check final balances
        uint256 finalUsdcFleetShares = usdcFleet.balanceOf(user1);
        uint256 daiFleetShares = daiFleet.balanceOf(user1);
        uint256 usdcBalance = IERC20(USDC_ADDRESS).balanceOf(user1);

        assertGt(finalUsdcFleetShares, 0, "Should have USDC fleet shares");
        assertGt(daiFleetShares, 0, "Should have DAI fleet shares");
        assertEq(usdcBalance, 0, "Should have no USDC balance left");

        vm.stopPrank();
    }

    function test_DepositBothTokens_SwapBetweenFleets_WithdrawAll() public {
        uint256 usdcAmount = 1000e6; // 1000 USDC
        uint256 daiAmount = 1000e18; // 1000 DAI

        // Mint tokens for user1
        deal(USDC_ADDRESS, user1, usdcAmount);
        deal(DAI_ADDRESS, user1, daiAmount);

        vm.startPrank(user1);

        // Deposit both tokens into their respective fleets
        bytes[] memory depositCalls = new bytes[](4);
        depositCalls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(USDC_ADDRESS), usdcAmount)
        );
        depositCalls[1] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(usdcFleet), IERC20(USDC_ADDRESS), usdcAmount, user1)
        );
        depositCalls[2] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(DAI_ADDRESS), daiAmount)
        );
        depositCalls[3] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(daiFleet), IERC20(DAI_ADDRESS), daiAmount, user1)
        );
        admiralsQuarters.multicall(depositCalls);

        uint256 initialUsdcShares = usdcFleet.balanceOf(user1);
        uint256 initialDaiShares = daiFleet.balanceOf(user1);

        assertGt(initialUsdcShares, 0, "Should have USDC fleet shares");
        assertGt(initialDaiShares, 0, "Should have DAI fleet shares");

        // Swap half of USDC to DAI and half of DAI to USDC
        uint256 halfUsdcAmount = usdcFleet.convertToAssets(
            initialUsdcShares / 2
        );
        uint256 halfDaiAmount = daiFleet.convertToAssets(initialDaiShares / 2);

        bytes memory usdcToDaiSwap = encodeUnoswapData(
            USDC_ADDRESS,
            halfUsdcAmount,
            0,
            UNISWAP_USDC_DAI_V3_POOL,
            Protocol.UniswapV3,
            false,
            false,
            false,
            false
        );

        bytes memory daiToUsdcSwap = encodeUnoswapData(
            DAI_ADDRESS,
            halfDaiAmount,
            0,
            UNISWAP_USDC_DAI_V3_POOL,
            Protocol.UniswapV3,
            false,
            false,
            true,
            false
        );

        usdcFleet.approve(address(admiralsQuarters), 2 * initialUsdcShares);
        daiFleet.approve(address(admiralsQuarters), 2 * initialDaiShares);

        bytes[] memory swapCalls = new bytes[](6);
        swapCalls[0] = abi.encodeCall(
            admiralsQuarters.exitFleet,
            (address(usdcFleet), halfUsdcAmount)
        );
        swapCalls[1] = abi.encodeCall(
            admiralsQuarters.swap,
            (
                IERC20(USDC_ADDRESS),
                IERC20(DAI_ADDRESS),
                halfUsdcAmount,
                0,
                usdcToDaiSwap
            )
        );
        swapCalls[2] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(daiFleet), IERC20(DAI_ADDRESS), 0, user1)
        );
        swapCalls[3] = abi.encodeCall(
            admiralsQuarters.exitFleet,
            (address(daiFleet), halfDaiAmount)
        );
        swapCalls[4] = abi.encodeCall(
            admiralsQuarters.swap,
            (
                IERC20(DAI_ADDRESS),
                IERC20(USDC_ADDRESS),
                halfDaiAmount,
                0,
                daiToUsdcSwap
            )
        );
        swapCalls[5] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(usdcFleet), IERC20(USDC_ADDRESS), 0, user1)
        );

        admiralsQuarters.multicall(swapCalls);

        // Withdraw all from both fleets
        bytes[] memory withdrawCalls = new bytes[](4);
        withdrawCalls[0] = abi.encodeCall(
            admiralsQuarters.exitFleet,
            (address(usdcFleet), type(uint256).max)
        );
        withdrawCalls[1] = abi.encodeCall(
            admiralsQuarters.exitFleet,
            (address(daiFleet), type(uint256).max)
        );
        withdrawCalls[2] = abi.encodeCall(
            admiralsQuarters.withdrawTokens,
            (IERC20(USDC_ADDRESS), 0)
        );
        withdrawCalls[3] = abi.encodeCall(
            admiralsQuarters.withdrawTokens,
            (IERC20(DAI_ADDRESS), 0)
        );

        admiralsQuarters.multicall(withdrawCalls);

        // Check final balances
        uint256 finalUsdcBalance = IERC20(USDC_ADDRESS).balanceOf(user1);
        uint256 finalDaiBalance = IERC20(DAI_ADDRESS).balanceOf(user1);

        assertGt(
            finalUsdcBalance,
            0,
            "Should have USDC balance after withdrawing"
        );
        assertGt(
            finalDaiBalance,
            0,
            "Should have DAI balance after withdrawing"
        );
        assertEq(
            usdcFleet.balanceOf(user1),
            0,
            "Should have no USDC fleet shares"
        );
        assertEq(
            daiFleet.balanceOf(user1),
            0,
            "Should have no DAI fleet shares"
        );

        vm.stopPrank();
    }

    function test_FailedSwap() public {
        uint256 usdcAmount = 1000e6; // 1000 USDC
        deal(USDC_ADDRESS, user1, usdcAmount);

        vm.startPrank(user1);

        // Deposit USDC
        admiralsQuarters.depositTokens(IERC20(USDC_ADDRESS), usdcAmount);

        // Attempt to swap with an unrealistically high minimum return
        uint256 unrealisticMinReturn = 10000e18; // Expecting 10000 DAI for 1000 USDC
        bytes memory usdcToDaiSwap = encodeUnoswapData(
            USDC_ADDRESS,
            usdcAmount,
            unrealisticMinReturn,
            UNISWAP_USDC_DAI_V3_POOL,
            Protocol.UniswapV3,
            false,
            false,
            false,
            false
        );

        // The swap should revert due to insufficient output amount
        vm.expectRevert(abi.encodeWithSignature("SwapFailed()"));
        admiralsQuarters.swap(
            IERC20(USDC_ADDRESS),
            IERC20(DAI_ADDRESS),
            usdcAmount,
            unrealisticMinReturn,
            usdcToDaiSwap
        );

        // Check that the USDC balance is unchanged
        assertEq(
            IERC20(USDC_ADDRESS).balanceOf(address(admiralsQuarters)),
            usdcAmount,
            "USDC balance should be unchanged"
        );

        vm.stopPrank();
    }

    function test_DepositWithdrawSameToken() public {
        uint256 usdcAmount = 1000e6; // 1000 USDC
        deal(USDC_ADDRESS, user1, usdcAmount);

        vm.startPrank(user1);

        // Deposit USDC
        admiralsQuarters.depositTokens(IERC20(USDC_ADDRESS), usdcAmount);

        // Withdraw half of the USDC
        uint256 withdrawAmount = usdcAmount / 2;
        admiralsQuarters.withdrawTokens(IERC20(USDC_ADDRESS), withdrawAmount);

        // Check balances
        assertEq(
            IERC20(USDC_ADDRESS).balanceOf(address(admiralsQuarters)),
            withdrawAmount,
            "AdmiralsQuarters should have half of the USDC"
        );
        assertEq(
            IERC20(USDC_ADDRESS).balanceOf(user1),
            withdrawAmount,
            "User should have received half of the USDC"
        );

        vm.stopPrank();
    }

    function test_MultiUserInteraction() public {
        uint256 user1UsdcAmount = 1000e6; // 1000 USDC
        uint256 user2DaiAmount = 1000e18; // 1000 DAI

        deal(USDC_ADDRESS, user1, user1UsdcAmount);
        deal(DAI_ADDRESS, user2, user2DaiAmount);

        // User 1 deposits USDC and enters USDC fleet
        vm.startPrank(user1);
        admiralsQuarters.depositTokens(IERC20(USDC_ADDRESS), user1UsdcAmount);
        admiralsQuarters.enterFleet(
            address(usdcFleet),
            IERC20(USDC_ADDRESS),
            user1UsdcAmount,
            user1
        );
        vm.stopPrank();

        // User 2 deposits DAI and enters DAI fleet
        vm.startPrank(user2);
        admiralsQuarters.depositTokens(IERC20(DAI_ADDRESS), user2DaiAmount);
        admiralsQuarters.enterFleet(
            address(daiFleet),
            IERC20(DAI_ADDRESS),
            user2DaiAmount,
            user2
        );
        vm.stopPrank();

        // Check fleet balances
        assertGt(
            usdcFleet.balanceOf(user1),
            0,
            "User 1 should have USDC fleet shares"
        );
        assertGt(
            daiFleet.balanceOf(user2),
            0,
            "User 2 should have DAI fleet shares"
        );

        // User 1 exits USDC fleet and swaps to DAI
        vm.startPrank(user1);
        uint256 user1UsdcShares = usdcFleet.balanceOf(user1);
        usdcFleet.approve(address(admiralsQuarters), user1UsdcShares);

        bytes memory usdcToDaiSwap = encodeUnoswapData(
            USDC_ADDRESS,
            user1UsdcAmount,
            0, // Set min return to 0 for simplicity
            UNISWAP_USDC_DAI_V3_POOL,
            Protocol.UniswapV3,
            false,
            false,
            false,
            false
        );

        bytes[] memory user1ExitAndSwapCalls = new bytes[](3);
        user1ExitAndSwapCalls[0] = abi.encodeCall(
            admiralsQuarters.exitFleet,
            (address(usdcFleet), type(uint256).max)
        );
        user1ExitAndSwapCalls[1] = abi.encodeCall(
            admiralsQuarters.swap,
            (
                IERC20(USDC_ADDRESS),
                IERC20(DAI_ADDRESS),
                user1UsdcAmount,
                0,
                usdcToDaiSwap
            )
        );
        user1ExitAndSwapCalls[2] = abi.encodeCall(
            admiralsQuarters.withdrawTokens,
            (IERC20(DAI_ADDRESS), 0)
        );

        admiralsQuarters.multicall(user1ExitAndSwapCalls);
        vm.stopPrank();

        // User 2 exits DAI fleet and swaps to USDC
        vm.startPrank(user2);
        uint256 user2DaiShares = daiFleet.balanceOf(user2);
        daiFleet.approve(address(admiralsQuarters), user2DaiShares);

        bytes memory daiToUsdcSwap = encodeUnoswapData(
            DAI_ADDRESS,
            user2DaiAmount,
            0, // Set min return to 0 for simplicity
            UNISWAP_USDC_DAI_V3_POOL,
            Protocol.UniswapV3,
            false,
            false,
            true,
            false
        );

        bytes[] memory user2ExitAndSwapCalls = new bytes[](3);
        user2ExitAndSwapCalls[0] = abi.encodeCall(
            admiralsQuarters.exitFleet,
            (address(daiFleet), type(uint256).max)
        );
        user2ExitAndSwapCalls[1] = abi.encodeCall(
            admiralsQuarters.swap,
            (
                IERC20(DAI_ADDRESS),
                IERC20(USDC_ADDRESS),
                user2DaiAmount,
                0,
                daiToUsdcSwap
            )
        );
        user2ExitAndSwapCalls[2] = abi.encodeCall(
            admiralsQuarters.withdrawTokens,
            (IERC20(USDC_ADDRESS), 0)
        );

        admiralsQuarters.multicall(user2ExitAndSwapCalls);
        vm.stopPrank();

        // Check final balances
        assertGt(
            IERC20(DAI_ADDRESS).balanceOf(user1),
            0,
            "User 1 should have DAI"
        );
        assertEq(
            usdcFleet.balanceOf(user1),
            0,
            "User 1 should have no USDC fleet shares"
        );
        assertGt(
            IERC20(USDC_ADDRESS).balanceOf(user2),
            0,
            "User 2 should have USDC"
        );
        assertEq(
            daiFleet.balanceOf(user2),
            0,
            "User 2 should have no DAI fleet shares"
        );
    }

    function test_RescueTokens() public {
        address owner = admiralsQuarters.owner();
        uint256 usdcAmount = 1000e6; // 1000 USDC
        uint256 ownerBalanceBefore = IERC20(USDC_ADDRESS).balanceOf(owner);
        deal(USDC_ADDRESS, address(admiralsQuarters), usdcAmount);

        // Only the owner should be able to rescue tokens
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                user1
            )
        );
        admiralsQuarters.rescueTokens(IERC20(USDC_ADDRESS), user1, usdcAmount);

        // Owner rescues tokens
        vm.prank(owner);
        admiralsQuarters.rescueTokens(IERC20(USDC_ADDRESS), owner, usdcAmount);

        assertEq(
            IERC20(USDC_ADDRESS).balanceOf(owner) - ownerBalanceBefore,
            usdcAmount,
            "Owner should have received rescued USDC"
        );
    }
}
