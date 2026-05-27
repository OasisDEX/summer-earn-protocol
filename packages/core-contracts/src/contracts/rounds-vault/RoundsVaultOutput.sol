// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import "@summerfi/price-solidity/contracts/PriceUtils.sol";

import {RoundsVaultBase} from "./RoundsVaultBase.sol";

import {IRoundsVaultOutput} from "../../interfaces/rounds-vault/IRoundsVaultOutput.sol";
import {IRoundsVaultOutputEvents} from "../../interfaces/rounds-vault/IRoundsVaultOutputEvents.sol";

/**
    @title RoundsVaultOutput
    @notice The RoundsVaultOutput contract allows users to deposit shares from the target vault into
    this contract while the  target vault is locked, and receipts are minted to the users for this deposits. Upon
    round completion, the shares are redeemed in the target vault and the corresponding funds are collected.

    Users can then exchange their receipts from previous rounds for the corresponding funds held in this vault.

    @author Roberto Cano <robercano>
 */
contract RoundsVaultOutput is
    RoundsVaultBase,
    IRoundsVaultOutput,
    IRoundsVaultOutputEvents
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

        @dev For an output vault the underlying asset is the same as the target vault, this is, the shares
     */
    constructor(
        address targetVault,
        address accessManager,
        string memory receiptsURI
    )
        RoundsVaultBase(
            targetVault,
            BaseVaultType.Output,
            accessManager,
            receiptsURI
        )
    {
        // Empty on purpose
    }

    /**
     * INTERNAL FUNCTIONS
     */

    /**
        @inheritdoc RoundsVaultBase
    */
    // @audit Re-entrancy posture: `_operate` is only reachable via `_setRoundSettled`, which is
    // gated by `onlyKeeper` on `setRoundSettled` / `setRoundSettledBatch`. The Keeper is a trusted
    // role. Even if a Keeper attempted to re-enter `setRoundSettled` for the same round, the round
    // state is flipped to `Settled` before `_operate` runs, so the second call would revert on
    // `InvalidRoundState`. And the round's frozen Fleet shares have already been redeemed against
    // the target FleetCommander, leaving this contract with nothing to move on a re-entrant pass.
    function _operate(
        uint256 shares,
        uint256 roundId
    ) internal override returns (uint256) {
        if (shares == 0) return 0;

        uint256 assets = _redeemFromTarget(shares);

        emit SharesRedeemed(roundId, _msgSender(), shares, assets);

        return assets;
    }

    /**
        @inheritdoc RoundsVaultBase

        @dev The exchange rate is given by the `previewRedeem` function on the target vault. The exchange rate is
        calculated for 1 full share

        @dev This function can only be called while the target vault is unlocked

        @dev The fallback exchange rate is calculated for 1 full token
     */
    function _getFallbackExchangeRate()
        internal
        view
        override
        returns (Price memory)
    {
        uint256 shares = 10 ** IERC20Metadata(asset()).decimals();
        uint256 assets = IERC4626(vault()).previewRedeem(shares);

        return toPrice(assets, shares);
    }
}
