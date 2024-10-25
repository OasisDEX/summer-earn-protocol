// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ITipJar} from "../interfaces/ITipJar.sol";

/**
 * @title ITipJarEvents
 * @notice Interface for events emitted by the TipJar contract
 */
interface ITipJarEvents {
    /**
     * @notice Emitted when a new tip stream is added to the TipJar
     * @param tipStream The tip stream that was added
     */
    event TipStreamAdded(ITipJar.TipStream tipStream);

    /**
     * @notice Emitted when a tip stream is removed from the TipJar
     * @param recipient The address of the recipient whose tip stream was removed
     */
    event TipStreamRemoved(address indexed recipient);

    /**
     * @notice Emitted when an existing tip stream is updated
     * @param oldTipStream The old tip stream
     * @param newTipStream The new tip stream
     */
    event TipStreamUpdated(
        ITipJar.TipStream oldTipStream,
        ITipJar.TipStream newTipStream
    );

    /**
     * @notice Emitted when the TipJar distributes collected tips from a FleetCommander
     * @param fleetCommander The address of the FleetCommander contract from which tips were distributed
     * @param totalDistributed The total amount of underlying assets distributed to all recipients
     */
    event TipJarShaken(
        address indexed fleetCommander,
        uint256 totalDistributed
    );

    /**
     * @notice Emitted when the TipJar is paused
     * @param account The address that triggered the pause
     */
    event TipJarPaused(address indexed account);

    /**
     * @notice Emitted when the TipJar is unpaused
     * @param account The address that triggered the unpause
     */
    event TipJarUnpaused(address indexed account);
}
