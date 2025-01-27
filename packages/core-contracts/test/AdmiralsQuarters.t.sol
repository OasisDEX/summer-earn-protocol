// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AdmiralsQuarters} from "../src/contracts/AdmiralsQuarters.sol";

import {FleetCommander} from "../src/contracts/FleetCommander.sol";
import {IAdmiralsQuartersErrors} from "../src/errors/IAdmiralsQuartersErrors.sol";
import {IAdmiralsQuartersEvents} from "../src/events/IAdmiralsQuartersEvents.sol";

import {IAggregationRouterV6} from "../src/interfaces/1inch/IAggregationRouterV6.sol";
import {IAdmiralsQuarters} from "../src/interfaces/IAdmiralsQuarters.sol";
import {IFleetCommanderRewardsManager} from "../src/interfaces/IFleetCommanderRewardsManager.sol";
import {FleetCommanderTestBase} from "./fleets/FleetCommanderTestBase.sol";
import {OneInchTestHelpers} from "./helpers/OneInchTestHelpers.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ContractSpecificRoles} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {Test, console} from "forge-std/Test.sol";

contract AdmiralsQuartersTest is FleetCommanderTestBase, OneInchTestHelpers {
    using SafeERC20 for IERC20;
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
    address public constant UNISWAP_WETH_USDC_V3_POOL =
        0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public immutable ETH_PSEUDO_ADDRESS =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address public user1 = address(0x1111);
    address public user2 = address(0x2222);
    FleetCommander public usdcFleet;
    FleetCommander public daiFleet;
    FleetCommander public wethFleet;

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

        initializeFleetCommanderWithoutArks(WETH, initialTipRate);
        wethFleet = fleetCommander;
        console.log("wethFleet", address(wethFleet));
        console.log("bufferArk", address(bufferArk));
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(address(bufferArk)),
            address(fleetCommander)
        );

        admiralsQuarters = new AdmiralsQuarters(
            ONE_INCH_ROUTER,
            address(configurationManager),
            WETH
        );

        // Grant roles
        accessManager.grantContractSpecificRole(
            ContractSpecificRoles.KEEPER_ROLE,
            address(0),
            address(this)
        );
        address _stakingRewardsManager = usdcFleet
            .getConfig()
            .stakingRewardsManager;

        deal(address(rewardTokens[0]), governor, 1000e6);
        rewardTokens[0].approve(address(_stakingRewardsManager), 1000e6);
        IFleetCommanderRewardsManager(_stakingRewardsManager)
            .notifyRewardAmount(address(rewardTokens[0]), 1000e6, 10 days);
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
        vm.label(address(wethFleet), "WETH Fleet");

        vm.label(USDC_ADDRESS, "USDC");
        vm.label(DAI_ADDRESS, "DAI");
        vm.label(WETH, "WETH");
    }

    function test_Constructor() public {
        vm.startPrank(governor);
        vm.expectRevert(abi.encodeWithSignature("InvalidRouterAddress()"));
        new AdmiralsQuarters(
            address(0),
            address(configurationManager),
            address(0)
        );
        vm.expectRevert(
            abi.encodeWithSignature("ConfigurationManagerZeroAddress()")
        );
        new AdmiralsQuarters(ONE_INCH_ROUTER, address(0), address(0));
        vm.expectRevert(abi.encodeWithSignature("InvalidNativeTokenAddress()"));
        new AdmiralsQuarters(
            ONE_INCH_ROUTER,
            address(configurationManager),
            address(0)
        );
        admiralsQuarters = new AdmiralsQuarters(
            ONE_INCH_ROUTER,
            address(configurationManager),
            WETH
        );
        assertEq(
            address(admiralsQuarters.owner()),
            governor,
            "Owner should be the governor"
        );
        assertEq(
            address(admiralsQuarters.ONE_INCH_ROUTER()),
            ONE_INCH_ROUTER,
            "OneInchRouter should be set"
        );
        assertEq(
            address(admiralsQuarters.WRAPPED_NATIVE()),
            WETH,
            "WETH should be set"
        );
        vm.stopPrank();
    }

    function test_Deposit_Reverts() public {
        // RevertsOnInvalidToken
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("InvalidToken()"));
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(address(0)), 1000e6)
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
        // RevertsOnZeroAmount
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("ZeroAmount()"));
        calls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(USDC_ADDRESS), 0)
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();

        vm.startPrank(user1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(USDC_ADDRESS), 1)
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
    }

    function test_Withdraw_Reverts() public {
        // RevertsOnInvalidToken
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("InvalidToken()"));
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.withdrawTokens,
            (IERC20(address(0)), 1000e6)
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
    }

    function test_EnterFleet_Reverts() public {
        // RevertsOnInvalidFleetCommander
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("InvalidFleetCommander()"));
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(0), 1000e6, user1)
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
        // RevertsOnInsufficientOutputAmount
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("InsufficientOutputAmount()"));
        calls[0] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(usdcFleet), 1000e6, user1)
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
    }

    function test_ExitFleet_Reverts() public {
        // RevertsOnInvalidFleetCommander
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("InvalidFleetCommander()"));
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.exitFleet,
            (address(0), 1000e6)
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
    }

    function test_Swap_Reverts() public {
        // RevertsOnInvalidToken
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("InvalidToken()"));
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.swap,
            (IERC20(address(0)), IERC20(DAI_ADDRESS), 1000e6, 0, new bytes(0))
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("InvalidToken()"));
        calls[0] = abi.encodeCall(
            admiralsQuarters.swap,
            (IERC20(DAI_ADDRESS), IERC20(address(0)), 1000e6, 0, new bytes(0))
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();

        // RevertsOnAssetMismatch
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("AssetMismatch()"));
        calls[0] = abi.encodeCall(
            admiralsQuarters.swap,
            (IERC20(DAI_ADDRESS), IERC20(DAI_ADDRESS), 1000e6, 0, new bytes(0))
        );
        admiralsQuarters.multicall(calls);
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
            (address(usdcFleet), usdcAmount / 2, address(admiralsQuarters))
        );
        enterCalls[2] = abi.encodeCall(
            admiralsQuarters.stake,
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

    function test_Deposit_Enter_Stake_WETH() public {
        uint256 wethAmount = 1e18; // 1 WETH

        // deal weth
        deal(WETH, user1, wethAmount);
        // deal eth
        deal(user1, 10 * wethAmount);
        uint256 userEthBalanceBefore = user1.balance;
        vm.startPrank(user1);
        IERC20(WETH).approve(address(admiralsQuarters), wethAmount);
        uint256 simulatedSharesAmount = wethFleet.previewDeposit(wethAmount);
        bytes[] memory enterCalls = new bytes[](2);
        enterCalls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(WETH), wethAmount)
        );
        enterCalls[1] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(wethFleet), wethAmount, address(user1))
        );

        admiralsQuarters.multicall(enterCalls);
        assertEq(
            wethFleet.balanceOf(address(admiralsQuarters)),
            0,
            "Fleet should have no shares"
        );
        assertEq(
            wethFleet.balanceOf(address(user1)),
            simulatedSharesAmount,
            "User should have received their shares"
        );
        assertEq(
            wethFleet.convertToAssets(simulatedSharesAmount),
            wethAmount,
            "User shares converted to assets should be equal to the deposit amount"
        );

        uint256 simulatedSharesAmount2 = wethFleet.previewDeposit(wethAmount);
        bytes[] memory enterCalls2 = new bytes[](3);
        enterCalls2[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(ETH_PSEUDO_ADDRESS), wethAmount)
        );
        enterCalls2[1] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(wethFleet), wethAmount, address(admiralsQuarters))
        );
        enterCalls2[2] = abi.encodeCall(
            admiralsQuarters.stake,
            (address(wethFleet), 0)
        );
        admiralsQuarters.multicall{value: wethAmount}(enterCalls2);
        uint256 userEthBalanceAfter = user1.balance;
        assertEq(
            wethAmount,
            userEthBalanceBefore - userEthBalanceAfter,
            "User should have only spent wethAmount of ETH on multicall"
        );
        assertEq(
            wethFleet.balanceOf(address(admiralsQuarters)),
            0,
            "Fleet should have no shares"
        );
        assertEq(
            IFleetCommanderRewardsManager(
                wethFleet.getConfig().stakingRewardsManager
            ).balanceOf(user1),
            simulatedSharesAmount2,
            "User should have received their shares in stakingRewardsManager"
        );

        assertEq(
            address(admiralsQuarters).balance,
            0,
            "AdmiralsQuarters should have no balance"
        );

        vm.stopPrank();
    }
    function test_EnterWithETH_ExitToETH() public {
        uint256 ethAmount = 1e18; // 1 ETH

        // Deal ETH to user1
        deal(user1, ethAmount);
        uint256 userEthBalanceBefore = user1.balance;
        uint256 userWethBalanceBefore = IERC20(WETH).balanceOf(user1);

        vm.startPrank(user1);

        // First multicall: deposit ETH and enter WETH fleet
        bytes[] memory enterCalls = new bytes[](2);
        enterCalls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(ETH_PSEUDO_ADDRESS), ethAmount)
        );
        enterCalls[1] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(wethFleet), ethAmount, user1)
        );
        admiralsQuarters.multicall{value: ethAmount}(enterCalls);

        // Verify initial state after entering fleet
        uint256 userFleetShares = wethFleet.balanceOf(user1);
        assertGt(userFleetShares, 0, "User should have WETH fleet shares");
        assertEq(
            address(admiralsQuarters).balance,
            0,
            "AdmiralsQuarters should have no ETH balance"
        );

        // Second multicall: exit fleet and withdraw as ETH
        wethFleet.approve(address(admiralsQuarters), userFleetShares);
        bytes[] memory exitCalls = new bytes[](2);
        exitCalls[0] = abi.encodeCall(
            admiralsQuarters.exitFleet,
            (address(wethFleet), type(uint256).max)
        );
        exitCalls[1] = abi.encodeCall(
            admiralsQuarters.withdrawTokens,
            (IERC20(ETH_PSEUDO_ADDRESS), 0) // 0 means withdraw all
        );
        admiralsQuarters.multicall(exitCalls);

        // Verify final state
        uint256 userEthBalanceAfter = user1.balance;
        uint256 userWethBalanceAfter = IERC20(WETH).balanceOf(user1);

        // User should have received ETH back (minus gas costs)
        assertGt(
            userEthBalanceAfter,
            userEthBalanceBefore - ethAmount,
            "User should have received ETH back (minus gas costs)"
        );

        // WETH balances should be unchanged
        assertEq(
            userWethBalanceAfter,
            userWethBalanceBefore,
            "User WETH balance should be unchanged"
        );

        // Contract balances should be 0
        assertEq(
            address(admiralsQuarters).balance,
            0,
            "AdmiralsQuarters should have no ETH balance"
        );
        assertEq(
            IERC20(WETH).balanceOf(address(admiralsQuarters)),
            0,
            "AdmiralsQuarters should have no WETH balance"
        );
        assertEq(
            wethFleet.balanceOf(user1),
            0,
            "User should have no fleet shares"
        );

        vm.stopPrank();
    }
    function test_EnterWithETH_ExitToWETH() public {
        uint256 ethAmount = 1e18; // 1 ETH

        // Deal ETH to user1
        deal(user1, ethAmount);
        uint256 userEthBalanceBefore = user1.balance;
        uint256 userWethBalanceBefore = IERC20(WETH).balanceOf(user1);

        vm.startPrank(user1);

        // First multicall: deposit ETH and enter WETH fleet
        bytes[] memory enterCalls = new bytes[](2);
        enterCalls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(ETH_PSEUDO_ADDRESS), ethAmount)
        );
        enterCalls[1] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(wethFleet), ethAmount, user1)
        );
        admiralsQuarters.multicall{value: ethAmount}(enterCalls);

        // Verify initial state after entering fleet
        uint256 userFleetShares = wethFleet.balanceOf(user1);
        assertGt(userFleetShares, 0, "User should have WETH fleet shares");
        assertEq(
            address(admiralsQuarters).balance,
            0,
            "AdmiralsQuarters should have no ETH balance"
        );

        // Second multicall: exit fleet and withdraw as ETH
        wethFleet.approve(address(admiralsQuarters), userFleetShares);
        bytes[] memory exitCalls = new bytes[](2);
        exitCalls[0] = abi.encodeCall(
            admiralsQuarters.exitFleet,
            (address(wethFleet), type(uint256).max)
        );
        exitCalls[1] = abi.encodeCall(
            admiralsQuarters.withdrawTokens,
            (IERC20(WETH), 0) // 0 means withdraw all
        );
        admiralsQuarters.multicall(exitCalls);

        // Verify final state
        uint256 userEthBalanceAfter = user1.balance;
        uint256 userWethBalanceAfter = IERC20(WETH).balanceOf(user1);

        // User should have received ETH back (minus gas costs)
        assertEq(
            userEthBalanceAfter,
            userEthBalanceBefore - ethAmount,
            "User should have received ETH back (minus gas costs)"
        );

        // WETH balances should be unchanged
        assertEq(
            userWethBalanceAfter,
            userWethBalanceBefore + ethAmount,
            "User WETH balance should increased by ethAmount"
        );

        // Contract balances should be 0
        assertEq(
            address(admiralsQuarters).balance,
            0,
            "AdmiralsQuarters should have no ETH balance"
        );
        assertEq(
            IERC20(WETH).balanceOf(address(admiralsQuarters)),
            0,
            "AdmiralsQuarters should have no WETH balance"
        );
        assertEq(
            wethFleet.balanceOf(user1),
            0,
            "User should have no fleet shares"
        );

        vm.stopPrank();
    }
    function test_Deposit_ETH_Swap_EnterFleet() public {
        uint256 ethAmount = 1e18; // 1 ETH
        uint256 minUsdcAmount = 1500e6; // Expecting at least 1500 USDC for 1 ETH

        // Deal ETH to user1
        deal(user1, ethAmount);
        uint256 userEthBalanceBefore = user1.balance;

        vm.startPrank(user1);

        // Encode unoswap data for ETH to USDC swap
        bytes memory ethToUsdcSwap = encodeUnoswapData(
            WETH,
            ethAmount,
            minUsdcAmount,
            UNISWAP_WETH_USDC_V3_POOL,
            Protocol.UniswapV3,
            false,
            false,
            false,
            false
        );

        // Create multicall for deposit ETH, swap to USDC, and enter USDC fleet
        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(ETH_PSEUDO_ADDRESS), ethAmount)
        );
        calls[1] = abi.encodeCall(
            admiralsQuarters.swap,
            (
                IERC20(WETH),
                IERC20(USDC_ADDRESS),
                ethAmount,
                minUsdcAmount,
                ethToUsdcSwap
            )
        );
        calls[2] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(usdcFleet), 0, user1)
        );
        uint256 gasBefore = gasleft();
        // Execute multicall with ETH value
        admiralsQuarters.multicall{value: ethAmount}(calls);
        uint256 gasAfter = gasleft();
        console.log("gas used : ", gasBefore - gasAfter);

        // Verify ETH was spent
        uint256 userEthBalanceAfter = user1.balance;
        assertEq(
            ethAmount,
            userEthBalanceBefore - userEthBalanceAfter,
            "User should have spent exactly ethAmount of ETH"
        );

        // Verify USDC fleet shares were received
        uint256 userUsdcShares = usdcFleet.balanceOf(user1);
        assertGt(
            userUsdcShares,
            0,
            "User should have received USDC fleet shares"
        );

        // Verify no ETH or USDC is stuck in AdmiralsQuarters
        assertEq(
            address(admiralsQuarters).balance,
            0,
            "AdmiralsQuarters should have no ETH balance"
        );
        assertEq(
            IERC20(USDC_ADDRESS).balanceOf(address(admiralsQuarters)),
            0,
            "AdmiralsQuarters should have no USDC balance"
        );

        // Verify fleet shares convert to expected amount of USDC
        uint256 usdcAmount = usdcFleet.convertToAssets(userUsdcShares);
        assertGe(
            usdcAmount,
            minUsdcAmount,
            "User should have received at least minUsdcAmount worth of shares"
        );

        vm.stopPrank();
    }

    function test_DirectUnstakeAfterStakingThroughAdmiralsQuarters() public {
        // Setup: Deposit and stake through AdmiralsQuarters
        address rewardsManager = usdcFleet.getConfig().stakingRewardsManager;
        uint256 usdcAmount = 1000e6; // 1000 USDC

        vm.startPrank(user1);

        // Deposit, enter fleet, and stake via AdmiralsQuarters
        bytes[] memory enterCalls = new bytes[](3);
        enterCalls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(USDC_ADDRESS), usdcAmount)
        );
        enterCalls[1] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(usdcFleet), usdcAmount, address(admiralsQuarters))
        );
        enterCalls[2] = abi.encodeCall(
            admiralsQuarters.stake,
            (address(usdcFleet), 0)
        );
        admiralsQuarters.multicall(enterCalls);

        // Verify stake was successful
        uint256 stakedAmount = IFleetCommanderRewardsManager(rewardsManager)
            .balanceOf(user1);
        assertGt(stakedAmount, 0, "User should have staked balance");

        // Attempt to unstake directly through rewards manager
        IFleetCommanderRewardsManager(rewardsManager)
            .unstakeAndWithdrawOnBehalfOf(user1, stakedAmount, false);

        // Verify stake amount remains unchanged
        assertEq(
            IFleetCommanderRewardsManager(rewardsManager).balanceOf(user1),
            0,
            "Staked amount should be zero"
        );
        assertEq(
            IERC20(address(usdcFleet)).balanceOf(address(admiralsQuarters)),
            0,
            "AdmiralsQuarters should have no fleet shares"
        );
        assertEq(
            IERC20(USDC_ADDRESS).balanceOf(address(user1)),
            stakedAmount,
            "User should have received back their shares"
        );

        vm.stopPrank();
    }

    function test_Deposit_Enter_Stake_Reverts() public {
        uint256 usdcAmount = 1000e6; // 1000 USDC
        vm.startPrank(user1);
        bytes[] memory enterCalls = new bytes[](3);
        enterCalls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(USDC_ADDRESS), usdcAmount)
        );
        enterCalls[1] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(usdcFleet), usdcAmount / 2, address(admiralsQuarters))
        );
        enterCalls[2] = abi.encodeCall(
            admiralsQuarters.stake,
            (address(usdcFleet), usdcAmount)
        );
        vm.expectRevert(abi.encodeWithSignature("InsufficientOutputAmount()"));
        admiralsQuarters.multicall(enterCalls);
        vm.stopPrank();
    }

    function test_unstakeAndWithdrawAssets() public {
        vm.prank(governor);
        accessManager.grantAdmiralsQuartersRole(address(admiralsQuarters));

        // First setup: stake some shares
        vm.startPrank(user1);
        uint256 depositAmount = 100e6;
        uint256 initialUserBalance = IERC20(USDC_ADDRESS).balanceOf(user1);
        IERC20(USDC_ADDRESS).approve(address(admiralsQuarters), depositAmount);

        // Deposit and stake
        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(USDC_ADDRESS), depositAmount)
        );
        calls[1] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(usdcFleet), depositAmount, address(admiralsQuarters))
        );
        calls[2] = abi.encodeCall(
            admiralsQuarters.stake,
            (address(usdcFleet), 0)
        );
        admiralsQuarters.multicall(calls);

        // Get initial balances
        address rewardsManager = usdcFleet.getConfig().stakingRewardsManager;
        uint256 initialStakedBalance = IFleetCommanderRewardsManager(
            rewardsManager
        ).balanceOf(user1);

        // Unstake shares
        uint256 unstakeAmount = initialStakedBalance / 2;
        bytes[] memory calls2 = new bytes[](1);
        calls2[0] = abi.encodeCall(
            admiralsQuarters.unstakeAndWithdrawAssets,
            (address(usdcFleet), unstakeAmount, false)
        );
        admiralsQuarters.multicall(calls2);

        // Verify balances after unstaking
        assertEq(
            IFleetCommanderRewardsManager(rewardsManager).balanceOf(user1),
            initialStakedBalance - unstakeAmount,
            "Incorrect staked balance after unstake"
        );
        assertEq(
            IERC20(USDC_ADDRESS).balanceOf(address(user1)),
            initialUserBalance - unstakeAmount,
            "Incorrect user balance"
        );
        vm.stopPrank();
    }

    function test_UnstakeAndWithdrawAll() public {
        vm.prank(governor);
        accessManager.grantAdmiralsQuartersRole(address(admiralsQuarters));

        // First setup: stake some shares
        vm.startPrank(user1);
        uint256 depositAmount = 100e6;
        IERC20(USDC_ADDRESS).approve(address(admiralsQuarters), depositAmount);

        // Deposit and stake
        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(USDC_ADDRESS), depositAmount)
        );
        calls[1] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(usdcFleet), 0, address(admiralsQuarters))
        );
        calls[2] = abi.encodeCall(
            admiralsQuarters.stake,
            (address(usdcFleet), 0)
        );
        admiralsQuarters.multicall(calls);

        // Get initial balances
        address rewardsManager = usdcFleet.getConfig().stakingRewardsManager;
        uint256 initialStakedBalance = IFleetCommanderRewardsManager(
            rewardsManager
        ).balanceOf(user1);
        assertGt(initialStakedBalance, 0, "Should have staked balance");
        uint256 initialUserBalance = IERC20(USDC_ADDRESS).balanceOf(user1);

        // Unstake all, exit fleet, and withdraw
        bytes[] memory withdrawCalls = new bytes[](1);
        withdrawCalls[0] = abi.encodeCall(
            admiralsQuarters.unstakeAndWithdrawAssets,
            (address(usdcFleet), 0, false) // 0 amount means unstake all
        );
        admiralsQuarters.multicall(withdrawCalls);

        // Verify final balances
        assertEq(
            IFleetCommanderRewardsManager(rewardsManager).balanceOf(user1),
            0,
            "Should have no staked balance"
        );
        assertEq(
            IERC20(address(usdcFleet)).balanceOf(address(admiralsQuarters)),
            0,
            "AdmiralsQuarters should have no fleet shares"
        );
        assertEq(
            IERC20(USDC_ADDRESS).balanceOf(address(admiralsQuarters)),
            0,
            "AdmiralsQuarters should have no USDC"
        );
        assertGe(
            IERC20(USDC_ADDRESS).balanceOf(user1),
            initialUserBalance + depositAmount - 1, // -1 for potential rounding
            "User should have received back their USDC"
        );
        vm.stopPrank();
    }

    function test_unstakeAndWithdrawAssetsRevert_NotStaked() public {
        vm.startPrank(user1);
        vm.expectRevert(); // Will revert due to insufficient balance
        admiralsQuarters.unstakeAndWithdrawAssets(
            address(usdcFleet),
            100e6,
            false
        );
        vm.stopPrank();
    }

    function test_unstakeAndWithdrawAssetsRevert_InvalidFleet() public {
        vm.startPrank(user1);
        vm.expectRevert(IAdmiralsQuartersErrors.InvalidFleetCommander.selector);
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.unstakeAndWithdrawAssets,
            (address(0x123), 100e6, false)
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
    }

    function test_unstakeAndWithdrawAssets_Full() public {
        vm.prank(governor);
        accessManager.grantAdmiralsQuartersRole(address(admiralsQuarters));

        // First setup: stake some shares
        vm.startPrank(user1);
        uint256 depositAmount = 100e6;
        uint256 initialUserBalance = IERC20(USDC_ADDRESS).balanceOf(user1);
        IERC20(USDC_ADDRESS).approve(address(admiralsQuarters), depositAmount);

        // Deposit and stake
        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(USDC_ADDRESS), depositAmount)
        );
        calls[1] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(usdcFleet), depositAmount, address(admiralsQuarters))
        );
        calls[2] = abi.encodeCall(
            admiralsQuarters.stake,
            (address(usdcFleet), 0)
        );
        admiralsQuarters.multicall(calls);

        // Get initial balances
        address rewardsManager = usdcFleet.getConfig().stakingRewardsManager;

        // Unstake all shares (using 0 amount)
        bytes[] memory calls2 = new bytes[](1);
        calls2[0] = abi.encodeCall(
            admiralsQuarters.unstakeAndWithdrawAssets,
            (address(usdcFleet), 0, false)
        );
        admiralsQuarters.multicall(calls2);

        // Verify balances after unstaking
        assertEq(
            IFleetCommanderRewardsManager(rewardsManager).balanceOf(user1),
            0,
            "Should have no staked balance"
        );
        assertEq(
            IERC20(USDC_ADDRESS).balanceOf(address(user1)),
            initialUserBalance,
            "All shares should be in AdmiralsQuarters"
        );
        vm.stopPrank();
    }

    function test_unstakeAndWithdrawAssets_Full_ClaimRewards() public {
        vm.prank(governor);
        accessManager.grantAdmiralsQuartersRole(address(admiralsQuarters));

        // First setup: stake some shares
        vm.startPrank(user1);
        uint256 depositAmount = 100e6;
        uint256 initialUserBalance = IERC20(USDC_ADDRESS).balanceOf(user1);
        IERC20(USDC_ADDRESS).approve(address(admiralsQuarters), depositAmount);

        // Deposit and stake
        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(USDC_ADDRESS), depositAmount)
        );
        calls[1] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(usdcFleet), depositAmount, address(admiralsQuarters))
        );
        calls[2] = abi.encodeCall(
            admiralsQuarters.stake,
            (address(usdcFleet), 0)
        );
        admiralsQuarters.multicall(calls);

        // Get initial balances
        address rewardsManager = usdcFleet.getConfig().stakingRewardsManager;
        vm.warp(block.timestamp + 10 days);
        // Unstake all shares (using 0 amount) and claim rewards
        bytes[] memory calls2 = new bytes[](1);
        calls2[0] = abi.encodeCall(
            admiralsQuarters.unstakeAndWithdrawAssets,
            (address(usdcFleet), 0, true)
        );
        admiralsQuarters.multicall(calls2);

        // Verify balances after unstaking
        assertEq(
            IFleetCommanderRewardsManager(rewardsManager).balanceOf(user1),
            0,
            "Should have no staked balance"
        );
        assertEq(
            IERC20(USDC_ADDRESS).balanceOf(user1),
            initialUserBalance,
            "User should have received all USDC"
        );
        assertEq(
            usdcFleet.balanceOf(address(admiralsQuarters)),
            0,
            "AdmiralsQuarters should have no shares"
        );
        assertEq(
            IERC20(USDC_ADDRESS).balanceOf(address(admiralsQuarters)),
            0,
            "AdmiralsQuarters should have no USDC"
        );

        // Check rewards balance
        uint256 rewardsBalance = rewardTokens[0].balanceOf(user1);
        assertGt(rewardsBalance, 0, "User should have received rewards");

        // Ensure no tokens are stuck in AdmiralsQuarters
        assertEq(
            rewardTokens[0].balanceOf(address(admiralsQuarters)),
            0,
            "No rewards should be stuck in AdmiralsQuarters"
        );
        vm.stopPrank();
    }

    function test_unstakeAndWithdrawAssets_DirectUnstakeReverts() public {
        // First setup: stake some shares
        vm.startPrank(user1);
        uint256 depositAmount = 100e6;
        IERC20(USDC_ADDRESS).approve(address(admiralsQuarters), depositAmount);

        // Deposit and stake
        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(USDC_ADDRESS), depositAmount)
        );
        calls[1] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(usdcFleet), depositAmount, address(admiralsQuarters))
        );
        calls[2] = abi.encodeCall(
            admiralsQuarters.stake,
            (address(usdcFleet), 0)
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
        // Try to unstake directly from rewards manager
        address rewardsManager = usdcFleet.getConfig().stakingRewardsManager;
        vm.expectRevert(
            IFleetCommanderRewardsManager.CallerNotAdmiralsQuarters.selector
        );
        IFleetCommanderRewardsManager(rewardsManager)
            .unstakeAndWithdrawOnBehalfOf(user1, 100e6, false);
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
            (address(usdcFleet), usdcAmount / 2, user1)
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
            (address(daiFleet), 0, user1)
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
            (address(daiFleet), 0, user1)
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
            (address(daiFleet), daiAmount, user1)
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
            (address(usdcFleet), 0, user1)
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
            (address(usdcFleet), usdcAmount, user1)
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
            (address(usdcFleet), halfUsdcAmount, user1)
        );
        withdrawSwapAndDepositCalls[3] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(daiFleet), 0, user1)
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
            (address(usdcFleet), usdcAmount, user1)
        );
        depositCalls[2] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(DAI_ADDRESS), daiAmount)
        );
        depositCalls[3] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(daiFleet), daiAmount, user1)
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
            (address(daiFleet), 0, user1)
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
            (address(usdcFleet), 0, user1)
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
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(USDC_ADDRESS), usdcAmount)
        );
        admiralsQuarters.multicall(calls);

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
        calls[0] = abi.encodeCall(
            admiralsQuarters.swap,
            (
                IERC20(USDC_ADDRESS),
                IERC20(DAI_ADDRESS),
                usdcAmount,
                unrealisticMinReturn,
                usdcToDaiSwap
            )
        );
        admiralsQuarters.multicall(calls);

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
        uint256 withdrawAmount = usdcAmount / 2;
        deal(USDC_ADDRESS, user1, usdcAmount);

        vm.startPrank(user1);

        // Deposit USDC
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(USDC_ADDRESS), usdcAmount)
        );
        calls[1] = abi.encodeCall(
            admiralsQuarters.withdrawTokens,
            (IERC20(USDC_ADDRESS), withdrawAmount)
        );
        admiralsQuarters.multicall(calls);

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
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(USDC_ADDRESS), user1UsdcAmount)
        );
        admiralsQuarters.multicall(calls);
        calls[0] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(usdcFleet), user1UsdcAmount, user1)
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();

        // User 2 deposits DAI and enters DAI fleet
        vm.startPrank(user2);
        calls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(DAI_ADDRESS), user2DaiAmount)
        );
        admiralsQuarters.multicall(calls);
        calls[0] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(daiFleet), user2DaiAmount, user2)
        );
        admiralsQuarters.multicall(calls);
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

    function test_RewardsExploitViaStakeOnBehalfOf() public {
        // Setup initial conditions
        uint256 usdcAmount = 1000e6; // 1000 USDC
        IFleetCommanderRewardsManager rewardsManager = IFleetCommanderRewardsManager(
                usdcFleet.getConfig().stakingRewardsManager
            );
        // Mint initial USDC for testing
        deal(address(rewardTokens[0]), user1, usdcAmount);

        // Advance time to accumulate all the rewards
        vm.warp(block.timestamp + 11 days);

        // User1 deposits and stakes legitimately
        vm.startPrank(user1);
        IERC20(USDC_ADDRESS).approve(address(usdcFleet), usdcAmount);
        uint256 user1shares = usdcFleet.deposit(usdcAmount, user1);
        IERC20(address(usdcFleet)).approve(
            address(rewardsManager),
            user1shares
        );
        rewardsManager.stakeOnBehalfOf(user1, user1shares);

        vm.stopPrank();

        uint256 rewardsBalanceUser1 = IERC20(rewardTokens[0]).balanceOf(user1);

        vm.prank(user1);
        rewardsManager.getReward();

        uint256 rewardsBalanceUser1After = IERC20(rewardTokens[0]).balanceOf(
            user1
        );

        assertEq(
            (rewardsBalanceUser1After - rewardsBalanceUser1) / 1e6,
            0,
            "User1 should have not received any rewards"
        );
    }

    function test_unstakeAndWithdrawAssets_Full_ClaimRewards_WithDust() public {
        vm.prank(governor);
        accessManager.grantAdmiralsQuartersRole(address(admiralsQuarters));

        // Wait for first reward period to finish
        vm.warp(block.timestamp + 10 days + 1);

        // Calculate a safe reward amount based on duration
        uint256 rewardDuration = 10 days;
        // We want rewardRate (reward/duration) to be less than balance/duration
        // So reward needs to be less than balance
        uint256 rewardAmount = 100e18; // Much smaller amount to ensure rate is acceptable

        // Notify rewards
        vm.startPrank(governor);
        address rewardsManager = usdcFleet.getConfig().stakingRewardsManager;
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            // First deal tokens to the rewards manager
            deal(address(rewardTokens[i]), governor, rewardAmount);
            rewardTokens[i].approve(address(rewardsManager), rewardAmount);

            // Then notify the reward amount
            IFleetCommanderRewardsManager(rewardsManager).notifyRewardAmount(
                address(rewardTokens[i]),
                rewardAmount,
                rewardDuration
            );
        }
        vm.stopPrank();

        // User stakes
        vm.startPrank(user1);
        uint256 depositAmount = 100e6;
        uint256 initialUserBalance = IERC20(USDC_ADDRESS).balanceOf(user1);
        IERC20(USDC_ADDRESS).approve(address(admiralsQuarters), depositAmount);

        // Deposit and stake
        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(USDC_ADDRESS), depositAmount)
        );
        calls[1] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(usdcFleet), depositAmount, address(admiralsQuarters))
        );
        calls[2] = abi.encodeCall(
            admiralsQuarters.stake,
            (address(usdcFleet), 0)
        );
        admiralsQuarters.multicall(calls);

        // Verify initial staking state
        assertGt(
            IFleetCommanderRewardsManager(rewardsManager).balanceOf(user1),
            0,
            "User should have staked balance before unstaking"
        );

        // Let 11 days pass (slightly more than reward period)
        vm.warp(block.timestamp + 11 days);

        // Verify rewards are available
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            assertGt(
                IFleetCommanderRewardsManager(rewardsManager).earned(
                    user1,
                    address(rewardTokens[i])
                ),
                0,
                "User should have earned rewards before unstaking"
            );
        }

        // Unstake all shares and claim rewards
        bytes[] memory calls2 = new bytes[](1);
        calls2[0] = abi.encodeCall(
            admiralsQuarters.unstakeAndWithdrawAssets,
            (address(usdcFleet), 0, true)
        );
        admiralsQuarters.multicall(calls2);

        // Verify final state
        assertEq(
            IFleetCommanderRewardsManager(rewardsManager).balanceOf(user1),
            0,
            "Should have no staked balance"
        );
        assertEq(
            IERC20(USDC_ADDRESS).balanceOf(user1),
            initialUserBalance,
            "User should have received all USDC"
        );
        assertEq(
            usdcFleet.balanceOf(address(admiralsQuarters)),
            0,
            "AdmiralsQuarters should have no shares"
        );
        assertEq(
            IERC20(USDC_ADDRESS).balanceOf(address(admiralsQuarters)),
            0,
            "AdmiralsQuarters should have no USDC"
        );

        // Check rewards balances
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            uint256 userRewardBalance = rewardTokens[i].balanceOf(user1);
            assertGt(
                userRewardBalance,
                90e18, // Should have received most of the 100 tokens
                "User should have received majority of rewards"
            );

            uint256 rewardsManagerBalance = rewardTokens[i].balanceOf(
                rewardsManager
            );
            assertGt(
                rewardsManagerBalance,
                0,
                "Some dust should remain in RewardsManager"
            );
            assertLt(
                rewardsManagerBalance,
                1e16, // Less than 0.01 tokens
                "Only dust amount should remain in RewardsManager"
            );
        }

        vm.stopPrank();
    }

    function test_RemoveRewardToken_FailsWithTooMuchBalance() public {
        vm.prank(governor);
        accessManager.grantAdmiralsQuartersRole(address(admiralsQuarters));

        // Get rewards manager from fleet config
        vm.startPrank(governor);
        address rewardsManager = usdcFleet.getConfig().stakingRewardsManager;

        // First clear any existing rewards from setup
        vm.warp(block.timestamp + 10 days + 1); // Wait for existing rewards period to finish

        // Add new rewards with significant balance
        uint256 rewardAmount = 100e18;
        uint256 rewardDuration = 10 days;

        // Deal tokens and notify rewards
        deal(address(rewardTokens[0]), governor, rewardAmount);
        rewardTokens[0].approve(address(rewardsManager), rewardAmount);
        IFleetCommanderRewardsManager(rewardsManager).notifyRewardAmount(
            address(rewardTokens[0]),
            rewardAmount,
            rewardDuration
        );

        vm.warp(block.timestamp + 10 days + 1);

        // Try to remove reward token while significant balance remains
        // Should fail because balance is above dust threshold
        vm.expectRevert(
            abi.encodeWithSignature(
                "RewardTokenStillHasBalance(uint256)",
                100000000001000000000
            )
        );
        IFleetCommanderRewardsManager(rewardsManager).removeRewardToken(
            address(rewardTokens[0])
        );
        vm.stopPrank();
    }

    function test_RemoveRewardToken_SucceedsWithDust() public {
        vm.prank(governor);
        accessManager.grantAdmiralsQuartersRole(address(admiralsQuarters));

        // First clear any existing rewards from setup
        vm.warp(block.timestamp + 10 days + 1);

        ERC20 usdc = ERC20(USDC_ADDRESS);
        address rewardsManager = usdcFleet.getConfig().stakingRewardsManager;

        // Setup: Give user1 some USDC and approve spending
        vm.startPrank(user1);
        deal(address(usdc), user1, 1000e6); // 1000 USDC
        usdc.approve(address(admiralsQuarters), type(uint256).max);
        vm.stopPrank();

        // Calculate a reward amount that divides evenly by the duration
        uint256 rewardAmount = 54e18;
        uint256 rewardDuration = 3.65 days;

        // First transfer USDC to the rewards manager and setup rewards
        vm.startPrank(governor);
        deal(address(usdc), governor, rewardAmount);
        usdc.approve(address(rewardsManager), rewardAmount);
        IFleetCommanderRewardsManager(rewardsManager).notifyRewardAmount(
            address(usdc),
            rewardAmount,
            rewardDuration
        );
        vm.stopPrank();

        // User stakes into the fleet
        vm.startPrank(user1);
        uint256 depositAmount = 100e6;
        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (usdc, depositAmount)
        );
        calls[1] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(usdcFleet), depositAmount, address(admiralsQuarters))
        );
        calls[2] = abi.encodeCall(
            admiralsQuarters.stake,
            (address(usdcFleet), 0)
        );
        admiralsQuarters.multicall(calls);

        // Wait for rewards period
        vm.warp(block.timestamp + rewardDuration + 1);

        // Unstake and claim rewards
        bytes[] memory unstakeCalls = new bytes[](1);
        unstakeCalls[0] = abi.encodeCall(
            admiralsQuarters.unstakeAndWithdrawAssets,
            (address(usdcFleet), 0, true)
        );
        admiralsQuarters.multicall(unstakeCalls);
        vm.stopPrank();

        // Now try to remove the reward token as governor
        vm.startPrank(governor);
        IFleetCommanderRewardsManager(rewardsManager).removeRewardToken(
            address(usdc)
        );
        vm.stopPrank();
    }

    function test_ClaimMerkleRewards_RevertInvalidRewardsRedeemer() public {
        uint256[] memory indices = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        bytes32[][] memory proofs = new bytes32[][](1);

        vm.startPrank(user1);
        vm.expectRevert(
            IAdmiralsQuartersErrors.InvalidRewardsRedeemer.selector
        );
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.claimMerkleRewards,
            (user1, indices, amounts, proofs, address(0))
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
    }

    function test_ClaimGovernanceRewards_RevertInvalidRewardsManager() public {
        vm.startPrank(user1);
        vm.expectRevert(IAdmiralsQuartersErrors.InvalidRewardsManager.selector);
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.claimGovernanceRewards,
            (address(0), USDC_ADDRESS)
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
    }

    function test_ClaimGovernanceRewards_RevertInvalidToken() public {
        vm.startPrank(user1);
        vm.expectRevert(IAdmiralsQuartersErrors.InvalidToken.selector);
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.claimGovernanceRewards,
            (address(usdcFleet), address(0))
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
    }
}
