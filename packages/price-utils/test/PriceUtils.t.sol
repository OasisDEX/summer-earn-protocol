// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import "../contracts/PriceUtils.sol";

contract PriceUtilsTest is Test {
    using PriceUtils for uint256;

    function test_FromFraction() public pure {
        uint256 priceRate = 200e18;

        uint256 inputAmount = 3e18;

        uint256 outputAmount = priceRate.toOutputAmount(inputAmount);

        assertEq(outputAmount, 600e18);
    }
}
