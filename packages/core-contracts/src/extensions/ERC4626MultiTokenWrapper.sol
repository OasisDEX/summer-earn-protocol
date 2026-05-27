// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ERC4626MultiToken} from "./ERC4626MultiToken.sol";

import {IERC4626MultiTokenWrapper} from "../interfaces/extensions/ERC4626MultiTokenWrapper/IERC4626MultiTokenWrapper.sol";

/**
 * @title ERC4626MultiTokenWrapper
 *
 * @notice ERC-4626-shaped vault that batches deposits in ERC-1155 receipts and only forwards them
 *         to a target ERC-4626 vault when an inheriting contract calls `_operate`. Lets users
 *         interact at any block even when the target vault accepts capital only periodically.
 *
 * @dev On deposit, an ERC-1155 receipt is minted to the depositor for an id chosen by the
 *      inheriting contract (typically the current round number). The id is the natural key for
 *      attaching round-specific state, e.g. a per-round exchange rate, to the deposit.
 *
 * @dev The wrapper handles one of two asset pairings, depending on how the inheriting contract
 *      configures `underlyingAsset` at construction:
 *      - if `underlyingAsset == proxiedVault.asset()`, this vault accumulates the target vault's
 *        underlying and `_depositOnTarget` exchanges it for target vault shares;
 *      - if `underlyingAsset == proxiedVault` (the share token), this vault accumulates target
 *        vault shares and `_redeemFromTarget` exchanges them for the target vault's underlying.
 *
 * @author Roberto Cano <robercano>
 */
abstract contract ERC4626MultiTokenWrapper is
    ERC4626MultiToken,
    IERC4626MultiTokenWrapper
{
    /**
     * STORAGE
     */

    /// @notice The target ERC-4626 vault that `_depositOnTarget` and `_redeemFromTarget` operate
    ///         against. Exposed via `vault()`.
    IERC4626 private _proxiedVault;

    /**
     * CONSTRUCTOR
     *
     * @param proxiedVault The target ERC-4626 vault to wrap.
     * @param underlyingAsset The asset this wrapper accepts on `deposit`. Configure as
     *                        `proxiedVault.asset()` for an Input-style wrapper or
     *                        `proxiedVault` (the share token) for an Output-style wrapper.
     * @param receiptsURI The ERC-1155 metadata URI used for deposit receipts.
     */
    constructor(
        address proxiedVault,
        address underlyingAsset,
        string memory receiptsURI
    ) ERC4626MultiToken(underlyingAsset, receiptsURI) {
        _proxiedVault = IERC4626(proxiedVault);
    }

    // PUBLIC FUNCTIONS

    /// @inheritdoc IERC4626MultiTokenWrapper
    function vault() public view returns (address vaultAddress) {
        return address(_proxiedVault);
    }

    /**
     * @notice Redeems `amount` of this wrapper's accumulated balance (target vault shares) from the
     *         target vault, paying out the target vault's underlying to this contract.
     * @param amount The amount of target vault shares to redeem
     * @return The amount of underlying asset paid back by the target vault
     */
    function _redeemFromTarget(uint256 amount) internal returns (uint256) {
        return _proxiedVault.redeem(amount, address(this), address(this));
    }

    /**
     * @notice Deposits `amount` of this wrapper's accumulated balance (target vault's underlying)
     *         into the target vault, receiving target vault shares to this contract.
     * @param amount The amount of underlying asset to deposit
     * @return The amount of target vault shares minted to this contract
     */
    function _depositOnTarget(uint256 amount) internal returns (uint256) {
        SafeERC20.forceApprove(IERC20(asset()), address(_proxiedVault), amount);

        return _proxiedVault.deposit(amount, address(this));
    }
}
