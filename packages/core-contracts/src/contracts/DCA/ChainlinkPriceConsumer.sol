// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AggregatorV3Interface} from "../../interfaces/external/Chainlink/AggregatorV3Interface.sol";
import {ChainlinkOracleUtils, ChainlinkOraclePrice} from "./ChainlinkOracleUtils.sol";

/**
 * @title ChainlinkPriceConsumer
 * @notice Abstract base contract for contracts that read prices from Chainlink
 *         AggregatorV3 feeds.
 *
 * @dev Exposes `_getPrice(feed)` which fetches the latest round answer and
 *      decimal precision, bundled into a `ChainlinkOraclePrice`.
 *      Reverts with `ChainlinkOraclePriceZero` when the reported
 *      value is zero or negative (stale / circuit-breaker state).
 */
abstract contract ChainlinkPriceConsumer {
    /**
     * @notice Returns the latest price and decimal precision from a Chainlink
     *         AggregatorV3 feed as a single `ChainlinkOraclePrice` struct.
     * @dev Reverts with `ChainlinkOraclePriceZero` when `latestRoundData` returns a
     *      value ≤ 0. The remaining round fields (roundId, updatedAt, answeredInRound)
     *      are intentionally ignored — callers that need freshness checks should
     *      extend this function.
     * @param feed  Address of the AggregatorV3Interface-compatible price feed.
     * @return      ChainlinkOraclePrice containing the latest answer and the feed's decimals.
     */
    function _getPrice(
        address feed
    ) internal view returns (ChainlinkOraclePrice memory) {
        (, int256 raw, , , ) = AggregatorV3Interface(feed).latestRoundData();
        if (raw <= 0) revert ChainlinkOracleUtils.ChainlinkOraclePriceZero();
        return
            ChainlinkOraclePrice({
                value: uint256(raw),
                decimals: AggregatorV3Interface(feed).decimals()
            });
    }
}
