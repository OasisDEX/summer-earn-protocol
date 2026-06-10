// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title AggregatorV3Interface
 * @notice Standard Chainlink price feed interface
 */
interface AggregatorV3Interface {
    /// @notice Returns the number of decimals in the feed's answer
    /// @return The number of decimals
    function decimals() external view returns (uint8);

    /// @notice Returns a human-readable description of the feed
    /// @return The feed description
    function description() external view returns (string memory);

    /// @notice Returns the version number of the aggregator
    /// @return The version
    function version() external view returns (uint256);

    /// @notice Returns the data for a specific round
    /// @param _roundId The round id to query
    /// @return roundId The round id of the returned data
    /// @return answer The price answer for the round
    /// @return startedAt The timestamp when the round started
    /// @return updatedAt The timestamp when the round was last updated
    /// @return answeredInRound The round in which the answer was computed
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

    /// @notice Returns the data for the latest round
    /// @return roundId The round id of the returned data
    /// @return answer The latest price answer
    /// @return startedAt The timestamp when the round started
    /// @return updatedAt The timestamp when the round was last updated
    /// @return answeredInRound The round in which the answer was computed
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
