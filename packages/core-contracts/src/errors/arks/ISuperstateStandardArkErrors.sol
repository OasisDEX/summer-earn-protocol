// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

/**
 * @title ISuperstateStandardArkErrors
 * @notice Custom errors raised by the Superstate standard Ark contract
 */
interface ISuperstateStandardArkErrors {
    /// @notice Thrown when the configured deposit address is the zero address.
    error InvalidDepositAddress();
    /// @notice Thrown when an operation references more pending-deposit assets than are actually pending.
    error InsufficientPendingDeposit();
    /// @notice Thrown when an operation is attempted while a deposit cycle is already in flight.
    error PendingDepositActive();
    /// @notice Thrown when an operation is attempted while the Ark is frozen.
    error ArkIsFrozen();
    /// @notice Thrown when the caller is not on the Superstate allowlist required for the operation.
    error NotAllowlisted();
    /// @notice Thrown when the realized yield is insufficient for the requested operation.
    error InsufficientYield();
}
