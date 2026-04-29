// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Price} from "./Types.sol";

/**
    @notice Creates a Price type from a base and quote amount

    @param baseAmount The amount of the base asset with the given decimals
    @param quoteAmount The amount of the quote asset with the given decimals

    @return The resulting Price type
 */
function toPrice(
    uint256 baseAmount,
    uint256 quoteAmount
) pure returns (Price memory) {
    return Price({baseAmount: baseAmount, quoteAmount: quoteAmount});
}

/**
    @notice Creates a Price type from an oracle price

    @param baseAmount The amount of the base asset
    @param quoteDecimals The decimals of the quote asset
    @param oracleDecimals The decimals of the oracle
    @param oraclePrice The price from the oracle

    @return The resulting Price type
 */
function toPriceFromOraclePrice(
    uint256 baseAmount,
    int256 oraclePrice,
    uint8 oracleDecimals,
    uint8 quoteDecimals
) pure returns (Price memory) {
    uint256 quoteAmountAdjusted = uint256(oraclePrice);

    if (oracleDecimals > quoteDecimals) {
        quoteAmountAdjusted =
            uint256(oraclePrice) /
            (10 ** (oracleDecimals - quoteDecimals));
    } else {
        quoteAmountAdjusted =
            uint256(oraclePrice) *
            (10 ** (quoteDecimals - oracleDecimals));
    }

    return Price({baseAmount: baseAmount, quoteAmount: quoteAmountAdjusted});
}
