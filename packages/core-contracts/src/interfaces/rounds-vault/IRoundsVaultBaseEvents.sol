// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "@summerfi/price-solidity/contracts/PriceUtils.sol";

/**
    @title IRoundsVaultBaseEvents

    @notice Events for the RoundsVaultBase contract
            
    @author Roberto Cano <robercano>
 */
interface IRoundsVaultBaseEvents {
    /// Emitted when the round is closed and the next one starts
    event RoundAdvanced(uint256 indexed roundId);

    /// Emitted when a user redeems a receipt for the exchange asset, indicating the amount of exchange asset
    event WithdrawExchangeAsset(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 exchangeAssetAmount,
        uint256 receiptId,
        uint256 receiptAmount
    );

    /// Emitted when a user redeems multiple receipts for the exchange asset, indicating the amount of exchange asset
    event WithdrawExchangeAssetBatch(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 exchangeAssetAmount,
        uint256[] receiptIds,
        uint256[] receiptAmounts
    );

    /// Emitted when a round is marked as settled
    event RoundSettled(uint256 indexed roundId, Price exchangeRate);

    /// Emitted when the minimum position size is updated
    event MinPositionSizeUpdated(uint256 oldMin, uint256 newMin);
}
