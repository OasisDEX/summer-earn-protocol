// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import "@summerfi/price-solidity/contracts/PriceUtils.sol";

import {RoundsVaultBase} from "./RoundsVaultBase.sol";

import {IRoundsVaultInput} from "../../interfaces/rounds-vault/IRoundsVaultInput.sol";
import {IRoundsVaultInputEvents} from "../../interfaces/rounds-vault/IRoundsVaultInputEvents.sol";

/**
    @title RoundsVaultInput

    @notice Input flavor of `RoundsVaultBase`. Users deposit the target vault's underlying asset
    (e.g. USDC) and receive ERC-1155 receipts for the current round. When the keeper closes and
    settles the round, the frozen underlying is deposited into the target vault and the target
    vault's shares are credited as the round's exchange asset. Holders of past-round receipts can
    then redeem them for shares at the round's snapshotted rate.

    @author Roberto Cano <robercano>
 */
contract RoundsVaultInput is
    RoundsVaultBase,
    IRoundsVaultInput,
    IRoundsVaultInputEvents
{
    /**
     * CONSTRUCTOR
     */

    /**
     * @notice Wires the Input-flavor rounds-vault to its target ERC-4626 vault and the protocol
     *         access manager.
     * @dev For an Input vault the deposit asset is the target vault's underlying asset; the exchange
     *      asset (returned by `redeemExchangeAsset`) is the target vault itself (its shares).
     * @param targetVault The target ERC-4626 vault this Input vault wraps; settlement deposits into
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
            BaseVaultType.Input,
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
     * @inheritdoc RoundsVaultBase
     * @dev Deposits the round's frozen underlying balance into the target vault and returns the
     *      amount of target-vault shares received. The shares stay in this contract and back
     *      `redeemExchangeAsset` payouts for the round.
     */
    // @audit Re-entrancy posture: `_operate` is only reachable via `_setRoundSettled`, which is
    // gated by `onlyKeeper` on `setRoundSettled` / `setRoundSettledBatch`. The Keeper is a trusted
    // role. Even if a Keeper attempted to re-enter `setRoundSettled` for the same round, the round
    // state is flipped to `Settled` before `_operate` runs, so the second call would revert on
    // `InvalidRoundState`. And the round's deposit balance has already been transferred to the
    // target FleetCommander, leaving this contract with nothing to move on a re-entrant pass.
    function _operate(
        uint256 assets,
        uint256 roundId
    ) internal override returns (uint256) {
        if (assets == 0) return 0;

        uint256 shares = _depositOnTarget(assets);

        emit AssetsDeposited(roundId, _msgSender(), assets, shares);

        return shares;
    }

    /**
     * @inheritdoc RoundsVaultBase
     *
     * @dev Derives the rate from the target vault's `previewDeposit` for one full unit of the
     *      deposit asset, so empty rounds still snapshot a sensible price aligned with what a
     *      synchronous deposit would have produced at settlement time.
     */
    function _getFallbackExchangeRate()
        internal
        view
        override
        returns (Price memory)
    {
        uint256 assets = 10 ** IERC20Metadata(asset()).decimals();
        uint256 shares = IERC4626(vault()).previewDeposit(assets);

        return toPrice(shares, assets);
    }
}
