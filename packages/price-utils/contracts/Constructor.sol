// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ud} from "@prb/math/src/UD60x18.sol";

import {Price} from "./Types.sol";
import {DEFAULT_DECIMALS} from "./Constants.sol";

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
    return Price({baseAmount: ud(baseAmount), quoteAmount: ud(quoteAmount)});
}
