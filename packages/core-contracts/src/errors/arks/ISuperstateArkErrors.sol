// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

interface ISuperstateArkErrors {
    error InvalidShareTokenAddress();
    error InvalidOracleAddress();
    error InvalidRedeemAddress();
    error OraclePriceNotPositive();
    error StaleOraclePrice();
    error InvalidSweepSlippage(Percentage newSlippage, Percentage maxSlippage);
    error InvalidDepositSlippage(
        Percentage newSlippage,
        Percentage maxSlippage
    );
    error SharesNotArrived(uint256 expectedShares, uint256 actualNewShares);
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
