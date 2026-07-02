// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IOracleRegistryEvents
 * @notice Interface defining events emitted by OracleRegistry.
 */
interface IOracleRegistryEvents {
    /**
     * @notice Emitted when a new oracle is registered or updated for a ticker and asset.
     * @param ticker The string symbol of the asset.
     * @param asset The address of the asset contract.
     * @param oracle The address of the price oracle contract.
     */
    event OracleSet(
        string indexed ticker,
        address indexed asset,
        address indexed oracle
    );
}
