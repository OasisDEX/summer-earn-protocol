// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./IHyperBeatPricer.sol";

/**
 * @title IHyperBeatOracle
 * @notice Interface for HyperBeat Oracle (wrapper around Pricer for compatibility)
 */
interface IHyperBeatOracle {
    /**
     * @notice Gets the exchange rate in base 18 (WAD format)
     * @return The exchange rate with 18 decimals
     */
    function getDataInBase18() external view returns (uint256);

    /**
     * @notice Gets the pricer address
     * @return The address of the pricer
     */
    function pricer() external view returns (IHyperBeatPricer);
}
