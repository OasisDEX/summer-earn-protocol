// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AggregatorV3Interface} from "../../interfaces/external/Chainlink/AggregatorV3Interface.sol";

/**
 * @title ChainlinkPriceConsumer
 * @notice Abstract base contract for contracts that read prices from Chainlink
 *         AggregatorV3 feeds.
 *
 * @dev Exposes `_getPrice(feed)` which fetches the latest round answer and
 *      reverts with `OraclePriceZero` when the reported value is zero or
 *      negative (stale / circuit-breaker state).
 */
abstract contract ChainlinkPriceConsumer {
    /// @notice Reverts when a Chainlink feed returns a non-positive price.
    error OraclePriceZero();

    /**
     * @notice Returns the latest price from a Chainlink AggregatorV3 feed.
     * @dev Reverts with `OraclePriceZero` when `latestRoundData` returns a
     *      value ≤ 0. The remaining round fields (roundId, updatedAt, answeredInRound)
     *      are intentionally ignored — callers that need freshness checks should
     *      extend this function.
     * @param feed  Address of the AggregatorV3Interface-compatible price feed.
     * @return      The latest answer cast to uint256.
     */
    function _getPrice(address feed) internal view returns (uint256) {
        (, int256 raw, , , ) = AggregatorV3Interface(feed).latestRoundData();
        if (raw <= 0) revert OraclePriceZero();
        return uint256(raw);
    }
}
