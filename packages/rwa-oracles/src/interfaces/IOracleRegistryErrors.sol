// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IOracleRegistryErrors
 * @notice Interface defining errors used in OracleRegistry.
 */
interface IOracleRegistryErrors {
    /**
     * @notice Reverted when the provided ticker string is empty or invalid.
     */
    error InvalidTicker();

    /**
     * @notice Reverted when the provided asset address is zero or invalid.
     */
    error InvalidAsset();

    /**
     * @notice Reverted when the provided oracle address is zero or invalid.
     */
    error InvalidOracle();

    /**
     * @notice Reserved; not currently thrown by OracleRegistry (zero-address
     *         checks use InvalidAsset / InvalidOracle instead).
     */
    error InvalidAddress();
}
