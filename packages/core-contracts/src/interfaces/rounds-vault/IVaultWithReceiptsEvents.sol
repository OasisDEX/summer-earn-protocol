// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
    @notice Events for the VaultWithReceipts contract

    @author Roberto Cano <robercano>
 */
interface IVaultWithReceiptsEvents {
    /// Emitted when assets are deposited by `caller` and the shares are received by `receiver` on round 'id'
    event DepositWithReceipt(
        address indexed caller,
        address indexed receiver,
        uint256 id,
        uint256 assets
    );

    /// Emitted when shares for round 'id' are redeemed by `caller` and the assets are received by `receiver`
    event RedeemReceipt(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 id,
        uint256 amount
    );

    /// Emitted when shares for rounds 'ids' are redeemed by `caller` on behalf of `owner` and the assets
    /// are received by `receiver`
    event RedeemReceiptBatch(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256[] ids,
        uint256[] amounts
    );
}
