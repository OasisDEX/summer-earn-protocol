// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./VaultWithReceipts.sol";

import "../../interfaces/rounds-vault/IVaultDeferredOperation.sol";

/**
    @dev Deferred operations vault that takes care of handling deposits/withdrawals for a target vault.
    It receives and accumulates deposits and then forwards them to the target vault when the `_operate` function
    is called.

    @dev Upon deposit in this vault, the proxy will mint a receipt to the depositor containing the amount of assets
    deposited and an id that can be used to identify extra information relative to the deposit: for example it can
    encode the round number in which the deposit was made for a vault that runs cyclically with rounds.

    @dev A vault typically manages 2 types of assets: the underlying and the shares. The deferred operations vault
    is aimed at exchanging between these 2 assets when the main vault cannot exchange them directly all the time
    (because it is locked, or the assets are not present all the time, etc...).

    @dev This vault extends from the ERC4626MultiToken contract, and the underlying asset should be configured as
    either the underlying of the target vault or the shares of the target vault.

    @dev After calling `_operate`, the proxy will exchange the corresponding amount of this vault's underlying
    for the other asset in the target vault: this is, if this vault's underlying is the target vault's shares,
    it will exchange these shares for the target vault's underlying. If this vault's underlying is the target vault's
    underlying, it will exchange this underlying for the target vault's shares.
 
    @author Roberto Cano <robercano>
 */
abstract contract VaultDeferredOperation is
    VaultWithReceipts,
    IVaultDeferredOperation
{
    /**
     * STORAGE
     */
    IERC4626 private _proxiedVault;

    /**
     * CONSTRUCTOR
     *
     * @param proxiedVault The target vault for which this vault will be accepting deposits and withdrawals
     */
    constructor(
        address proxiedVault
    ) VaultWithReceipts(IERC4626(proxiedVault).asset()) {
        _proxiedVault = IERC4626(proxiedVault);
    }

    // PUBLIC FUNCTIONS

    /** @dev See {IVaultDeferredOperation-vault} */
    function vault() public view returns (address vaultAddress) {
        return address(_proxiedVault);
    }

    /** 
        @notice Exchanges the underlying asset for target vault shares

        @param amount The amount of underlying asset to redeem on the target vault

        @return The amount of target vault shares received
     */
    function _redeemFromTarget(uint256 amount) internal returns (uint256) {
        return _proxiedVault.redeem(amount, address(this), address(this));
    }

    /** 
        @notice Exchanges an amount of target vault shares for the underlying asset in the target vault

        @param amount The amount of the other asset to deposit on the target vault

        @return The amount of underlying assets received from the target vault
     */
    function _depositOnTarget(uint256 amount) internal returns (uint256) {
        SafeERC20.forceApprove(IERC20(asset()), address(_proxiedVault), amount);

        return _proxiedVault.deposit(amount, address(this));
    }
}
