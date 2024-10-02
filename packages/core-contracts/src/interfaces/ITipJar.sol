// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {ITipJarErrors} from "../errors/ITipJarErrors.sol";
import {ITipJarEvents} from "../events/ITipJarEvents.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

/**
 * @title ITipJar
 * @notice Interface for the TipJar contract, which manages the collection and distribution of tips
 * @dev This contract allows for the creation, modification, and removal of tip streams,
 *      as well as the distribution of accumulated tips to recipients
 */
interface ITipJar is ITipJarEvents, ITipJarErrors {
    /**
     * @notice Struct representing a tip stream
     * @param recipient The address of the tip stream recipient
     * @param allocation The percentage of tips allocated to this stream
     * @param lockedUntilEpoch The epoch until which this tip stream is locked and cannot be modified
     */
    struct TipStream {
        address recipient;
        Percentage allocation;
        uint256 lockedUntilEpoch;
    }

    /**
     * @notice Adds a new tip stream
     * @param recipient The address of the tip stream recipient
     * @param allocation The percentage of tips allocated to this stream
     * @param lockedUntilEpoch The epoch until which this tip stream is locked
     */
    function addTipStream(
        address recipient,
        Percentage allocation,
        uint256 lockedUntilEpoch
    ) external;

    /**
     * @notice Removes an existing tip stream
     * @param recipient The address of the tip stream recipient to remove
     */
    function removeTipStream(address recipient) external;

    /**
     * @notice Updates an existing tip stream
     * @param recipient The address of the tip stream recipient to update
     * @param newAllocation The new percentage allocation for the tip stream
     * @param newLockedUntilEpoch The new epoch until which this tip stream is locked
     */
    function updateTipStream(
        address recipient,
        Percentage newAllocation,
        uint256 newLockedUntilEpoch
    ) external;

    /**
     * @notice Retrieves information about a specific tip stream
     * @param recipient The address of the tip stream recipient
     * @return TipStream struct containing the tip stream information
     */
    function getTipStream(
        address recipient
    ) external view returns (TipStream memory);

    /**
     * @notice Retrieves information about all tip streams
     * @return An array of TipStream structs containing all tip stream information
     */
    function getAllTipStreams() external view returns (TipStream[] memory);

    /**
     * @notice Calculates the total allocation percentage across all tip streams
     * @return The total allocation as a Percentage
     */
    function getTotalAllocation() external view returns (Percentage);

    /**
     * @notice Distributes accumulated tips from a single FleetCommander
     * @param fleetCommander The address of the FleetCommander contract to distribute tips from
     */
    function shake(address fleetCommander) external;

    /**
     * @notice Distributes accumulated tips from multiple FleetCommanders
     * @param fleetCommanders An array of FleetCommander contract addresses to distribute tips from
     */
    function shakeMultiple(address[] calldata fleetCommanders) external;
}
