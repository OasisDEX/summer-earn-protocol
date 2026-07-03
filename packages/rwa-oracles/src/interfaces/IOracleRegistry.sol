// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IOracleRegistryErrors} from "./IOracleRegistryErrors.sol";
import {IOracleRegistryEvents} from "./IOracleRegistryEvents.sol";

/**
 * @title IOracleRegistry
 * @notice Interface for the Oracle Registry that maps asset tickers and addresses to their respective price oracles.
 */
interface IOracleRegistry is IOracleRegistryErrors, IOracleRegistryEvents {
    /**
     * @notice Registers or updates a price oracle for a given ticker and asset address.
     * @param ticker The string symbol of the asset.
     * @param asset The address of the asset contract.
     * @param oracle The address of the price oracle contract.
     */
    function setOracle(
        string calldata ticker,
        address asset,
        address oracle
    ) external;

    /**
     * @notice Retrieves the oracle address associated with a given ticker symbol.
     * @param ticker The string symbol of the asset.
     * @return The address of the price oracle contract.
     */
    function getOracleByTicker(
        string calldata ticker
    ) external view returns (address);

    /**
     * @notice Retrieves the oracle address associated with a given asset address.
     * @param asset The address of the asset.
     * @return The address of the price oracle contract.
     */
    function getOracleByAsset(address asset) external view returns (address);
}
