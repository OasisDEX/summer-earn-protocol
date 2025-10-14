// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IBaseBridgeAdapterEvents
 * @notice Interface containing all events for BaseBridgeAdapter
 * @dev This interface centralizes all event definitions for better organization and reusability
 */
interface IBaseBridgeAdapterEvents {
    /// @notice Emitted when a chain external ID mapping is added
    event ExternalIdMapped(uint16 indexed chainId, uint32 indexed externalId);

    /// @notice Emitted when a chain external ID mapping is removed
    event ExternalIdUnmapped(uint16 indexed chainId, uint32 indexed externalId);
}
