// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IFleetCommander} from "./IFleetCommander.sol";
import {AsyncOperation, CrossChainFleetCommanderParams} from "../types/CrossChainFleetCommanderTypes.sol";

/**
 * @title ICrossChainFleetCommander
 * @notice Interface for CrossChain FleetCommander with async operations
 * @dev Extends IFleetCommander with async deposit/withdrawal functionality
 */
interface ICrossChainFleetCommander is IFleetCommander {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when an async operation is queued
    event AsyncOperationQueued(
        uint256 indexed operationId,
        address indexed user,
        uint8 operationType,
        uint256 amount,
        uint256 timestamp
    );

    /// @notice Emitted when async operations are processed
    event AsyncOperationsProcessed(
        uint256[] operationIds,
        uint256 processedCount,
        uint256 failedCount
    );

    /// @notice Emitted when an operation is cancelled
    event AsyncOperationCancelled(
        uint256 indexed operationId,
        address indexed user
    );

    /*//////////////////////////////////////////////////////////////
                            ASYNC OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Queue an async deposit operation
     * @param assets The amount of assets to deposit
     * @param receiver The address to receive the shares
     * @return operationId The ID of the queued operation
     */
    function queueDeposit(
        uint256 assets,
        address receiver
    ) external returns (uint256 operationId);

    /**
     * @notice Queue an async withdrawal operation
     * @param assets The amount of assets to withdraw
     * @param receiver The address to receive the assets
     * @param owner The owner of the shares
     * @return operationId The ID of the queued operation
     */
    function queueWithdrawal(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 operationId);

    /**
     * @notice Queue an async redemption operation
     * @param shares The number of shares to redeem
     * @param receiver The address to receive the assets
     * @param owner The owner of the shares
     * @return operationId The ID of the queued operation
     */
    function queueRedemption(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 operationId);

    /*//////////////////////////////////////////////////////////////
                            SUPERKEEPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Process queued async operations
     * @dev Only callable by superkeeper when all Arks are synced
     * @param maxOperations Maximum number of operations to process in this call
     * @return processedCount Number of operations successfully processed
     * @return failedCount Number of operations that failed
     */
    function processAsyncOperations(
        uint256 maxOperations
    ) external returns (uint256 processedCount, uint256 failedCount);

    /**
     * @notice Cancel a queued async operation
     * @param operationId The ID of the operation to cancel
     */
    function cancelOperation(uint256 operationId) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get details of a queued operation
     * @param operationId The ID of the operation
     * @return operation The operation details
     */
    function getAsyncOperation(
        uint256 operationId
    ) external view returns (AsyncOperation memory operation);

    /**
     * @notice Get the number of queued operations
     * @return count The number of queued operations
     */
    function getQueuedOperationsCount() external view returns (uint256 count);

    /**
     * @notice Get the next operation to process
     * @return operationId The ID of the next operation, or 0 if none
     */
    function getNextOperationId() external view returns (uint256 operationId);

    /**
     * @notice Check if all Arks are synced
     * @return synced True if all Arks are synced, false otherwise
     */
    function areAllArksSynced() external view returns (bool synced);
}
