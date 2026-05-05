// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

/**
 * @title Superstate Continuous Price Oracle Interface
 * @notice Interface to read the current NAV (share price) from Superstate's Oracle or Chainlink.
 */
interface ISuperstateOracle {
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
    function decimals() external view returns (uint8);
}
