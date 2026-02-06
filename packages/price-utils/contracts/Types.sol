// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {UD60x18, ud, intoUint256} from "@prb/math/src/UD60x18.sol";

/**
  The price structure holds the base/quote ratio as well as the decimals of both assets
  to allow for proper conversions between amounts of base and quote assets.
 */
struct Price {
    UD60x18 baseAmount; // Amount of base asset
    UD60x18 quoteAmount; // Amount of quote asset
}
