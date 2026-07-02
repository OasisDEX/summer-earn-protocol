// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IRwaOracleErrors} from "./IRwaOracleErrors.sol";
import {IRwaOracleEvents} from "./IRwaOracleEvents.sol";

/**
 * @title IRwaOracle
 * @notice Interface for the Real World Asset (RWA) Oracle, managing authorized signers, signature verification thresholds, and price updates.
 */
interface IRwaOracle is IRwaOracleErrors, IRwaOracleEvents {
    /**
     * @notice Updates the current asset price by validating signed price payloads.
     * @param price The new price value.
     * @param timestamp The timestamp of the price generation.
     * @param signatures Array of signatures validating the price update.
     */
    function updatePrice(
        int256 price,
        uint256 timestamp,
        bytes[] calldata signatures
    ) external;

    /**
     * @notice Authorizes a new signer to participate in price updates.
     * @param signer The address of the new signer.
     */
    function addSigner(address signer) external;

    /**
     * @notice Removes an authorized signer.
     * @param signer The address of the signer to remove.
     */
    function removeSigner(address signer) external;

    /**
     * @notice Sets the signature threshold required to accept a price update.
     * @param threshold The number of unique signatures required.
     */
    function setThreshold(uint256 threshold) external;
}
