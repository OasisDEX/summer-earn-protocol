// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title AggregatorV3Interface
 * @notice Standard interface for Chainlink Price Feeds.
 */
interface AggregatorV3Interface {
    /**
     * @notice Get the number of decimals in the price.
     * @return The number of decimals.
     */
    function decimals() external view returns (uint8);

    /**
     * @notice Get the description of the price feed.
     * @return The description string.
     */
    function description() external view returns (string memory);

    /**
     * @notice Get the version of the price feed.
     * @return The version number.
     */
    function version() external view returns (uint256);

    /**
     * @notice Get the data of a specific round.
     * @param _roundId The round ID to query.
     * @return roundId The round ID.
     * @return answer The price.
     * @return startedAt Timestamp when the round started.
     * @return updatedAt Timestamp when the round was updated.
     * @return answeredInRound The round ID in which the answer was resolved.
     */
    function getRoundData(
        uint80 _roundId
    )
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    /**
     * @notice Get the data of the latest round.
     * @return roundId The round ID.
     * @return answer The price.
     * @return startedAt Timestamp when the round started.
     * @return updatedAt Timestamp when the round was updated.
     * @return answeredInRound The round ID in which the answer was resolved.
     */
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}
