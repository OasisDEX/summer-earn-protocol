// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title ICrossChainFleetCommanderErrors
 * @dev This file contains custom error definitions for the CrossChainFleetCommander contract.
 * @notice These custom errors provide more gas-efficient and informative error handling
 * compared to traditional require statements with string messages.
 */
interface ICrossChainFleetCommanderErrors {
    /**
     * @notice Thrown when users try to use sync functions instead of async ones
     * @param message The error message explaining which async function to use
     */
    error CrossChainFleetCommanderUseAsyncFunction(string message);

    /**
     * @notice Thrown when not all Arks are synced before processing operations
     */
    error CrossChainFleetCommanderNotAllArksSynced();

    /**
     * @notice Thrown when the operation amount is below the minimum required amount
     * @param amount The amount provided
     * @param minAmount The minimum required amount
     */
    error CrossChainFleetCommanderAmountBelowMinimum(
        uint256 amount,
        uint256 minAmount
    );

    /**
     * @notice Thrown when the operation queue is full
     * @param currentSize The current queue size
     * @param maxSize The maximum allowed queue size
     */
    error CrossChainFleetCommanderQueueFull(
        uint256 currentSize,
        uint256 maxSize
    );

    /**
     * @notice Thrown when trying to process an operation that has already been processed
     * @param operationId The ID of the operation that was already processed
     */
    error CrossChainFleetCommanderOperationAlreadyProcessed(
        uint256 operationId
    );

    /**
     * @notice Thrown when trying to cancel an operation that has already been processed
     * @param operationId The ID of the operation that was already processed
     */
    error CrossChainFleetCommanderOperationAlreadyProcessedForCancellation(
        uint256 operationId
    );

    /**
     * @notice Thrown when trying to cancel an operation that doesn't belong to the caller
     * @param operationId The ID of the operation
     * @param caller The address attempting to cancel
     * @param owner The actual owner of the operation
     */
    error CrossChainFleetCommanderNotYourOperation(
        uint256 operationId,
        address caller,
        address owner
    );
}
