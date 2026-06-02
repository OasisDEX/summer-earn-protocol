// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

interface ISecuritizeArkErrors {
    /// @notice Reverts when the constructor or `setCustodianWallet` is given the zero address.
    error InvalidTargetWallet();
    /// @notice Reverts when the constructor is given a zero oracle address.
    error InvalidOracleAddress();
    /// @notice Reverts when the constructor is given a zero share-token address.
    error InvalidShareTokenAddress();
    /// @notice Reverts when the registry service resolved from the DSToken is the zero address
    ///         (i.e. the token has no registry configured).
    error InvalidRegistryAddress();
    /// @notice Reverts when this Ark is not (yet) a registered investor wallet in the Securitize
    ///         registry and therefore cannot hold or transfer the DSToken. Onboarding is performed
    ///         off-chain by Securitize.
    error ArkNotRegistered();
    /// @notice Reverts when a prospective DSToken transfer fails the compliance pre-check.
    /// @param code The non-zero compliance failure code returned by `preTransferCheck`
    /// @param reason The human-readable reason returned by `preTransferCheck`
    error TransferNotCompliant(uint256 code, string reason);
    /// @notice Reverts when the NAV oracle returns a non-positive answer.
    error OraclePriceNotPositive();
    /// @notice Reverts when the oracle's `updatedAt` is older than `ORACLE_HEARTBEAT_TIMEOUT`.
    error StaleOraclePrice();
    /// @notice Reverts when `emergencyClearPendingDeposit` is called with `amount` greater than
    ///         the currently pending deposit.
    error InsufficientPendingDeposit();
    /// @notice Reverts when an operation (e.g. `_board`, `requestWithdrawal`) is attempted while a
    ///         deposit is already pending.
    error PendingDepositActive();
    /// @notice Reverts when `requestWithdrawal` is called while a withdrawal cycle is already in
    ///         flight (`pendingWithdrawalShares > 0`).
    error PendingWithdrawalActive();
    /// @notice Reverts when a state-changing entry point is invoked while the ark is frozen via
    ///         `setArkFrozen`.
    error ArkIsFrozen();
    /// @notice Reverts when `setDepositSlippage` or the constructor is given a value above
    ///         `MAX_DEPOSIT_SLIPPAGE`.
    /// @param newSlippage The supplied slippage
    /// @param maxSlippage The hard cap (`MAX_DEPOSIT_SLIPPAGE`)
    error InvalidDepositSlippage(
        Percentage newSlippage,
        Percentage maxSlippage
    );
    /// @notice Reverts when `setSweepSlippage` or the constructor is given a value above
    ///         `MAX_SWEEP_SLIPPAGE`.
    /// @param newSlippage The supplied slippage
    /// @param maxSlippage The hard cap (`MAX_SWEEP_SLIPPAGE`)
    error InvalidSweepSlippage(Percentage newSlippage, Percentage maxSlippage);
    /// @notice Reverts in `sweep` when the assets returned by Securitize convert to fewer shares
    ///         (at current oracle price) than `pendingWithdrawalShares - sweepSlippage`.
    /// @param receivedAssets The asset balance the ark holds at sweep time
    /// @param expectedShares `pendingWithdrawalShares` at sweep time
    /// @param receivedShares Asset balance converted back to shares via the oracle
    error InsufficientAssetsReturned(
        uint256 receivedAssets,
        uint256 expectedShares,
        uint256 receivedShares
    );
    /// @notice Reverts in `clearPendingDeposit` when the share delta since `cachedShareBalance` is
    ///         below the oracle-implied expected shares minus `depositSlippage`.
    /// @param expectedShares Oracle-implied shares for `pendingDepositAssets`
    /// @param actualNewShares Live share balance minus `cachedShareBalance`
    error SharesNotArrived(uint256 expectedShares, uint256 actualNewShares);
    /// @notice Reverts when on-ramp boarding is requested but the DSToken has no on-ramp
    ///         registered under service id 16384.
    error OnRampNotConfigured();
    /// @notice Reverts when on-ramp boarding is requested but the on-ramp's investor-initiated
    ///         `swap` subscriptions are disabled. The keeper should switch the Ark to the
    ///         custodial path via `setUseOnRampSubscription(false)`.
    error OnRampSubscriptionDisabled();
    /// @notice Reverts when the resolved on-ramp's liquidity token does not match this Ark's base
    ///         asset (e.g. a re-registered on-ramp), since `_board` approves/passes the base asset.
    /// @param expected This Ark's base asset
    /// @param actual The on-ramp's liquidity token
    error OnRampAssetMismatch(address expected, address actual);
}
