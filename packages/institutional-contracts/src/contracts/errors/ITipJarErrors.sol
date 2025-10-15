// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

/**
 * @title ITipJarErrors
 * @dev This file contains custom error definitions for the TipJar contract.
 * @notice These custom errors provide more gas-efficient and informative error handling
 * compared to traditional require statements with string messages.
 */
interface ITipJarErrors {
    /**
     * @notice Thrown when an invalid recipient address is provided.
     */
    error InvalidTipStreamRecipient();

    /**
     * @notice Thrown when attempting to create a tip stream for a recipient that already has one.
     * @param recipient The address of the recipient with an existing tip stream.
     */
    error TipStreamAlreadyExists(address recipient);

    /**
     * @notice Thrown when an invalid allocation percentage is provided for a tip stream.
     * @param invalidAllocation The invalid allocation percentage.
     */
    error InvalidTipStreamAllocation(Percentage invalidAllocation);

    /**
     * @notice Thrown when the total allocation of tip streams exceeds 100%.
     */
    error TotalAllocationExceedsOneHundredPercent();

    /**
     * @notice Thrown when attempting to interact with a non-existent tip stream.
     * @param recipient The address of the recipient for which the tip stream does not exist.
     */
    error TipStreamDoesNotExist(address recipient);

    /**
     * @notice Thrown when attempting to modify a locked tip stream.
     * @param recipient The address of the recipient with the locked tip stream.
     */
    error TipStreamLocked(address recipient);

    /**
     * @notice Thrown when an invalid treasury address is provided.
     */
    error InvalidTreasuryAddress();

    /**
     * @notice Thrown when an invalid FleetCommander address is provided.
     */
    error InvalidFleetCommanderAddress();

    /**
     * @notice Thrown when a tip stream is locked for too long.
     * @param recipient The address of the recipient with the locked tip stream.
     */
    error TipStreamLockedForTooLong(address recipient);
}
