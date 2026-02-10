// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import "@summerfi/price-solidity/contracts/PriceUtils.sol";

import {BaseRoundsVault} from "./BaseRoundsVault.sol";

import {IRoundsInputVault} from "../../interfaces/rounds-vault/IRoundsInputVault.sol";
import {IRoundsInputVaultEvents} from "../../interfaces/rounds-vault/IRoundsInputVaultEvents.sol";

/**
    @title RoundsInputVault

    @notice The RoundsInputVault contract allows users to deposit funds into this contract while the
    target vault is locked, and receipts are minted to the users for this deposits. Upon round completion, the
    funds are transferred to the target vault and the corresponding shares are collected.

    Users can then exchange their receipts from previous rounds for the corresponding shares held in this vault.

    @author Roberto Cano <robercano>
 */
contract RoundsInputVault is
    BaseRoundsVault,
    IRoundsInputVault,
    IRoundsInputVaultEvents
{
    /**
     * CONSTRUCTOR
     */

    /**
        @param targetVault The address of the target vault for which this input vault is managing deposits. This vault will
                           be moving funds in and out of the target vault on each round
        @param accessManager The address of the Protocol Access Manager contract that provides information
                             about the different roles in the protocol, including the Keeper role that is the only
                             one allowed to call the `nextRound` function
        @param receiptsURI The URI of the ERC-1155 receipts that will be emitted when depositing the underlying
     */
    constructor(
        address targetVault,
        address accessManager,
        string memory receiptsURI
    ) BaseRoundsVault(targetVault, accessManager, receiptsURI) {
        // Empty on purpose
    }

    /**
     * INTERNAL FUNCTIONS
     */

    /**
        @inheritdoc BaseRoundsVault

        @dev Deposits the available funds into the main vault, receiving back an amount of target vault shares
    */
    // @audit This function is protected for re-entrancy by two mechanisms: only the Operator can call
    // `_nextRound` which is the function that in turn calls this function, and the Operator is a trusted
    // entity. Also, even if the operator would call `nextRound` in a re-entrancy attack, the funds are being
    // moved from this contract to the `InvestmentVault` contract and no more funds would be left, leading
    // the following code to be a no-op

    function _operate() internal override {
        uint256 assets = totalAssets();
        if (assets > 0) {
            uint256 shares = _depositOnTarget(assets);

            emit AssetsDeposited(
                getCurrentRound(),
                _msgSender(),
                assets,
                shares
            );
        }
    }

    /**
        @inheritdoc BaseRoundsVault

        @dev The exchange rate is given by the `previewDeposit` function on the target vault. The exchange rate is
        calculated for 1 full token

        @dev This function can only be called while the target vault is unlocked
     */
    function _getCurrentExchangeRate()
        internal
        view
        override
        returns (Price memory)
    {
        IERC20Metadata asset_ = IERC20Metadata(asset());

        // TODO: this can be optimized by caching it
        uint256 OneAsset = 10 ** asset_.decimals();
        uint256 shares = IERC4626(vault()).previewDeposit(OneAsset);

        return toPrice(OneAsset, shares);
    }
}
