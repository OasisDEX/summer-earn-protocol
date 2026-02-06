// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {ERC1155FullSupply} from "../../extensions/ERC1155FullSupply.sol";

import {IVaultWithReceipts} from "../../interfaces/rounds-vault/IVaultWithReceipts.sol";
import {IVaultWithReceiptsEvents} from "../../interfaces/rounds-vault/IVaultWithReceiptsEvents.sol";
import {IVaultWithReceiptsErrors} from "../../interfaces/rounds-vault/IVaultWithReceiptsErrors.sol";

/**
    @notice Implementation of the ERC4626 "Tokenized Vault Standard", modified to emit ERC-1155 receipts.
    When depositing a receipt is generated using an id provided by implementor of this interface.
    The receipt should contain the deposit amount. The id can be used freely to identify extra information
    about the deposit.
    
    @dev The internal function `_getMintId` is added here so derived contracts can override it to provide
    the correct id to be used for minting. The function is not marked as `view` to allow for any scheme of
    ids, including generating a new id on each minting operation

    @dev See { IERC4626MultiTokenUpgradeable }
    
    @dev This contract is a copy-paste of OpenZeppelin's `ERC4626Upgradeable.sol` with some modifications to
    support the ERC-1155 receipts.

    @dev In the original ERC-4626 the caller is checked against the allowance given by the owner in the internal
    functions `_deposit` and `_withdraw`. In ERC-1155 there is no such concept and the owner just approves the caller
    for none or all of the tokens in a collection. This is used here to allow for a caller to trade on behalf of the
    owner of the receipts

    @author Roberto Cano <robercano>
 */

abstract contract VaultWithReceipts is
    ERC1155FullSupply,
    IVaultWithReceipts,
    IVaultWithReceiptsEvents,
    IVaultWithReceiptsErrors
{
    using Math for uint256;

    /**
     * STORAGE
     */
    IERC20Metadata private _asset;

    /**
     * CONSTRUCTOR
     */
    constructor(address asset_) {
        _asset = IERC20Metadata(asset_);
    }

    /**
     * EXTERNAL/PUBLIC FUNCTIONS
     */

    /** @dev See {IVaultWithReceipts-asset} */
    function asset() public view virtual override returns (address) {
        return address(_asset);
    }

    /** @dev See {IVaultWithReceipts-totalAssets} */
    function totalAssets() public view virtual override returns (uint256) {
        return _asset.balanceOf(address(this));
    }

    /** @dev See {IVaultWithReceipts-maxDeposit} */
    function maxDeposit(
        address
    ) public view virtual override returns (uint256) {
        return type(uint256).max;
    }

    /** @dev See {IVaultWithReceipts-maxRedeem} */
    function maxRedeem(
        address owner
    ) public view virtual override returns (uint256) {
        return balanceOfAll(owner);
    }

    /** @dev See {IVaultWithReceipts-deposit} */
    function deposit(
        uint256 assets,
        address receiver
    ) public virtual override returns (uint256) {
        if (assets > maxDeposit(receiver)) {
            revert MaxDepositExceeded(
                _msgSender(),
                assets,
                maxDeposit(receiver)
            );
        }

        _deposit(_msgSender(), receiver, assets, _getMintId());

        return assets;
    }

    /** @dev See {IVaultWithReceipts-redeem} */
    function redeem(
        uint256 id,
        uint256 amount,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        if (amount > maxRedeem(owner)) {
            revert MaxRedeemExceeded(
                _msgSender(),
                owner,
                id,
                amount,
                maxRedeem(owner)
            );
        }

        _redeem(_msgSender(), receiver, owner, amount, id);

        return amount;
    }

    /** @dev See {IVaultWithReceipts-redeemBatch} */
    function redeemBatch(
        uint256[] memory ids,
        uint256[] memory amounts,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        if (ids.length != amounts.length) {
            revert BadRedeemBatchParameters(ids.length, amounts.length);
        }

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < ids.length; i++) {
            totalAmount += amounts[i];
        }

        // Emit a single error if the total amount to redeem exceeds the max allowed for the redeemer by the owner of the shares
        // The round id is left to 0
        if (totalAmount > maxRedeem(owner)) {
            revert MaxRedeemBatchExceeded(
                _msgSender(),
                owner,
                ids,
                totalAmount,
                maxRedeem(owner)
            );
        }

        _redeemBatch(_msgSender(), receiver, owner, totalAmount, ids, amounts);

        return totalAmount;
    }

    /**
     * INTERNAL FUNCTIONS
     */

    /**
        @dev Deposit/mint common workflow
     */
    function _deposit(
        address caller,
        address receiver,
        uint256 amount,
        uint256 id
    ) private {
        // @audit If _asset is ERC777, `transferFrom` can trigger a reenterancy BEFORE the transfer happens through the
        // `tokensToSend` hook. On the other hand, the `tokenReceived` hook, that is triggered after the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer before we mint so that any reentrancy would happen before the
        // assets are transfered and before the shares are minted, which is a valid state.
        // slither-disable-next-line reentrancy-no-eth
        SafeERC20.safeTransferFrom(_asset, caller, address(this), amount);
        _mint(receiver, id, amount, "");

        emit DepositWithReceipt(caller, receiver, id, amount);
    }

    /**
        @dev Redeem workflow
     */
    function _redeem(
        address caller,
        address receiver,
        address owner,
        uint256 amount,
        uint256 id
    ) private {
        if (caller != owner && !isApprovedForAll(owner, caller)) {
            revert CallerCannotRedeem(caller, owner, id, amount);
        }

        // @audit If _asset is ERC777, `transfer` can trigger trigger a reentrancy AFTER the transfer happens through the
        // `tokensReceived` hook. On the other hand, the `tokensToSend` hook, that is triggered before the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the Setransfer after the burn so that any reentrancy would happen after the
        // shares are burned and after the assets are transfered, which is a valid state.
        _burn(owner, id, amount);
        SafeERC20.safeTransfer(_asset, receiver, amount);

        emit RedeemReceipt(caller, receiver, owner, id, amount);
    }

    /**
        @dev The caller must make sure that totalAmount is the sum of all the amounts in the amounts array
     */
    function _redeemBatch(
        address caller,
        address receiver,
        address owner,
        uint256 totalAmount,
        uint256[] memory ids,
        uint256[] memory amounts
    ) private {
        if (caller != owner && !isApprovedForAll(owner, caller)) {
            revert CallerCannotRedeemBatch(caller, owner, ids, amounts);
        }

        // If _asset is ERC777, `transfer` can trigger trigger a reentrancy AFTER the transfer happens through the
        // `tokensReceived` hook. On the other hand, the `tokensToSend` hook, that is triggered before the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer after the burn so that any reentrancy would happen after the
        // shares are burned and after the assets are transfered, which is a valid state.
        _burnBatch(owner, ids, amounts);
        SafeERC20.safeTransfer(_asset, receiver, totalAmount);

        emit RedeemReceiptBatch(caller, receiver, owner, ids, amounts);
    }

    /**
        @notice Returns the Id to be used for minting the receipt

        @dev This function must be overriden by the child contract to implement any desired strategy

        @dev Not marked as `view` to allow the derived contract to modify the state inside it, in case
        a different id is desired for each minting operation
     */
    function _getMintId() internal virtual returns (uint256);
}
