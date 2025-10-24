// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBaseBridgeAdapterErrors} from "./IBaseBridgeAdapterErrors.sol";
import {IBaseBridgeAdapterEvents} from "./IBaseBridgeAdapterEvents.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";

/**
 * @title IBaseBridgeAdapter
 * @notice Consolidated interface for base bridge adapter functionality
 * @dev This interface combines error and event definitions for BaseBridgeAdapter,
 *      providing a single point of inheritance for base adapter functionality.
 *      This follows the established pattern of consolidating related interfaces
 *      to reduce interface clutter and improve maintainability.
 *
 * ## Interface Hierarchy
 *
 * This interface serves as the **Base Layer** in the three-tier bridge adapter architecture:
 *
 * 1. **Base Layer** (`IBaseBridgeAdapter`) - Error/event definitions + core methods ← **This interface**
 * 2. **Core Layer** (`IBridgeAdapter`) - Marker interface for ERC165 support
 * 3. **Capability Layer** (`IAssetAdapter`/`IMessageAdapter`) - Specific capabilities
 *
 * ## Usage
 *
 * All bridge adapters should inherit from `BaseBridgeAdapter` which implements this interface,
 * providing consistent error handling and event emission across all adapters.
 */
interface IBaseBridgeAdapter is
    IBaseBridgeAdapterErrors,
    IBaseBridgeAdapterEvents
{
    /**
     * @notice Check if an adapter supports a specific operation type
     * @param operationType Type of operation to check support for
     * @return Whether the adapter supports the operation type
     * @dev This method should check both asset and message capabilities based on operationType
     */
    function supportsOperation(
        BridgeTypes.OperationType operationType
    ) external view returns (bool);
}
