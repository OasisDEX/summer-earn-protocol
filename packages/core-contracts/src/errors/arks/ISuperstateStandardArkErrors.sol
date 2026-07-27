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
    /// @notice Reserved; not reverted by the Ark — allowlist enforcement is performed by the external Superstate token during redemption, not via this error.
    error NotAllowlisted();
    /// @notice Reserved; not currently reverted anywhere in the Ark.
    error InsufficientYield();
}
