// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

/**
 * @title ITipJarEvents
 * @notice Interface for events emitted by the TipJar contract
 */
interface ITipJarEvents {
    /**
     * @notice Emitted when a new tip stream is added to the TipJar
     * @param recipient The address of the recipient for the new tip stream
     * @param allocation The allocation percentage for the new tip stream
     * @param lockedUntilEpoch The minimum duration (as a UNIX timestamp) during which this tip stream cannot be
     * modified or removed
     */
    event TipStreamAdded(
        address indexed recipient,
        Percentage allocation,
        uint256 lockedUntilEpoch
    );

    /**
     * @notice Emitted when a tip stream is removed from the TipJar
     * @param recipient The address of the recipient whose tip stream was removed
     */
    event TipStreamRemoved(address indexed recipient);

    /**
     * @notice Emitted when an existing tip stream is updated
     * @param recipient The address of the recipient whose tip stream was updated
     * @param newAllocation The new allocation percentage for the tip stream
     * @param newLockedUntilEpoch The new minimum duration (as a UNIX timestamp) during which this tip stream cannot be
     * modified or removed
     */
    event TipStreamUpdated(
        address indexed recipient,
        Percentage newAllocation,
        uint256 newLockedUntilEpoch
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
}
