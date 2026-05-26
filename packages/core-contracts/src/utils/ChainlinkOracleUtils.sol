// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AggregatorV3Interface} from "../interfaces/external/Chainlink/AggregatorV3Interface.sol";

/**
 * @notice Bundles a Chainlink feed's latest answer with its decimal precision.
 * @dev Keeping value and decimals together prevents accidentally pairing a
 *      price with the wrong feed's decimal count when passing through call stacks.
 *      Defined at file level so it can be imported directly by name without
 *      the `ChainlinkOracleUtils.` prefix.
 */
struct ChainlinkOraclePrice {
    /// @notice Raw answer returned by `latestRoundData` cast to uint256.
    uint256 value;
    /// @notice Decimal precision of the feed (e.g. 8 for most USD feeds).
    uint8 decimals;
}

/**
 * @title ChainlinkOracleUtils
 * @notice Pure/view math helpers for computations that involve two independent
 *         Chainlink USD price feeds.
 *
 * @dev Call `_getPrice` to read a single price, or call `convertAmount` to
 *      fetch both prices and perform the conversion in one shot, receiving
 *      the prices back for reuse.
 */
library ChainlinkOracleUtils {
    /// @notice Scaling factor applied to cross-rate results (1e18).
    uint256 internal constant PRECISION = 1e18;

    /// @notice Maximum age (in seconds) of a Chainlink round before it is
    ///         considered stale. Set to 24 hours to accommodate feeds with
    ///         a 24-hour heartbeat (e.g. USDC/USD on Ethereum mainnet).
    uint256 internal constant MAX_ORACLE_STALENESS = 86400;

    /// @notice Reverts when a Chainlink feed returns a non-positive price.
    error ChainlinkOraclePriceZero();

    /// @notice Reverts when a Chainlink feed's last update is older than
    ///         `MAX_ORACLE_STALENESS` seconds.
    error ChainlinkOracleStalePrice(
        address feed,
        uint256 updatedAt,
        uint256 currentTime
    );

    /**
     * @notice Computes the cross-rate between two assets whose prices are
     *         independently quoted in USD by Chainlink feeds.
     *
     * @dev Formula: (out.value / outScale) / (in.value / inScale) × PRECISION
     *      Collapsed into a single `mulDiv` to prevent intermediate rounding.
     *      Result is always scaled to `PRECISION` (1e18).
     *
     * @param inPrice   ChainlinkOraclePrice for the in-asset/USD feed.
     * @param outPrice  ChainlinkOraclePrice for the out-asset/USD feed.
     * @return          Cross-rate scaled by `PRECISION`
     *                  (outAsset units per inAsset unit × 1e18).
     */
    function crossRate(
        ChainlinkOraclePrice memory inPrice,
        ChainlinkOraclePrice memory outPrice
    ) internal pure returns (uint256) {
        uint256 inOracleScale = 10 ** uint256(inPrice.decimals);
        uint256 outOracleScale = 10 ** uint256(outPrice.decimals);
        return
            Math.mulDiv(
                outPrice.value * inOracleScale, // outPrice normalised to inFeed precision
                PRECISION,
                inPrice.value * outOracleScale // inPrice normalised to outFeed precision
            );
    }

    /**
     * @notice Converts an input asset amount to its equivalent output asset amount
     *         using two independent Chainlink USD price feeds, fetching prices and
     *         decimals from the provided addresses.
     *
     * @dev Formula (long form):
     *        inAmount × (inPrice / 10^inOracleDec)    ← inAsset USD value
     *                 ÷ (outPrice / 10^outOracleDec)  ← outAsset USD price (reciprocal)
     *                 × (10^outAssetDec / 10^inAssetDec) ← decimal normalisation
     *      Collapsed into a single `mulDiv` to prevent intermediate rounding.
     *
     *      Both `ChainlinkOraclePrice` structs are returned alongside `outAmount` so callers
     *      can reuse them (e.g. for a price-guard check via `crossRate`) without
     *      fetching the feeds a second time.
     *      Reverts with `ChainlinkOraclePriceZero` if either feed returns a non-positive value.
     *
     * @param inAmount   Amount of the input asset (in its native token decimals).
     * @param inAsset    Input ERC20 token (used to fetch decimals).
     * @param inFeed     Chainlink AggregatorV3 feed address for the in-asset/USD price.
     * @param outAsset   Output ERC20 token (used to fetch decimals).
     * @param outFeed    Chainlink AggregatorV3 feed address for the out-asset/USD price.
     * @return outAmount   Expected output amount in the output asset's native decimals.
     * @return inPrice     ChainlinkOraclePrice fetched from `inFeed` (value + decimals).
     * @return outPrice    ChainlinkOraclePrice fetched from `outFeed` (value + decimals).
     */
    function convertAmount(
        uint256 inAmount,
        IERC20 inAsset,
        address inFeed,
        IERC20 outAsset,
        address outFeed
    )
        internal
        view
        returns (
            uint256 outAmount,
            ChainlinkOraclePrice memory inPrice,
            ChainlinkOraclePrice memory outPrice
        )
    {
        // Each _getPrice call is a separate stack frame, keeping convertAmount
        // within the EVM's 16-slot stack limit despite the many local variables.
        inPrice = _getPrice(inFeed);
        outPrice = _getPrice(outFeed);

        uint8 inAssetDec = IERC20Metadata(address(inAsset)).decimals();
        uint8 outAssetDec = IERC20Metadata(address(outAsset)).decimals();

        // Combined scale factors for each side (oracle decimals + asset decimals).
        uint256 inNorm = 10 **
            (uint256(inPrice.decimals) + uint256(inAssetDec));
        uint256 outNorm = 10 **
            (uint256(outPrice.decimals) + uint256(outAssetDec));
        outAmount = Math.mulDiv(
            inAmount * inPrice.value,
            outNorm,
            outPrice.value * inNorm
        );
    }

    /**
     * @dev Reads a single Chainlink feed, validates the price is positive, and
     *      validates the round is not older than `MAX_ORACLE_STALENESS`.
     *      Extracted into its own frame to keep `convertAmount` within the EVM
     *      16-slot stack limit.
     */
    function _getPrice(
        address feed
    ) internal view returns (ChainlinkOraclePrice memory price) {
        (, int256 raw, , uint256 updatedAt, ) = AggregatorV3Interface(feed)
            .latestRoundData();
        if (raw <= 0) revert ChainlinkOraclePriceZero();
        if (block.timestamp - updatedAt > MAX_ORACLE_STALENESS) {
            revert ChainlinkOracleStalePrice(feed, updatedAt, block.timestamp);
        }
        price = ChainlinkOraclePrice({
            value: uint256(raw),
            decimals: AggregatorV3Interface(feed).decimals()
        });
    }
}
