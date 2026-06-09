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
    /// @notice Reverts when the Ark is deployed without `requiresKeeperData = true`; the on-ramp
    ///         subscription payload is supplied as keeper board data, so it is mandatory.
    error MustRequireKeeperData();
    /// @notice Reverts when a prospective DSToken transfer fails the compliance pre-check.
    /// @param code The non-zero compliance failure code returned by `preTransferCheck`
    /// @param reason The human-readable reason returned by `preTransferCheck`
    error TransferNotCompliant(uint256 code, string reason);
    /// @notice Reverts when the NAV oracle returns a non-positive answer.
    error OraclePriceNotPositive();
    /// @notice Reverts when the oracle's `updatedAt` is older than `ORACLE_HEARTBEAT_TIMEOUT`.
    error StaleOraclePrice();
    /// @notice Reverts when `requestWithdrawal` is called while a withdrawal cycle is already in
    ///         flight (`pendingWithdrawalShares > 0`).
    error PendingWithdrawalActive();
    /// @notice Reverts when a state-changing entry point is invoked while the ark is frozen via
    ///         `setArkFrozen`.
    error ArkIsFrozen();
    /// @notice Reverts when `setDepositSlippage` or the constructor is given a value above
    ///         `MAX_DEPOSIT_SLIPPAGE`.
    error InvalidDepositSlippage(
        Percentage newSlippage,
        Percentage maxSlippage
    );
    /// @notice Reverts when `setSweepSlippage` or the constructor is given a value above
    ///         `MAX_SWEEP_SLIPPAGE`.
    error InvalidSweepSlippage(Percentage newSlippage, Percentage maxSlippage);
    /// @notice Reverts in `sweep` when the assets returned by Securitize convert to fewer shares
    ///         (at current oracle price) than `pendingWithdrawalShares - sweepSlippage`.
    error InsufficientAssetsReturned(
        uint256 receivedAssets,
        uint256 expectedShares,
        uint256 receivedShares
    );
    /// @notice Reverts in `_board` when the DSTokens minted by the on-ramp subscription are below
    ///         the oracle-implied expected shares minus `depositSlippage` (NAV-source divergence or
    ///         excess on-ramp fee).
    /// @param expectedShares Oracle-implied shares for the boarded amount
    /// @param actualNewShares Shares actually minted to this Ark by the subscription
    error SharesNotArrived(uint256 expectedShares, uint256 actualNewShares);
    /// @notice Reverts when the DSToken has no on-ramp registered under service id 16384.
    error OnRampNotConfigured();
    /// @notice Reverts when the resolved on-ramp's liquidity token does not match this Ark's base
    ///         asset (e.g. a re-registered on-ramp), since `_board` approves/passes the base asset.
    error OnRampAssetMismatch(address expected, address actual);
    /// @notice Reverts when the keeper-supplied subscription payload does not relay a `subscribe`
    ///         to the resolved on-ramp that mints to THIS Ark for exactly the boarded amount.
    error InvalidSubscriptionPayload();
}
