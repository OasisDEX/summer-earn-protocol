// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IProtocolFeeTokenHandlerErrors
 * @notice Interface containing all error definitions for ProtocolFeeTokenHandler
 * @dev Errors for protocol fee token management functionality
 */
interface IProtocolFeeTokenHandlerErrors {
    /// @notice Thrown when payInProtocolToken is requested but protocolFeeToken is not configured
    error ProtocolTokenNotConfigured();
}
