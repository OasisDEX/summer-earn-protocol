// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../../libraries/BridgeTypes.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IBridgeRouter} from "../../interfaces/IBridgeRouter.sol";

/**
 * @title BridgeRouterFailureBase
 * @notice Abstract base contract providing failure management for BridgeRouter operations
 * @dev Contains failure tracking logic with direct storage access
 */
abstract contract BridgeRouterFailureBase {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Record of failed delivery attempts by operationId
    struct FailedDeliveryRecord {
        BridgeTypes.OperationType operationType;
        address adapter;
        uint16 sourceChainId;
        bytes operationPayload; // original encoded payload
        uint256 failedAt; // block timestamp
    }

    /// @notice Mapping from operationId to failure record (exists if failed)
    mapping(bytes32 operationId => FailedDeliveryRecord record)
        public failedDeliveries;

    /// @notice Set of failed operationIds for enumeration/pagination
    EnumerableSet.Bytes32Set private failedDeliveryIds;

    /*//////////////////////////////////////////////////////////////
                      FAILURE RECORDING UTILITIES
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Records a failed delivery attempt
     * @param operationId The operation ID that failed
     * @param operationType The type of operation that failed
     * @param adapter The adapter that attempted the delivery
     * @param sourceChainId The source chain ID
     * @param operationPayload The original operation payload
     * @param errorData The error data from the failure
     */
    function _recordFailedDelivery(
        bytes32 operationId,
        BridgeTypes.OperationType operationType,
        address adapter,
        uint16 sourceChainId,
        bytes memory operationPayload,
        bytes memory errorData
    ) internal {
        FailedDeliveryRecord storage existing = failedDeliveries[operationId];
        if (existing.failedAt == 0) {
            // Insert new record
            failedDeliveries[operationId] = FailedDeliveryRecord({
                operationType: operationType,
                adapter: adapter,
                sourceChainId: sourceChainId,
                operationPayload: operationPayload,
                failedAt: block.timestamp
            });
            failedDeliveryIds.add(operationId);
        } else {
            // Update existing record
            existing.failedAt = block.timestamp;
            // Keep original payload and metadata
        }

        emit IBridgeRouter.OperationFailed(
            operationId,
            operationType,
            adapter,
            sourceChainId,
            errorData
        );
    }

    /**
     * @dev Clears a failed delivery record
     * @param operationId The operation ID to clear
     */
    function _clearFailedDelivery(bytes32 operationId) internal {
        failedDeliveryIds.remove(operationId);
        delete failedDeliveries[operationId];
    }

    /*//////////////////////////////////////////////////////////////
                          FAILURE VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns a page of failed delivery operationIds
    function getFailedDeliveryIds(
        uint256 cursor,
        uint256 size
    ) external view returns (bytes32[] memory ids, uint256 nextCursor) {
        uint256 len = failedDeliveryIds.length();
        if (cursor >= len) {
            return (new bytes32[](0), cursor);
        }
        uint256 end = cursor + size;
        if (end > len) end = len;
        uint256 pageSize = end - cursor;
        ids = new bytes32[](pageSize);
        for (uint256 i = 0; i < pageSize; i++) {
            ids[i] = failedDeliveryIds.at(cursor + i);
        }
        nextCursor = end;
    }

    /// @notice Returns the failure record for an operationId (reverts if none)
    function getFailedDelivery(
        bytes32 operationId
    ) external view returns (FailedDeliveryRecord memory) {
        FailedDeliveryRecord memory r = failedDeliveries[operationId];
        if (r.failedAt == 0) revert IBridgeRouter.FailureRecordNotFound();
        return r;
    }
}
