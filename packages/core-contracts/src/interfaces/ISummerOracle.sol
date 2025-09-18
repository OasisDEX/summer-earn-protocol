// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IOracle} from "./morpho/IOracle.sol";
import {IPriceOracle} from "./euler/IPriceOracle.sol";

/**
 * @title ISummerOracle
 * @notice Unified oracle interface used to quote between a FleetCommander ERC4626 vault (fleet shares)
 *         and its underlying ERC20 asset, while exposing a Morpho-compatible price feed.
 *
 * @dev This interface composes two widely used oracle shapes:
 * - Morpho's IOracle: a single scalar price via `price()`, scaled to 1e36, that answers
 *   "how many loan tokens for 1 unit of collateral token". For SummerOracle the
 *   collateral token is the FleetCommander share token and the loan token is the underlying asset.
 * - Euler's IPriceOracle: quote functions `getQuote` / `getQuotes` for base/quote conversions.
 *
 * Semantics and scaling:
 * - Decimals parity: Fleet shares and the underlying asset MUST have the same decimals. Deployments
 *   that violate this invariant should revert with `InvalidDecimals()`.
 * - Morpho price scaling (1e36): `price()` returns the value of 1 full share (10^shareDecimals)
 *   in asset units, scaled by 1e36 and divided by 10^assetDecimals. With equal decimals this is
 *   effectively `assetsPerShare * 1e36 / 10^decimals`.
 * - Euler quotes: `getQuote(inAmount, base, quote)` and `getQuotes(...)` support only the pairs
 *   base=fleet, quote=asset and base=asset, quote=fleet. Implementations should revert with
 *   `UnsupportedPair(base, quote)` for any other pair.
 */
interface ISummerOracle is IOracle, IPriceOracle {
    /**
     * @notice Error emitted when a base/quote pair other than (fleet, asset) or (asset, fleet) is requested.
     * @param fleet The base token provided when the unsupported pair was requested
     * @param quote The quote token provided when the unsupported pair was requested
     */
    error UnsupportedPair(address fleet, address quote);

    /**
     * @notice Error emitted when an invalid FleetCommander address is provided at construction time.
     */
    error InvalidFleet();

    /**
     * @notice Error emitted when an invalid or zero asset is observed for the provided fleet.
     */
    error InvalidAsset();

    /**
     * @notice Error emitted when fleet share decimals and underlying asset decimals differ.
     * @dev SummerOracle requires equal decimals to maintain simple, precise conversions between
     *      shares and assets without additional scaling artifacts.
     */
    error InvalidDecimals();

    /**
     * @notice Returns the current conversion rate of 1 full share to assets (assets per share unit).
     * @dev This exposes the raw ERC4626 `convertToAssets(10^shareDecimals)` without Morpho scaling.
     *      It is intended for integrators who need an exact assets-per-share figure.
     * @return assetsForOneShareUnit The number of underlying asset units received for one full share
     */
    function getRate() external view returns (uint256 assetsForOneShareUnit);
}
