// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
  The price structure holds the base/quote ratio as well as the decimals of both assets
  to allow for proper conversions between amounts of base and quote assets.
 */
struct Price {
    uint256 baseAmount; // Amount of base asset
    uint256 quoteAmount; // Amount of quote asset
}
