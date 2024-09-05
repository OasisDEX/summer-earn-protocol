// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import {SimpleSwapArk, ArkParams} from "../../src/contracts/arks/SimpleSwapArk.sol";
import {BaseSwapArk} from "../../src/contracts/arks/BaseSwapArk.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import {ConfigurationManager, ConfigurationManagerParams} from "../../src/contracts/ConfigurationManager.sol";
import {PercentageUtils, Percentage} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {OneInchHelpers} from "../helpers/OneInchHelpers.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract SwapArkTest is Test, OneInchHelpers {
    using PercentageUtils for uint256;
    SimpleSwapArk public swapArk;
    IERC20 public usdc;
    IERC20 public DAI;
    ProtocolAccessManager public accessManager;
    ConfigurationManager public configManager;
    address public constant ONE_INCH_ROUTER =
        0x111111125421cA6dc452d289314280a0f8842A65;
    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant DAI_ADDRESS =
        0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant UNISWAP_USDC_DAI_V3_POOL =
        0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168;

    address public user = address(0x1);
    address public governor = address(0x2);
    address public commander = address(0x3);
    uint256 constant FORK_BLOCK = 20576616;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), FORK_BLOCK);

        usdc = IERC20(USDC_ADDRESS);
        DAI = IERC20(DAI_ADDRESS);

        accessManager = new ProtocolAccessManager(governor);
        configManager = new ConfigurationManager(
            ConfigurationManagerParams({
                accessManager: address(accessManager),
                raft: address(0x3),
                tipJar: address(0x4)
            })
        );

        ArkParams memory params = ArkParams({
            accessManager: address(accessManager),
            configurationManager: address(configManager),
            token: address(usdc),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            name: "SimpleSwapArk",
            requiresKeeperData: false
        });

        swapArk = new SimpleSwapArk(params, address(DAI));

        vm.startPrank(governor);

        swapArk.grantCommanderRole(commander);
        vm.stopPrank();

        deal(address(usdc), commander, 1000e6);
        vm.label(USDC_ADDRESS, "USDC_ADDRESS");
        vm.label(DAI_ADDRESS, "DAI_ADDRESS");
        vm.label(UNISWAP_USDC_DAI_V3_POOL, "UNISWAP_USDC_DAI_V3_POOL");
    }

    function testBoard() public {
        uint256 amount = 100e6;

        bytes memory usdcToDaiSwap = encodeUnoswapData(
            USDC_ADDRESS,
            amount,
            995e17, // 0.5% slippage in DAI terms
            UNISWAP_USDC_DAI_V3_POOL,
            Protocol.UniswapV3,
            false,
            false,
            false,
            false
        );

        SimpleSwapArk.SwapCallData memory swapData = BaseSwapArk.SwapCallData({
            fromToken: usdc,
            toToken: DAI,
            fromTokenAmount: amount,
            minTokensReceived: 95e18,
            swapCalldata: usdcToDaiSwap
        });

        vm.startPrank(commander);
        usdc.approve(address(swapArk), amount);
        swapArk.board(amount, abi.encode(swapData));
        vm.stopPrank();
        uint256 daiBalanceAtOneToOneRatio = 100e18;
        assertApproxEqRel(
            DAI.balanceOf(address(swapArk)),
            daiBalanceAtOneToOneRatio,
            Percentage.unwrap(swapArk.slippagePercentage()),
            "Amount of DAI shall be withing assumed slippage assuming 1:1 ratios"
        );
    }

    function testDisembark() public {
        // First, we need to board some tokens
        testBoard();
        console.log("taotalseets", swapArk.totalAssets());
        console.log("daibalance ", DAI.balanceOf(address(swapArk)));
        uint256 amount = 100e6; // Amount in USDC (6 decimals)
        uint256 sdaiAmount = DAI.balanceOf(address(swapArk)); // Equivalent amount in DAI (18 decimals)

        bytes memory daiToUsdcSwap = encodeUnoswapData(
            DAI_ADDRESS,
            sdaiAmount,
            995e5, // 0.5% slippage in USDC terms
            UNISWAP_USDC_DAI_V3_POOL,
            Protocol.UniswapV3,
            false,
            false,
            true, // zeroForOne should be true for DAI -> USDC
            false
        );

        SimpleSwapArk.SwapCallData memory swapData = BaseSwapArk.SwapCallData({
            fromToken: DAI,
            toToken: usdc,
            fromTokenAmount: sdaiAmount,
            minTokensReceived: 95e6, // 5% slippage in USDC
            swapCalldata: daiToUsdcSwap
        });

        uint256 initialUserUsdcBalance = usdc.balanceOf(commander);
        uint256 initialArkSdaiBalance = DAI.balanceOf(address(swapArk));

        uint256 _totalAssets = swapArk.totalAssets();
        vm.prank(commander);
        swapArk.disembark(_totalAssets, abi.encode(swapData));

        uint256 finalUserUsdcBalance = usdc.balanceOf(commander);
        uint256 finalArkSdaiBalance = DAI.balanceOf(address(swapArk));

        assertApproxEqRel(
            finalArkSdaiBalance,
            initialArkSdaiBalance - sdaiAmount,
            Percentage.unwrap(swapArk.slippagePercentage()),
            "DAI balance of SimpleSwapArk should decrease by approximately the disembarked amount"
        );

        assertApproxEqRel(
            finalUserUsdcBalance - initialUserUsdcBalance,
            amount,
            Percentage.unwrap(swapArk.slippagePercentage()),
            "USDC balance of user should increase by approximately the disembarked amount"
        );
    }

    function testSetSlippagePercentage() public {
        Percentage onePercent = PercentageUtils.fromFraction(1, 100);
        vm.prank(governor);
        swapArk.setSlippagePercentage(PercentageUtils.fromFraction(1, 100)); // 1%

        assertEq(
            Percentage.unwrap(swapArk.slippagePercentage()),
            Percentage.unwrap(onePercent),
            "Slippage percentage should be updated"
        );
    }

    function testFailSetSlippagePercentageTooHigh() public {
        Percentage elevenPercent = PercentageUtils.fromFraction(11, 100);
        vm.prank(governor);
        swapArk.setSlippagePercentage(elevenPercent); // 11%
    }

    function testFailBoardWithoutSwapData() public {
        vm.prank(user);
        swapArk.board(100e6, "");
    }

    function testFailDisembarkWithoutSwapData() public {
        vm.prank(user);
        swapArk.disembark(100e18, "");
    }

    function testTotalAssets() public {
        assertEq(
            swapArk.totalAssets(),
            1000e18,
            "Total assets should match DAI balance"
        );
    }
}
