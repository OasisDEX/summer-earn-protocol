// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

/**
 * @title ISuperstateArkErrors
 * @notice Custom errors raised by Superstate Ark contracts
 */
interface ISuperstateArkErrors {
    /// @notice Thrown when the Superstate fund share token address supplied to the constructor is
    ///         the zero address.
    error InvalidShareTokenAddress();
    /// @notice Thrown when the price oracle address is the zero address, or (for the Subscribe ark)
    ///         when it does not match `SUPERSTATE_SUBSCRIBE.superstateOracle()`.
    error InvalidOracleAddress();
    /// @notice Thrown when the Superstate redeem (RedemptionIdle) contract address supplied to the
    ///         constructor is the zero address.
    error InvalidRedeemAddress();
    /// @notice Thrown when the oracle returns a non-positive answer (`answer <= 0`), which cannot be
    ///         used to price shares against the base asset.
    error OraclePriceNotPositive();
    /// @notice Thrown when the oracle's last update is older than `ORACLE_HEARTBEAT_TIMEOUT` (24h),
    ///         so the reported price is considered stale and unsafe for conversion.
    error StaleOraclePrice();
    /// @notice Thrown when a new sweep slippage exceeds `MAX_SWEEP_SLIPPAGE` (0.5%).
    /// @param newSlippage The rejected slippage value.
    /// @param maxSlippage The maximum permitted sweep slippage.
    error InvalidSweepSlippage(Percentage newSlippage, Percentage maxSlippage);
    /// @notice Thrown when a new deposit slippage exceeds `MAX_DEPOSIT_SLIPPAGE` (0.5%).
    /// @param newSlippage The rejected slippage value.
    /// @param maxSlippage The maximum permitted deposit slippage.
    error InvalidDepositSlippage(
        Percentage newSlippage,
        Percentage maxSlippage
    );
    /// @notice Thrown when the share-balance delta after a subscription/clear is below the
    ///         oracle-implied expected shares minus `depositSlippage` — i.e. Superstate delivered
    ///         fewer fund tokens than expected (fee enabled, partial mint, etc.).
    /// @param expectedShares The oracle-implied shares expected for the deposited amount.
    /// @param actualNewShares The shares that actually arrived since the pre-call snapshot.
    error SharesNotArrived(uint256 expectedShares, uint256 actualNewShares);
    /// @notice Thrown by `sweep` when the returned USDC, valued in shares at the current oracle
    ///         price, falls below `pendingWithdrawalShares` minus `sweepSlippage` — i.e. the
    ///         settlement returned less than the outstanding redemption was worth.
    /// @param receivedAssets The base-asset (USDC) amount held by the ark at sweep time.
    /// @param expectedShares The outstanding `pendingWithdrawalShares` being settled.
    /// @param receivedShares `receivedAssets` valued in shares at the current oracle price.
    error InsufficientAssetsReturned(
        uint256 receivedAssets,
        uint256 expectedShares,
        uint256 receivedShares
    );
    /// @notice Thrown when `requestWithdrawal` is called while a withdrawal cycle is already in
    ///         flight (`pendingWithdrawalShares > 0`). Prevents stacking redemptions that the
    ///         single-tranche `sweep` slippage check cannot reconcile.
    error PendingWithdrawalActive();
}
