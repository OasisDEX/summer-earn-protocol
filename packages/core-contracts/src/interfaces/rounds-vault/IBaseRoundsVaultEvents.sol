// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "@summerfi/price-solidity/contracts/PriceUtils.sol";

/**
    @title IBaseRoundsVaultEvents

    @notice Events for the BaseRoundsVault contract
            
    @author Roberto Cano <robercano>
 */
interface IBaseRoundsVaultEvents {
    /// Emitted when the next round starts and the exchange rate for the previous round is stored
    event NextRound(
        uint256 indexed newRoundNumber,
        Price prevRoundExchangeRate
    );

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
}
