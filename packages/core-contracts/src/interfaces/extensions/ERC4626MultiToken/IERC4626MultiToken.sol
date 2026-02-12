// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../extensions/ERC1155FullSupply/IERC1155FullSupply.sol";

/**
    @notice Interface of the ERC4626 "Tokenized Vault Standard", modified to emit ERC-1155 receipts.
    When depositing the underlying token, a receipt is generated using an id provided by the implementor
    of this interface. The receipt should contain the deposit amount. The id can be used freely to identify
    extra information about the deposit.
    
    @dev The `withdraw` function, along with the `previewWithdraw` and `maxWithdraw` functions
    have been removed because the only way to implement them is to support enumeration
    for the ERC-1155 tokens, which is quite heavy in gas costs.

    @dev Although the only withdrawal functions are `redeem` and `reedeemBatch` the events have been
    kept with the original names `Withdraw` and `WithdrawBatch` for backwards consistency.
 
    @dev This interface is a copy-paste of OpenZeppelin's `IERC4626Upgradeable.sol` with some modifications to
    support the ERC-1155 receipts.

    @author Roberto Cano <robercano>
 */
interface IERC4626MultiToken is IERC1155FullSupply {
    /**
     * EXTERNAL FUNCTIONS
     */

    /**
     * @dev Returns the address of the underlying token used for the Vault for accounting, depositing, and withdrawing.
     *
     * - MUST be an ERC-20 token contract.
     * - MUST NOT revert.
     */
    function asset() external view returns (address assetTokenAddress);

    /**
     * @dev Returns the total amount of the underlying asset that is “managed” by Vault.
     *
     * - SHOULD include any compounding that occurs from yield.
     * - MUST be inclusive of any fees that are charged against assets in the Vault.
     * - MUST NOT revert.
     */
    function totalAssets() external view returns (uint256 totalManagedAssets);

    /**
     * @dev Returns the maximum amount of the underlying asset that can be deposited into the Vault for the receiver,
     * through a deposit call.
     *
     * - MUST return a limited value if receiver is subject to some deposit limit.
     * - MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of assets that may be deposited.
     * - MUST NOT revert.
     */
    function maxDeposit(
        address receiver
    ) external view returns (uint256 maxAssets);

    /**
     * @dev Mints shares Vault shares with the given id to receiver by depositing exactly amount of underlying tokens.
     *
     * - MUST emit the Deposit event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the
     *   deposit execution, and are accounted for during deposit.
     * - MUST revert if all of assets cannot be deposited (due to deposit limit being reached, slippage, the user not
     *   approving enough underlying tokens to the Vault contract, etc).
     *
     * NOTE: most implementations will require pre-approval of the Vault with the Vault’s underlying asset token.
     */
    function deposit(
        uint256 assets,
        address receiver
    ) external returns (uint256 shares);

    /**
     * @dev Returns the maximum amount of Vault shares that can be redeemed from the owner balance in the Vault,
     * through a redeem call.
     *
     * - MUST return a limited value if owner is subject to some withdrawal limit or timelock.
     * - MUST return balanceOf(owner) if owner is not subject to any withdrawal limit or timelock.
     * - MUST NOT revert.
     */
    function maxRedeem(address owner) external view returns (uint256 maxShares);

    /**
     * @dev Burns exactly shares from owner and sends assets of underlying tokens to receiver.
     *
     * - MUST emit the Withdraw event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the
     *   redeem execution, and are accounted for during redeem.
     * - MUST revert if all of shares cannot be redeemed (due to withdrawal limit being reached, slippage, the owner
     *   not having enough shares, etc).
     *
     * NOTE: some implementations will require pre-requesting to the Vault before a withdrawal may be performed.
     * Those methods should be performed separately.
     */
    function redeem(
        uint256 sharesId,
        uint256 sharesAmount,
        address receiver,
        address owner
    ) external returns (uint256 assets);

    /**
     * @dev Burns each batch of shares and the specific amounts and sends assets of underlying tokens to receiver.
     *
     * - MUST emit the WithdrawBatch event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the
     *   redeem execution, and are accounted for during redeem.
     * - MUST revert if all of shares cannot be redeemed (due to withdrawal limit being reached, slippage, the owner
     *   not having enough shares, etc).
     *
     * NOTE: some implementations will require pre-requesting to the Vault before a withdrawal may be performed.
     * Those methods should be performed separately.
     */
    function redeemBatch(
        uint256[] memory sharesIds,
        uint256[] memory sharesAmounts,
        address receiver,
        address owner
    ) external returns (uint256 assets);
}
