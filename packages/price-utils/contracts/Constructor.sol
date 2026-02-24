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
