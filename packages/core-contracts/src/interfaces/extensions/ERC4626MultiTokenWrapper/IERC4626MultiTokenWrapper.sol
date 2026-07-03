// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../ERC4626MultiToken/IERC4626MultiToken.sol";

/**
 * @title IERC4626MultiTokenWrapper
 *
 * @notice Variant of ERC-4626 that mints ERC-1155 receipts instead of a fungible share token. The
 *         id chosen by the implementation (typically a round number) is the natural key for
 *         attaching extra per-deposit state — e.g. a per-round exchange rate when capital is moved
 *         into the wrapped target vault on a settlement tick.
 *
 * @dev `withdraw`, `previewWithdraw`, and `maxWithdraw` from ERC-4626 are intentionally omitted —
 *      implementing them would require enumerating ERC-1155 ids per account, which is prohibitively
 *      expensive in gas. Users redeem by id via `redeem` / `redeemBatch` instead.
 *
 * @author Roberto Cano <robercano>
 */
interface IERC4626MultiTokenWrapper is IERC4626MultiToken {
    /// @notice Returns the address of the target ERC-4626 vault this wrapper batches deposits for.
    /// @return vaultAddress The address of the wrapped target vault
    function vault() external view returns (address vaultAddress);
}
