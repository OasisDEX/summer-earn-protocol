// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {OneInchTestHelpers} from "./OneInchTestHelpers.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test, console} from "forge-std/Test.sol";

type Address is uint256;

contract OneInchHelpersTest is Test, OneInchTestHelpers {
    address public constant ONE_INCH_ROUTER =
        0x111111125421cA6dc452d289314280a0f8842A65;
    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant DAI_ADDRESS =
        0x6B175474E89094C44Da98b954EedeAC495271d0F;

    address public user1 = address(0x1);
    address public user2 = address(0x2);

    uint256 constant FORK_BLOCK = 20576616;

    function setUp() public {
        console.log("Setting up AdmiralsQuartersTest");

        vm.createSelectFork(vm.rpcUrl("mainnet"), FORK_BLOCK);

        // Mint tokens for users
        deal(USDC_ADDRESS, user1, 1000e6);
        deal(USDC_ADDRESS, user2, 1000e6);
    }

    function test_SwapUSDCToDAI() public {
        uint256 usdcBalanceBeforeSwap = IERC20(USDC_ADDRESS).balanceOf(user1);
        uint256 usdcAmount = 1000000000; // 100 USDC
        uint256 minDaiAmount = 99e18; // Expecting at least 99 DAI (adjust based on current rates)

        // Encode unoswap data
        bytes memory unoswapData = encodeUnoswapData(
            USDC_ADDRESS,
            usdcAmount,
            minDaiAmount,
            0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168, // Example DEX address, replace with actual DEX address
            Protocol.UniswapV3, // Assuming UniswapV3, adjust as needed
            false, // shouldUnwrapWeth
            false, // shouldWrapWeth
            false, // zeroForOne
            false // usePermit2
        );

        vm.prank(user1);
        IERC20(USDC_ADDRESS).approve(ONE_INCH_ROUTER, usdcAmount);

        vm.prank(user1);
        (bool success, bytes memory returnData) = ONE_INCH_ROUTER.call(
            unoswapData
        );

        require(success, "Swap failed");
        uint256 returnAmount = abi.decode(returnData, (uint256));

        console.log("DAI received:", returnAmount);

        assertEq(
            IERC20(USDC_ADDRESS).balanceOf(user1),
            usdcBalanceBeforeSwap - usdcAmount,
            "Incorrect USDC balance after swap"
        );
        assertGe(
            IERC20(DAI_ADDRESS).balanceOf(user1),
            minDaiAmount,
            "Incorrect DAI balance after swap"
        );
    }

    function test_DecodeUnoswapData() public pure {
        (
            address token,
            uint256 amount,
            uint256 minReturn,
            address dex,
            Protocol protocol,
            bool shouldUnwrapWeth,
            bool shouldWrapWeth,
            bool usePermit2
        ) = decodeUnoswapData(
                hex"83800a8e000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000000000003b9aca00000000000000000000000000000000000000000000000035a9834f640f45a5332800000000000000000000005777d92f208679db4b9778590fa3cab3ac9e21680709215a"
            );

        // Assert the decoded values
        assertEq(
            token,
            0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
            "Incorrect token address"
        );
        assertEq(amount, 1000000000, "Incorrect amount");
        assertEq(minReturn, 989892129812136699187, "Incorrect minReturn");
        assertEq(
            dex,
            0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168,
            "Incorrect dex address"
        );
        assertEq(uint256(protocol), 1, "Incorrect protocol"); // 1 corresponds to UniswapV3
        assertEq(shouldUnwrapWeth, false, "Incorrect shouldUnwrapWeth");
        assertEq(shouldWrapWeth, false, "Incorrect shouldWrapWeth");
        assertEq(usePermit2, false, "Incorrect usePermit2");

        // Print the decoded values for inspection
        console.log("Token:", token);
        console.log("Amount:", amount);
        console.log("Min Return:", minReturn);
        console.log("DEX:", dex);
        console.log("Protocol:", uint256(protocol));
        console.log("Should Unwrap WETH:", shouldUnwrapWeth);
        console.log("Should Wrap WETH:", shouldWrapWeth);
        console.log("Use Permit2:", usePermit2);
    }
}
