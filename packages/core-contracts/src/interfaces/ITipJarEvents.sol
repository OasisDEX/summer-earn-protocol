// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/**
 * @title ITipJarEvents
 * @notice Interface for events emitted by the TipJar contract
 */
interface ITipJarEvents {
    /**
     * @notice Emitted when a new tip stream is added to the TipJar
     * @param recipient The address of the recipient for the new tip stream
     * @param allocation The allocation percentage for the new tip stream (in basis points, where 10000 = 100%)
     * @param minimumTerm The minimum duration (as a UNIX timestamp) during which this tip stream cannot be modified or removed
     */
    event TipStreamAdded(address indexed recipient, uint256 allocation, uint256 minimumTerm);

    /**
     * @notice Emitted when a tip stream is removed from the TipJar
     * @param recipient The address of the recipient whose tip stream was removed
     */
    event TipStreamRemoved(address indexed recipient);

    /**
     * @notice Emitted when an existing tip stream is updated
     * @param recipient The address of the recipient whose tip stream was updated
     * @param newAllocation The new allocation percentage for the tip stream (in basis points, where 10000 = 100%)
     * @param newMinimumTerm The new minimum duration (as a UNIX timestamp) during which this tip stream cannot be modified or removed
     */
    event TipStreamUpdated(address indexed recipient, uint256 newAllocation, uint256 newMinimumTerm);

    /**
     * @notice Emitted when the TipJar distributes collected tips from a FleetCommander
     * @param fleetCommander The address of the FleetCommander contract from which tips were distributed
     * @param totalDistributed The total amount of underlying assets distributed to all recipients
     */
    event TipJarShaken(address indexed fleetCommander, uint256 totalDistributed);
}