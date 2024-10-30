// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ITipJarErrors} from "../errors/ITipJarErrors.sol";
import {ITipJarEvents} from "../events/ITipJarEvents.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

/**
 * @title ITipJar
 * @notice Interface for managing tip streams and distributing accumulated tips
 */
interface ITipJar is ITipJarEvents, ITipJarErrors {
    struct TipStream {
        address recipient;
        Percentage allocation;
        uint256 lockedUntilEpoch;
    }

    /**
     * @notice Adds a new tip stream
     * @param tipStream The tip stream to add
     * @return lockedUntilEpoch The epoch until which this tip stream is locked
     */
    function addTipStream(
        TipStream memory tipStream
    ) external returns (uint256 lockedUntilEpoch);

    /**
     * @notice Removes an existing tip stream
     * @param recipient The address of the tip stream recipient to remove
     */
    function removeTipStream(address recipient) external;

    /**
     * @notice Updates an existing tip stream
     * @param tipStream The updated tip stream data
     * @param shakeAllFleetCommanders If true, performs a global shake of all fleet commanders before updating
     */
    function updateTipStream(
        TipStream memory tipStream,
        bool shakeAllFleetCommanders
    ) external;

    /**
     * @notice Retrieves a specific tip stream's information
     * @param recipient The address of the tip stream recipient
     * @return TipStream struct with the recipient's tip stream details
     */
    function getTipStream(
        address recipient
    ) external view returns (TipStream memory);

    /**
     * @notice Retrieves all tip streams' information
     * @return An array of all TipStream structs
     */
    function getAllTipStreams() external view returns (TipStream[] memory);

    /**
     * @notice Calculates the total allocation percentage across all tip streams
     * @return total The total allocation as a Percentage
     */
    function getTotalAllocation() external view returns (Percentage total);

    /**
     * @notice Distributes accumulated tips from a single FleetCommander
     * @param fleetCommander The FleetCommander contract to distribute tips from
     * @dev Redeems shares, distributes assets to recipients, and sends remaining to treasury
     */
    function shake(address fleetCommander) external;

    /**
     * @notice Distributes accumulated tips from multiple FleetCommanders
     * @param fleetCommanders An array of FleetCommander contracts to distribute tips from
     * @dev Calls shake() for each FleetCommander in the array
     */
    function shakeMultiple(address[] calldata fleetCommanders) external;

    /**
     * @notice Pauses the TipJar, preventing shake operations
     */
    function pause() external;

    /**
     * @notice Unpauses the TipJar, allowing shake operations
     */
    function unpause() external;
}
