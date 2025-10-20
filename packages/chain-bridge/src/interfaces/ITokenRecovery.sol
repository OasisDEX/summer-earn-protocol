// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title ITokenRecovery
 * @notice Interface containing all event and error definitions for TokenRecovery
 * @dev Following the established pattern for consistent event and error definitions
 */
interface ITokenRecovery {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when stuck tokens are recovered via sweep
    event TokensRecovered(
        address indexed asset,
        uint256 amount,
        address indexed recipient
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the contract has insufficient balance
    error InsufficientBalance();

    /// @notice Thrown when a native token transfer fails
    error FailedCall();

    /// @notice Thrown when invalid parameters are provided
    error InvalidRecoveryParams();
}
