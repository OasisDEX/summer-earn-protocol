// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

interface ISuperstateSubscribeArkErrors {
    error InvalidSubscribeAddress();
    error UnsupportedStablecoin();
    /// @notice Thrown by `_disembark` when the synchronous redemption via `SUPERSTATE_REDEEM.redeem`
    ///         reverts (e.g. RedemptionIdle market closed, out of idle USDC, paused). The keeper is
    ///         expected to detect this and use `requestWithdrawal` to route the withdrawal through
    ///         the off-chain async path instead.
    error DirectWithdrawalNotAvailable();
}
