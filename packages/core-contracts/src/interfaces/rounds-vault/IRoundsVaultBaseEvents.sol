// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "@summerfi/price-solidity/contracts/PriceUtils.sol";

/**
    @title IRoundsVaultBaseEvents

    @notice Events emitted by the `RoundsVaultBase` contract.

    @author Roberto Cano <robercano>
 */
interface IRoundsVaultBaseEvents {
    /// @notice Emitted by `nextRound` after closing the current round and opening the next one.
    /// @param roundId The id of the round that was just closed (moved from `Opened` to `InSettlement`)
    event RoundAdvanced(uint256 indexed roundId);

    /// @notice Emitted by `redeemExchangeAsset` when a single past-round receipt is burned and the
    ///         exchange asset is paid out.
    /// @param caller The address that invoked the redemption
    /// @param receiver The address that received the exchange asset
    /// @param owner The address whose receipts were burned
    /// @param exchangeAssetAmount The amount of exchange asset transferred to `receiver`
    /// @param receiptId The round id of the burned receipts
    /// @param receiptAmount The amount of receipts that were burned
    event WithdrawExchangeAsset(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 exchangeAssetAmount,
        uint256 receiptId,
        uint256 receiptAmount
    );

    /// @notice Emitted by `redeemExchangeAssetBatch` when several past-round receipts are burned in
    ///         one call and the cumulative exchange asset is paid out.
    /// @param caller The address that invoked the redemption
    /// @param receiver The address that received the exchange asset
    /// @param owner The address whose receipts were burned
    /// @param exchangeAssetAmount The total exchange asset transferred to `receiver`
    /// @param receiptIds The round ids of the burned receipts
    /// @param receiptAmounts The amount of receipts burned per round id (aligned with `receiptIds`)
    event WithdrawExchangeAssetBatch(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 exchangeAssetAmount,
        uint256[] receiptIds,
        uint256[] receiptAmounts
    );

    /// @notice Emitted by `setRoundSettled` once the settlement trade has executed and the per-round
    ///         exchange rate has been snapshotted.
    /// @param roundId The round id that was settled
    /// @param exchangeRate The snapshotted per-round exchange rate
    event RoundSettled(uint256 indexed roundId, Price exchangeRate);

    /// @notice Emitted by `setMinPositionSize` when the governor updates the minimum aggregate
    ///         position size.
    /// @param oldMin The previous minimum (in target-vault assets)
    /// @param newMin The new minimum (in target-vault assets); 0 disables the check
    event MinPositionSizeUpdated(uint256 oldMin, uint256 newMin);

    /// @notice Emitted by `emergencyRollbackRound` when the governor moves a stuck `InSettlement`
    ///         round back to `Opened`.
    /// @param roundId The round id that was rolled back
    event EmergencyRoundRolledBack(uint256 indexed roundId);

    /// @notice Emitted by `retryRound` when the keeper pushes a past `Opened` round back to
    ///         `InSettlement` for another settlement attempt.
    /// @param roundId The round id that was retried
    event RoundRetried(uint256 indexed roundId);
}
