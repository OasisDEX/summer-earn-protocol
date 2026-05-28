// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IRoundsVaultBaseEnums} from "./IRoundsVaultBaseEnums.sol";

/**
    @title IRoundsVaultBaseErrors

    @notice Custom errors used by the `RoundsVaultBase` contract.

    @author Roberto Cano <robercano>
 */
interface IRoundsVaultBaseErrors {
    /// @notice Reverts when a current-round redemption is attempted with a receipt id that does not
    ///         match the current open round.
    /// @param receiptId The receipt id that was supplied
    /// @param currentRound The id of the currently open round
    /// @dev Reserved for future use / not currently thrown.
    error CanOnlyRedeemCurrentRound(uint256 receiptId, uint256 currentRound);

    /// @notice Reverts on a batch current-round redemption where one or more receipt ids do not match
    ///         the current open round.
    /// @param receiptIds The receipt ids that were supplied
    /// @param currentRound The id of the currently open round
    /// @dev Reserved for future use / not currently thrown.
    error CanOnlyRedeemBatchCurrentRound(
        uint256[] receiptIds,
        uint256 currentRound
    );

    /// @notice Reverts when `redeemExchangeAsset` is called with the current round id (only past
    ///         settled rounds are exchangeable for the exchange asset).
    /// @param receiptId The receipt id that was supplied
    /// @param currentRound The id of the currently open round
    /// @dev Note: error name retains a historical "Redeeem" misspelling; do not change without
    ///      coordinated rename across all call sites and ABIs.
    error CannotRedeeemExchangeAssetCurrentRound(
        uint256 receiptId,
        uint256 currentRound
    );

    /// @notice Reverts when `redeemExchangeAssetBatch` is called with one or more current-round ids.
    /// @param receiptIds The receipt ids that were supplied
    /// @param currentRound The id of the currently open round
    /// @dev Note: error name retains a historical "Redeeem" misspelling; do not change without
    ///      coordinated rename across all call sites and ABIs.
    /// @dev Reserved for future use / not currently thrown.
    error CannotRedeeemBatchExchangeAssetCurrentRound(
        uint256[] receiptIds,
        uint256 currentRound
    );

    /// @notice Reverts when an exchange redemption targets a round that is not in the `Settled` state.
    /// @param roundNumber The round id that was supplied
    error RoundNotSettled(uint256 roundNumber);

    /// @notice Reverts when a state transition expects the round in a specific `RoundState` but it is
    ///         actually in another state (covers `nextRound`, `setRoundSettled`, `retryRound`,
    ///         `emergencyRollbackRound`, `redeem`, `redeemBatch`).
    /// @param roundNumber The round id that was operated on
    /// @param currentRoundState The state the round is actually in
    /// @param expectedRoundState The state the operation required
    error InvalidRoundState(
        uint256 roundNumber,
        IRoundsVaultBaseEnums.RoundState currentRoundState,
        IRoundsVaultBaseEnums.RoundState expectedRoundState
    );

    /// @notice Reverts when an entry/exit leaves the user with a non-zero aggregate position below
    ///         `minPositionSize`. The aggregate combines open receipts (treated as assets for the
    ///         `Input` flavor) with target-vault shares converted to assets via `convertToAssets`.
    /// @param account The user whose post-flight balance was checked
    /// @param currentBalance The user's aggregate position size, in target-vault assets
    /// @param minRequired The configured minimum position size
    error RoundsVaultPositionTooSmall(
        address account,
        uint256 currentBalance,
        uint256 minRequired
    );

    /// @notice Reverts when `retryRound` is called with the current round id; `retryRound` only
    ///         operates on past rounds that the governor has rolled back to `Opened`.
    /// @param roundId The round id that was supplied
    /// @param currentRound The id of the currently open round
    error CannotRetryCurrentRound(uint256 roundId, uint256 currentRound);
}
