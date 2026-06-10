// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IRwaOracleEvents
 * @notice Interface defining events emitted by the Real World Asset (RWA) Oracle contract.
 */
interface IRwaOracleEvents {
    /**
     * @notice Emitted when the price is successfully updated.
     * @param price The new price value.
     * @param timestamp The timestamp of the price update.
     * @param roundId The ID of the round associated with this update.
     */
    event PriceUpdated(int256 price, uint256 timestamp, uint256 roundId);

    /**
     * @notice Emitted when a new authorized signer is added.
     * @param signer The address of the added signer.
     */
    event SignerAdded(address indexed signer);

    /**
     * @notice Emitted when an authorized signer is removed.
     * @param signer The address of the removed signer.
     */
    event SignerRemoved(address indexed signer);

    /**
     * @notice Emitted when the signature verification threshold is updated.
     * @param threshold The new signature threshold.
     */
    event ThresholdUpdated(uint256 threshold);
}

