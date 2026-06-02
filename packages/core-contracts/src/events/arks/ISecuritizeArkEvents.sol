// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

interface ISecuritizeArkEvents {
    /// @notice Emitted when `clearPendingDeposit` or `emergencyClearPendingDeposit` reduces
    ///         `pendingDepositAssets`.
    /// @param amountCleared The amount removed from `pendingDepositAssets`
    event PendingDepositCleared(uint256 amountCleared);

    /// @notice Emitted by `requestWithdrawal` after DSToken shares are sent to the Securitize
    ///         custodian for off-chain redemption.
    /// @param shares Shares transferred to the custodian wallet
    /// @param expectedAssets Underlying asset amount the keeper requested (informational)
    event SharesSentForRedemption(uint256 shares, uint256 expectedAssets);

    /// @notice Emitted when the Securitize custodian wallet is rotated.
    /// @param oldWallet The previous `custodianWallet`
    /// @param newWallet The newly configured `custodianWallet`
    event CustodianWalletUpdated(address oldWallet, address newWallet);

    /// @notice Emitted whenever `setArkFrozen` is called.
    /// @param isFrozen The new frozen flag
    /// @param frozenTotalAssets The current value of the `_frozenTotalAssets` storage slot at emit
    ///                          time. On freeze this is the snapshot just taken; on unfreeze this is
    ///                          the previous snapshot (the slot is intentionally not reset).
    event ArkIsFrozenUpdated(bool isFrozen, uint256 frozenTotalAssets);

    /// @notice Emitted by `setSweepSlippage` after the cap is updated.
    /// @param oldSweepSlippage The previous `sweepSlippage`
    /// @param newSweepSlippage The newly configured `sweepSlippage`
    event SweepSlippageUpdated(
        Percentage oldSweepSlippage,
        Percentage newSweepSlippage
    );

    /// @notice Emitted by `setDepositSlippage` after the cap is updated.
    /// @param oldDepositSlippage The previous `depositSlippage`
    /// @param newDepositSlippage The newly configured `depositSlippage`
    event DepositSlippageUpdated(
        Percentage oldDepositSlippage,
        Percentage newDepositSlippage
    );
}
