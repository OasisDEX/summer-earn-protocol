// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
    @title IRoundsVaultBaseErrors

    @notice Errors for the RoundsVaultBase contract
            
    @author Roberto Cano <robercano>
 */
interface IRoundsVaultBaseErrors {
    /// Error thrown when trying to redeem a receipt for a round that is not the current round
    error CanOnlyRedeemCurrentRound(uint256 receiptId, uint256 currentRound);

    /// Error thrown when trying to redeem a batch of receipts and one or more of the receipts are not for the current round
    error CanOnlyRedeemBatchCurrentRound(
        uint256[] receiptIds,
        uint256 currentRound
    );

    /// Error thrown when trying to redeem a receipt for the exchange asset and the round of the receipt is the current round
    error CannotRedeeemExchangeAssetCurrentRound(
        uint256 receiptId,
        uint256 currentRound
    );

    /// Error thrown when trying to redeem a batch of receipts for the exchange asset and one or more of the receipts are for the current round
    error CannotRedeeemBatchExchangeAssetCurrentRound(
        uint256[] receiptIds,
        uint256 currentRound
    );

    /// Error thrown when trying to redeem an exchange asset for a round that is not settled
    error RoundNotSettled(uint256 roundNumber);
}
