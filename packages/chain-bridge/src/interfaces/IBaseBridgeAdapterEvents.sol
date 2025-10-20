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

    /// @notice Emitted when the protocol fee token is configured
    event ProtocolFeeTokenConfigured(address indexed feeToken);

    /// @notice Emitted when protocol token fees are collected from the payer (keeper)
    event ProtocolFeeCollected(
        bytes32 indexed operationId,
        address indexed payer,
        address indexed token,
        uint256 tokenFee
    );

    /// @notice Emitted when protocol token fees are spent for an operation
    event ProtocolFeeSpent(
        bytes32 indexed operationId,
        address indexed token,
        uint256 tokenFee
    );
}
