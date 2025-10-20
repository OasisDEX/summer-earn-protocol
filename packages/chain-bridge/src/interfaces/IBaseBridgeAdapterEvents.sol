// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IBaseBridgeAdapterEvents
 * @notice Interface containing all event definitions for BaseBridgeAdapter
 * @dev Following the IArkEvents pattern for consistent event definitions
 */
interface IBaseBridgeAdapterEvents {
    /// @notice Emitted when a chain external ID mapping is added
    event ExternalIdMapped(uint16 indexed chainId, uint32 indexed externalId);

    /// @notice Emitted when a chain external ID mapping is removed
    event ExternalIdUnmapped(uint16 indexed chainId, uint32 indexed externalId);

    /// @notice Emitted when stuck tokens are recovered via sweep
    event TokensRecovered(
        address indexed asset,
        uint256 amount,
        address indexed recipient
    );
}
