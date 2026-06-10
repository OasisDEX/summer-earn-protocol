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

    @notice Output flavor of `RoundsVaultBase`. Users deposit target vault shares and receive
    ERC-1155 receipts for the current round. When the keeper closes and settles the round, the
    frozen shares are redeemed from the target vault and the resulting underlying asset (e.g. USDC)
    is credited as the round's exchange asset. Holders of past-round receipts can then redeem them
    for that underlying at the round's snapshotted rate.

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
     * @notice Wires the Output-flavor rounds-vault to its target ERC-4626 vault and the protocol
     *         access manager.
     * @dev For an Output vault the deposit asset is the target vault itself (its shares); the
     *      exchange asset (returned by `redeemExchangeAsset`) is the target vault's underlying.
     * @param targetVault The target ERC-4626 vault this Output vault wraps; settlement redeems from
     *                    this vault each round.
     * @param accessManager The `ProtocolAccessManagerV2` instance that gates keeper and governor
     *                      entry points (e.g. only the keeper may call `nextRound`).
     * @param receiptsURI The ERC-1155 metadata URI for round receipts minted on deposit.
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

    // @audit Re-entrancy posture: `_operate` is only reachable via `_setRoundSettled`, which is
    // gated by `onlyKeeper` on `setRoundSettled` / `setRoundSettledBatch`. The Keeper is a trusted
    // role. Even if a Keeper attempted to re-enter `setRoundSettled` for the same round, the round
    // state is flipped to `Settled` before `_operate` runs, so the second call would revert on
    // `InvalidRoundState`. And the round's frozen target vault shares have already been redeemed
    // against the target ERC-4626 vault, leaving this contract with nothing to move on a re-entrant
    // pass.
    /**
     * @inheritdoc RoundsVaultBase
     * @dev Redeems the round's frozen target-vault shares back to the target vault's underlying
     *      asset and returns that amount. The underlying stays in this contract and backs
     *      `redeemExchangeAsset` payouts for the round.
     */
    function _operate(
        uint256 amount,
        uint256 roundId
    ) internal override returns (uint256 outputAmount) {
        if (amount == 0) return 0;

        uint256 assets = _redeemFromTarget(amount);

        emit SharesRedeemed(roundId, _msgSender(), amount, assets);

        return assets;
    }

    /**
     * @inheritdoc RoundsVaultBase
     *
     * @dev Derives the rate from the target vault's `previewRedeem` for one full unit of shares, so
     *      empty rounds still snapshot a sensible price aligned with what a synchronous redeem
     *      would have produced at settlement time.
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
