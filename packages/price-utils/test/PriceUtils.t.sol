// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import "../contracts/PriceUtils.sol";

contract PriceUtilsTest is Test {
    using PriceUtils for Price;
    using PriceUtils for uint256;

    /**
        .quote() tests
     */
    function test_quote_simple() public pure {
        uint256 baseAmount = 1e18;
        uint256 quoteAmount = 5e18;

        Price memory price = toPrice(baseAmount, quoteAmount);

        uint256 inputQuoteAmount = 5e18;

        uint256 outputAmount = price.quote(inputQuoteAmount);

        assertEq(outputAmount, 1e18);
    }

    function test_quote_complex() public pure {
        uint256 baseAmount = 123456789e18;
        uint256 quoteAmount = 987654321e18;

        Price memory price = toPrice(baseAmount, quoteAmount);

        uint256 inputQuoteAmount = 555555555e18;

        uint256 outputAmount = price.quote(inputQuoteAmount);

        // expected = (inputQuoteAmount * baseAmount) / quoteAmount
        uint256 expected = (inputQuoteAmount * baseAmount) / quoteAmount;

        assertEq(outputAmount, expected);
    }

    function test_quote_differentDecimals() public pure {
        {
            uint256 baseAmount = 1e6; // USDC
            uint256 quoteAmount = 2e18; // ETH

            Price memory price = toPrice(baseAmount, quoteAmount);

            uint256 inputQuoteAmount = 10e18; // 10 ETH

            uint256 outputAmount = price.quote(inputQuoteAmount);

            assertEq(outputAmount, 5e6); // should be 5e6 USDC
        }

        {
            uint256 baseAmount = 1e18; // ETH
            uint256 quoteAmount = 3000e6; // USDC

            Price memory price = toPrice(baseAmount, quoteAmount);

            uint256 inputQuoteAmount = 15000e6; // 15000 USDC

            uint256 outputAmount = price.quote(inputQuoteAmount);

            assertEq(outputAmount, 5e18); // should be 5 ETH
        }
    }

    /**
        .invert() tests
     */
    function test_invert() public pure {
        uint256 baseAmount = 1e18;
        uint256 quoteAmount = 2000e18;

        Price memory price = toPrice(baseAmount, quoteAmount);
        Price memory invertedPrice = price.invert();

        uint256 inputQuoteAmount = 4000e18;
        uint256 inputBaseAmount = 2e18;

        uint256 normalOutputAmount = price.quote(inputQuoteAmount);
        uint256 invertedOutputAmount = invertedPrice.quote(inputBaseAmount);

        assertEq(normalOutputAmount, inputBaseAmount);
        assertEq(invertedOutputAmount, inputQuoteAmount);
    }

    function test_invert_decimals() public pure {
        {
            uint256 baseAmount = 1e6; // USDC
            uint256 quoteAmount = 3000e18; // ETH

            Price memory price = toPrice(baseAmount, quoteAmount);
            Price memory invertedPrice = price.invert();

            uint256 inputQuoteAmount = 6000e18; // 6000 ETH
            uint256 inputBaseAmount = 2e6; // 2 USDC

            uint256 normalOutputAmount = price.quote(inputQuoteAmount);
            uint256 invertedOutputAmount = invertedPrice.quote(inputBaseAmount);

            assertEq(normalOutputAmount, inputBaseAmount);
            assertEq(invertedOutputAmount, inputQuoteAmount);
        }

        {
            uint256 baseAmount = 1e18; // ETH
            uint256 quoteAmount = 2500e6; // USDC

            Price memory price = toPrice(baseAmount, quoteAmount);
            Price memory invertedPrice = price.invert();

            uint256 inputQuoteAmount = 5000e6; // 5000 USDC
            uint256 inputBaseAmount = 2e18; // 2 ETH

            uint256 normalOutputAmount = price.quote(inputQuoteAmount);
            uint256 invertedOutputAmount = invertedPrice.quote(inputBaseAmount);

            assertEq(normalOutputAmount, inputBaseAmount);
            assertEq(invertedOutputAmount, inputQuoteAmount);
        }
    }

    /**
        Compounded prices tests
     */
    function test_compoundPrice_simple() public pure {
        uint256 priceABase = 1e18; // ETH
        uint256 priceAQuote = 2e18; // SUMR

        uint256 priceBBase = 1e18; // ETH
        uint256 priceBQuote = 5e18; // DOGE

        Price memory priceA = toPrice(priceABase, priceAQuote);
        Price memory priceB = toPrice(priceBBase, priceBQuote);

        uint256 inputAmount = 4e18; // SUMR

        uint256 outputAAmount = priceA.quote(inputAmount); // in ETH = 2e18
        uint256 outputBAmount = priceB.invert().quote(outputAAmount); // in DOGE = 10e18

        assertEq(outputAAmount, 2e18);
        assertEq(outputBAmount, 10e18);
    }

    function test_compoundPrice_complex() public pure {
        uint256 priceABase = 123456789e18; // ETH
        uint256 priceAQuote = 987654321e18; // SUMR

        uint256 priceBBase = 111111111e18; // ETH
        uint256 priceBQuote = 333333333e18; // DOGE

        Price memory priceA = toPrice(priceABase, priceAQuote);
        Price memory priceB = toPrice(priceBBase, priceBQuote);

        uint256 inputAmount = 555555555e18; // SUMR

        uint256 outputAAmount = priceA.quote(inputAmount); // in ETH
        uint256 outputBAmount = priceB.invert().quote(outputAAmount); // in DOGE

        // expectedA = (inputAmount * priceABase) / priceAQuote
        uint256 expectedA = (inputAmount * priceABase) / priceAQuote;
        // expectedB = (outputAAmount * priceBQuote) / priceBBase
        uint256 expectedB = (expectedA * priceBQuote) / priceBBase;

        assertEq(outputAAmount, expectedA);
        assertEq(outputBAmount, expectedB);
    }

    function test_compoundPrice_decimals() public pure {
        uint256 priceABase = 1e6; // USDC
        uint256 priceAQuote = 2e18; // SUMR

        uint256 priceBBase = 100000e6; // USDC
        uint256 priceBQuote = 1e8; // WBTC

        Price memory priceA = toPrice(priceABase, priceAQuote);
        Price memory priceB = toPrice(priceBBase, priceBQuote);

        uint256 inputAmount = 400000e18; // SUMR

        uint256 outputAAmount = priceA.quote(inputAmount);
        uint256 outputBAmount = priceB.invert().quote(outputAAmount);

        assertEq(outputAAmount, 200000e6);
        assertEq(outputBAmount, 2e8);
    }

    /**
        .mul() and .div() tests
     */
    function test_mul() public pure {
        uint256 priceABase = 10000e9; // SUMR
        uint256 priceAQuote = 1e8; // WBTC

        uint256 priceBBase = 1e8; // WBTC
        uint256 priceBQuote = 100000e6; // USDC

        Price memory priceA = toPrice(priceABase, priceAQuote);
        Price memory priceB = toPrice(priceBBase, priceBQuote);

        uint256 inputAmount = 200000e6; // USDC

        uint256 outputAmount = inputAmount.mul(priceB).mul(priceA);

        assertEq(outputAmount, 20000e9);
    }

    function test_div() public pure {
        uint256 priceABase = 100000e6; // USDC
        uint256 priceAQuote = 2e18; // SUMR

        uint256 priceBBase = 1e18; // SUMR
        uint256 priceBQuote = 2e8; // WBTC

        Price memory priceA = toPrice(priceABase, priceAQuote);
        Price memory priceB = toPrice(priceBBase, priceBQuote);

        uint256 inputAmount = 200000e6; // USDC

        uint256 outputAmount = inputAmount.div(priceA).div(priceB);

        assertEq(outputAmount, 8e8);
    }

    function test_mul_div() public pure {
        uint256 priceABase = 1e6; // USDC
        uint256 priceAQuote = 2e18; // SUMR

        uint256 priceBBase = 100000e6; // USDC
        uint256 priceBQuote = 1e8; // WBTC

        Price memory priceA = toPrice(priceABase, priceAQuote);
        Price memory priceB = toPrice(priceBBase, priceBQuote);

        uint256 inputAmount = 400000e18; // SUMR

        uint256 outputAmount = inputAmount.mul(priceA).div(priceB);

        assertEq(outputAmount, 2e8);
    }
}
