// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
    @title IERC4626MultiTokenErrors

    @notice Errors for the VaultWithReceipts contract

    @author Roberto Cano <robercano>
 */
interface IERC4626MultiTokenErrors {
    /// Emitted when trying to deposit an amount of assets that exceeds the max allowed for
    /// the depositor
    error MaxDepositExceeded(address depositor, uint256 amount, uint256 max);

    /// Emitted when trying to redeem an amount of shares that exceeds the max allowed for
    /// the redeemer by the owner of the shares
    error MaxRedeemExceeded(
        address redeemer,
        address owner,
        uint256 id,
        uint256 amount,
        uint256 max
    );

    /// Emitted when trying to redeem a batch of shares and the total amount exceeds the max allowed for
    /// the redeemer by the owner of the shares
    error MaxRedeemBatchExceeded(
        address redeemer,
        address owner,
        uint256[] ids,
        uint256 amount,
        uint256 max
    );

    /// Emitted when trying to redeem an amount of shares and the caller is not the owner
    /// or the amount that exceeds the max allowed by the owner for the redeemer
    error CallerCannotRedeem(
        address caller,
        address owner,
        uint256 id,
        uint256 amount
    );

    /// Emitted when trying to redeem a batch of shares and the caller is not the owner
    /// or the total amount exceeds the max allowed by the owner for the redeemer
    error CallerCannotRedeemBatch(
        address caller,
        address owner,
        uint256[] ids,
        uint256[] amounts
    );

    /// Emitted when trying to redeem a batch of shares and the lengths of the ids and amounts arrays do not match
    error BadRedeemBatchParameters(uint256 idsLength, uint256 amountsLength);
}
