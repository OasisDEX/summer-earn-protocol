// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBaseBridgeAdapterErrors} from "./IBaseBridgeAdapterErrors.sol";
import {IBaseBridgeAdapterEvents} from "./IBaseBridgeAdapterEvents.sol";

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
 * 1. **Base Layer** (`IBaseBridgeAdapter`) - Error/event definitions ← **This interface**
 * 2. **Core Layer** (`IBridgeAdapter`) - Core bridge functionality
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
    // This interface serves as a consolidation point for base functionality
    // All methods are inherited from the extended interfaces
}
