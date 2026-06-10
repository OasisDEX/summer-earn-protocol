// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

/**
 * @title ISuperstateSubscribeArkErrors
 * @notice Custom errors raised by the Superstate subscribe Ark contract
 */
interface ISuperstateSubscribeArkErrors {
    /// @notice Thrown when the configured subscribe address is invalid (e.g. the zero address).
    error InvalidSubscribeAddress();
    /// @notice Thrown when the supplied stablecoin is not supported for subscription.
    error UnsupportedStablecoin();
    /// @notice Thrown by `_disembark` when the synchronous redemption via `SUPERSTATE_REDEEM.redeem`
    ///         reverts (e.g. RedemptionIdle market closed, out of idle USDC, paused). The keeper is
    ///         expected to detect this and use `requestWithdrawal` to route the withdrawal through
    ///         the off-chain async path instead.
    error DirectWithdrawalNotAvailable();
}
