// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IProtocolFeeTokenHandlerEvents
 * @notice Interface containing all event definitions for ProtocolFeeTokenHandler
 * @dev Events for protocol fee token management functionality
 */
interface IProtocolFeeTokenHandlerEvents {
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
