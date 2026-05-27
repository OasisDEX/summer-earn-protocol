// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@summerfi/price-solidity/contracts/PriceUtils.sol";

import {ProtocolAccessManagedV2} from "@summerfi/access-contracts/contracts/ProtocolAccessManagedV2.sol";

import {ERC4626MultiToken, IERC4626MultiToken} from "../../extensions/ERC4626MultiToken.sol";
import {ERC4626MultiTokenWrapper} from "../../extensions/ERC4626MultiTokenWrapper.sol";
import {IWhitelist} from "../../utils/Whitelist/IWhitelist.sol";
import {Whitelist} from "../../utils/Whitelist/Whitelist.sol";

import {IRoundsVaultBase} from "../../interfaces/rounds-vault/IRoundsVaultBase.sol";
import {IRoundsVaultBaseEnums} from "../../interfaces/rounds-vault/IRoundsVaultBaseEnums.sol";
import {IRoundsVaultBaseErrors} from "../../interfaces/rounds-vault/IRoundsVaultBaseErrors.sol";
import {IRoundsVaultBaseEvents} from "../../interfaces/rounds-vault/IRoundsVaultBaseEvents.sol";

/**
 * @title RoundsVaultBase
 *
 * @notice Abstract base that batches user activity into discrete rounds and only moves funds in or
 *         out of a target ERC-4626 vault when the keeper closes and settles each round. Lets users
 *         interact at any block even when the target vault settles asynchronously (e.g. T+0/T+1
 *         against an off-chain NAV strike).
 *
 * @dev Public ABI is described by `IRoundsVaultBase`. Concrete subclasses (`RoundsVaultInput` and
 *      `RoundsVaultOutput`) pick a `BaseVaultType` at construction and implement the two virtual
 *      hooks `_operate` (the settlement trade) and `_getFallbackExchangeRate` (the rate used when
 *      a round was empty). Typical `_operate` implementations call `_depositOnTarget` or
 *      `_redeemFromTarget` to move funds in or out of the target vault.
 *
 * @dev Access control: round-state transitions (`nextRound`, `setRoundSettled[Batch]`, `retryRound`)
 *      are keeper-gated; `emergencyRollbackRound` and `setMinPositionSize` are governor-gated. User
 *      flows (`deposit`, `redeem[Batch]`, `redeemExchangeAsset[Batch]`, ERC-1155 transfers) require
 *      every involved party (caller/owner/receiver) to be whitelisted on the target vault context.
 *
 * @author Roberto Cano <robercano>
 */
abstract contract RoundsVaultBase is
    ProtocolAccessManagedV2,
    ERC4626MultiTokenWrapper,
    Whitelist,
    IRoundsVaultBase,
    IRoundsVaultBaseErrors,
    IRoundsVaultBaseEvents,
    IRoundsVaultBaseEnums
{
    using PriceUtils for Price;

    /**
     * STORAGE
     */

    /// @notice The currently open round number; starts at 0 and is incremented by `nextRound`.
    uint256 private _roundNumber;

    /// @notice Per-round settlement exchange rate, snapshotted by `_setRoundSettled`.
    /// @dev Rounds that have not been settled read back the zero-valued `Price`.
    mapping(uint256 => Price) private _exchangeRateByRound;

    /// @notice The ERC-20 token paid out when exchanging a settled-round receipt.
    /// @dev For an Input vault this is the target vault's share token; for an Output vault this is
    ///      the target vault's underlying asset.
    address private _exchangeAsset;

    /// @notice Lifecycle state of each round id (see `IRoundsVaultBaseEnums.RoundState`).
    /// @dev Default value `NotOpened` for any id the contract has never written. The constructor
    ///      seeds `roundState[0] = Opened` so round 0 is usable from deployment.
    mapping(uint256 => RoundState) public roundState;

    /// @notice Minimum aggregate position size, in target-vault assets, that a user must maintain
    ///         to enter or exit. `0` disables the check.
    uint256 public minPositionSize;

    /// @notice Vault flavor configured at construction. Determines the deposit and exchange assets.
    /// @dev `Input`:  deposit asset = proxiedVault.asset(), exchange asset = proxiedVault (shares).
    ///      `Output`: deposit asset = proxiedVault (shares), exchange asset = proxiedVault.asset().
    BaseVaultType public immutable VAULT_TYPE;

    /**
     * CONSTRUCTOR
     */

    /**
     * @notice Wires the rounds-vault to a target ERC-4626 vault and the protocol access manager.
     * @dev Opens round 0 (`roundState[0] = Opened`) so the contract is usable immediately after
     *      deployment. Assumes the target ERC-4626 vault uses itself as its own share token, per
     *      the OpenZeppelin reference implementation.
     * @param proxiedERC4626Vault The target ERC-4626 vault this rounds-vault wraps. Funds move in
     *                            and out of it once per round, via `_operate`.
     * @param _vaultType The vault flavor (`Input` or `Output`). Determines the deposit/exchange asset
     *                   pair:
     *                     - `Input`:  deposit asset = `proxiedERC4626Vault.asset()`,
     *                                 exchange asset = `proxiedERC4626Vault` (its shares);
     *                     - `Output`: deposit asset = `proxiedERC4626Vault` (its shares),
     *                                 exchange asset = `proxiedERC4626Vault.asset()`.
     * @param accessManager The `ProtocolAccessManagerV2` instance that brokers Keeper/Governor roles
     *                      and the whitelist. The Keeper role is required for `nextRound`,
     *                      `setRoundSettled[Batch]` and `retryRound`; the Governor role is required
     *                      for `emergencyRollbackRound` and `setMinPositionSize`.
     * @param receiptsURI The ERC-1155 metadata URI for round receipts minted on deposit.
     */
    constructor(
        address proxiedERC4626Vault,
        BaseVaultType _vaultType,
        address accessManager,
        string memory receiptsURI
    )
        ERC4626MultiTokenWrapper(
            proxiedERC4626Vault,
            _vaultType == BaseVaultType.Input
                ? IERC4626(proxiedERC4626Vault).asset()
                : proxiedERC4626Vault,
            receiptsURI
        )
        ProtocolAccessManagedV2(accessManager)
    {
        if (_vaultType == BaseVaultType.Input) {
            _exchangeAsset = proxiedERC4626Vault;
        } else {
            _exchangeAsset = IERC4626(proxiedERC4626Vault).asset();
        }

        VAULT_TYPE = _vaultType;
        roundState[0] = RoundState.Opened;
    }

    /**
     * PUBLIC FUNCTIONS
     */

    /**
     *     @inheritdoc IRoundsVaultBase
     */
    function nextRound() external onlyKeeper {
        uint256 closingRound = _roundNumber;

        _startSettlement(closingRound);

        _roundNumber++;

        roundState[_roundNumber] = RoundState.Opened;

        emit RoundAdvanced(closingRound);
    }

    /**
     * @inheritdoc IRoundsVaultBase
     */
    function retryRound(uint256 roundId) external onlyKeeper {
        if (roundId >= _roundNumber) {
            revert CannotRetryCurrentRound(roundId, _roundNumber);
        }

        _startSettlement(roundId);
        emit RoundRetried(roundId);
    }

    /**
     * @inheritdoc IRoundsVaultBase
     */
    function setRoundSettled(uint256 roundId) external onlyKeeper {
        _setRoundSettled(roundId);
    }

    /**
     *     @inheritdoc IRoundsVaultBase
     */
    function setRoundSettledBatch(
        uint256[] memory roundIds
    ) external onlyKeeper {
        for (uint256 i = 0; i < roundIds.length; i++) {
            _setRoundSettled(roundIds[i]);
        }
    }

    /**
     * @inheritdoc IRoundsVaultBase
     */
    function emergencyRollbackRound(uint256 roundId) external onlyGovernor {
        if (roundState[roundId] != RoundState.InSettlement) {
            revert InvalidRoundState(
                roundId,
                roundState[roundId],
                RoundState.InSettlement
            );
        }

        roundState[roundId] = RoundState.Opened;
        emit EmergencyRoundRolledBack(roundId);
    }

    /**
     * @dev Wires the inherited `Whitelist` helper to the same `ProtocolAccessManagerV2` instance
     *      configured for `ProtocolAccessManagedV2`, so all whitelist checks flow through one
     *      authority.
     */
    function _getAccessManager() internal view override returns (address) {
        return address(_accessManager);
    }

    /**
     * @dev Validates that both outgoing and incoming parties meet the minimum aggregate position
     *      size, post-flight (`_;` first) so the check sees the final on-chain balances.
     * @param outgoing The address whose position is decreasing. Use `address(0)` to skip the check
     *                 on that side (e.g. for deposits into an Input vault, where the depositor's
     *                 position grows, no party is "outgoing"). For self-operations (`outgoing ==
     *                 incoming`), a full exit (zero remaining aggregate balance) is allowed.
     * @param incoming The address whose position is increasing. Skipped if it equals `outgoing` (the
     *                 self case), if it is `address(0)`, or if it is `address(this)`.
     */
    modifier validateMinPosition(address outgoing, address incoming) {
        _;

        uint256 _minPositionSize = minPositionSize;
        if (_minPositionSize > 0) {
            bool isInput = VAULT_TYPE == BaseVaultType.Input;
            address targetVault = vault();
            bool isSelf = outgoing == incoming;

            if (outgoing != address(0)) {
                if (!isSelf || balanceOfAll(outgoing) > 0) {
                    _validateAggregateAssets(
                        outgoing,
                        isInput,
                        _minPositionSize,
                        targetVault
                    );
                }
            }

            if (!isSelf && incoming != address(0)) {
                _validateAggregateAssets(
                    incoming,
                    isInput,
                    _minPositionSize,
                    targetVault
                );
            }
        }
    }

    /**
     *     @inheritdoc IERC4626MultiToken
     */
    function deposit(
        uint256 assets,
        address receiver
    )
        public
        virtual
        override(IERC4626MultiToken, ERC4626MultiToken)
        validateMinPosition(
            VAULT_TYPE == BaseVaultType.Input ? address(0) : _msgSender(),
            receiver
        )
        returns (uint256)
    {
        _revertIfNotWhitelisted(vault(), receiver, _msgSender());

        return super.deposit(assets, receiver);
    }

    /**
     *     @inheritdoc IERC4626MultiToken
     */
    function redeem(
        uint256 id,
        uint256 amount,
        address receiver,
        address owner
    )
        public
        virtual
        override(IERC4626MultiToken, ERC4626MultiToken)
        validateMinPosition(owner, receiver)
        returns (uint256)
    {
        _revertIfNotWhitelisted(vault(), owner, receiver, _msgSender());
        if (roundState[id] != RoundState.Opened) {
            revert InvalidRoundState(id, roundState[id], RoundState.Opened);
        }

        return super.redeem(id, amount, receiver, owner);
    }

    /**
     * @inheritdoc IERC4626MultiToken
     *
     * @dev All `ids` must equal the currently open round. To exchange settled-round receipts for the
     *      exchange asset, use `redeemExchangeAssetBatch` instead.
     */
    function redeemBatch(
        uint256[] memory ids,
        uint256[] memory amounts,
        address receiver,
        address owner
    )
        public
        virtual
        override(IERC4626MultiToken, ERC4626MultiToken)
        validateMinPosition(owner, receiver)
        returns (uint256 assets)
    {
        _revertIfNotWhitelisted(vault(), owner, receiver, _msgSender());
        for (uint256 i = 0; i < ids.length; i++) {
            if (roundState[ids[i]] != RoundState.Opened) {
                revert InvalidRoundState(
                    ids[i],
                    roundState[ids[i]],
                    RoundState.Opened
                );
            }
        }

        return super.redeemBatch(ids, amounts, receiver, owner);
    }

    /**
     *     @inheritdoc IRoundsVaultBase
     */
    function redeemExchangeAsset(
        uint256 id,
        uint256 amount,
        address receiver,
        address owner
    ) public validateMinPosition(owner, receiver) returns (uint256) {
        _revertIfNotWhitelisted(vault(), owner, receiver, _msgSender());

        if (id >= _roundNumber) {
            revert CannotRedeeemExchangeAssetCurrentRound(id, _roundNumber);
        }
        if (roundState[id] != RoundState.Settled) {
            revert RoundNotSettled(id);
        }

        return _redeemExchangeAsset(_msgSender(), receiver, owner, id, amount);
    }

    /**
     * @inheritdoc IRoundsVaultBase
     *
     * @dev Partial redemptions are allowed, but each `(id, amount)` pair is converted using the
     *      round's snapshotted rate and integer multiplication; redeeming a very small amount against
     *      a sub-unit rate can therefore truncate to zero exchange asset for that line. Callers that
     *      want exact-trade semantics should redeem each receipt in full.
     */
    function redeemExchangeAssetBatch(
        uint256[] calldata ids,
        uint256[] calldata amounts,
        address receiver,
        address owner
    ) public validateMinPosition(owner, receiver) returns (uint256 shares) {
        _revertIfNotWhitelisted(vault(), owner, receiver, _msgSender());
        if (ids.length != amounts.length) {
            revert BadRedeemBatchParameters(ids.length, amounts.length);
        }

        for (uint256 i = 0; i < ids.length; i++) {
            if (ids[i] >= _roundNumber) {
                revert CannotRedeeemExchangeAssetCurrentRound(
                    ids[i],
                    _roundNumber
                );
            }
            if (roundState[ids[i]] != RoundState.Settled) {
                revert RoundNotSettled(ids[i]);
            }
        }

        return
            _redeemExchangeAssetBatch(
                _msgSender(),
                receiver,
                owner,
                ids,
                amounts
            );
    }

    /**
     *     @inheritdoc IERC1155
     *
     *     @dev Gate the function so only whitelisted addresses can transfer receipts
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) public virtual override(ERC1155, IERC1155) validateMinPosition(from, to) {
        _revertIfNotWhitelisted(vault(), from, to, _msgSender());
        super.safeTransferFrom(from, to, id, value, data);
    }

    /**
     *     @inheritdoc IERC1155
     *
     *     @dev Gate the function so only whitelisted addresses can transfer receipts in batch
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public virtual override(ERC1155, IERC1155) validateMinPosition(from, to) {
        _revertIfNotWhitelisted(vault(), from, to, _msgSender());
        super.safeBatchTransferFrom(from, to, ids, values, data);
    }

    // VIEW FUNCTIONS

    /**
     *     @inheritdoc IRoundsVaultBase
     */
    function getCurrentRound() public view override returns (uint256) {
        return _roundNumber;
    }

    /**
     *     @inheritdoc IRoundsVaultBase
     */
    function exchangeAsset() public view override returns (address) {
        return _exchangeAsset;
    }

    /**
     * @inheritdoc IRoundsVaultBase
     */
    function setMinPositionSize(
        uint256 minSize
    ) external override onlyGovernor {
        emit MinPositionSizeUpdated(minPositionSize, minSize);
        minPositionSize = minSize;
    }

    /**
     *     @inheritdoc IRoundsVaultBase
     */
    function getExchangeRate(uint256 round) public view returns (Price memory) {
        return _exchangeRateByRound[round];
    }

    /**
     * @dev Reverts with `RoundsVaultPositionTooSmall` if the user's aggregate post-flight position
     *      is non-zero but below `_minPositionSize`. For Input flavor, open receipts are counted
     *      1:1 as assets (they represent capital queued to be deposited); for Output flavor receipts
     *      are treated as 0 (they represent capital already on the way out). Both flavors additionally
     *      count any target-vault shares the user holds, converted to assets via `convertToAssets`.
     * @param user The address being evaluated
     * @param isInputVault `true` for Input flavor, `false` for Output flavor
     * @param _minPositionSize The minimum aggregate position size, in target-vault assets
     * @param targetVault The target ERC-4626 vault address
     */
    function _validateAggregateAssets(
        address user,
        bool isInputVault,
        uint256 _minPositionSize,
        address targetVault
    ) internal view {
        uint256 targetAssets = 0;

        if (isInputVault) {
            targetAssets = balanceOfAll(user);
            if (targetAssets >= _minPositionSize) return;
        }

        IERC4626 targetVaultContract = IERC4626(targetVault);
        uint256 shares = targetVaultContract.balanceOf(user);

        if (shares > 0) {
            targetAssets += targetVaultContract.convertToAssets(shares);
        }
        if (targetAssets > 0 && targetAssets < _minPositionSize) {
            revert RoundsVaultPositionTooSmall(
                user,
                targetAssets,
                _minPositionSize
            );
        }
    }

    /**
     * @notice Helper that moves an `Opened` round to `InSettlement`. Used both by `nextRound`
     *         (closing the current round) and `retryRound` (re-attempting a previously rolled-back
     *         past round).
     * @param roundId The id of the round to transition
     */
    function _startSettlement(uint256 roundId) internal {
        if (roundState[roundId] != RoundState.Opened) {
            revert InvalidRoundState(
                roundId,
                roundState[roundId],
                RoundState.Opened
            );
        }

        roundState[roundId] = RoundState.InSettlement;
    }

    /**
     *     @inheritdoc ERC4626MultiToken
     */
    function _getMintId() internal view virtual override returns (uint256) {
        return _roundNumber;
    }

    /**
     * @notice Settlement hook: executes the actual deposit-into or redeem-from the target vault for
     *         a round's frozen liability.
     * @dev Implementations are expected to call `_depositOnTarget` (Input flavor) or
     *      `_redeemFromTarget` (Output flavor) and return the exact amount the target vault paid
     *      back, so the caller can snapshot the per-round exchange rate from real execution.
     * @param amount The exact amount frozen for the round (deposit asset for Input, shares for Output)
     * @param roundId The id of the round being settled
     * @return outputAmount The exact amount the target vault returned after the settlement trade
     */
    function _operate(
        uint256 amount,
        uint256 roundId
    ) internal virtual returns (uint256 outputAmount);

    /**
     * @notice Returns the exchange rate used when a round had no deposits at settlement time.
     * @dev Implementations typically derive the rate from the target vault's `previewDeposit`
     *      (Input) or `previewRedeem` (Output) so empty rounds still snapshot a sensible price.
     */
    function _getFallbackExchangeRate()
        internal
        view
        virtual
        returns (Price memory);

    /**
     * @notice Helper that runs the actual settlement: flips the round state to `Settled` first
     *         (so any reentry sees a terminal state), then calls `_operate` against the frozen
     *         total supply, and finally snapshots the per-round exchange rate from the real result.
     *         Empty rounds (no receipts minted) fall back to `_getFallbackExchangeRate()`.
     * @dev Reverts unless `roundState[roundId] == InSettlement`.
     * @param roundId The id of the round to settle
     */
    function _setRoundSettled(uint256 roundId) internal {
        if (roundState[roundId] != RoundState.InSettlement) {
            revert InvalidRoundState(
                roundId,
                roundState[roundId],
                RoundState.InSettlement
            );
        }

        // 1. Mark as Settled early
        roundState[roundId] = RoundState.Settled;

        // 2. Fetch exact liability using ERC-1155 total supply for this specific round
        uint256 frozenAmount = totalSupply(roundId);

        Price memory finalExchangeRate;

        if (frozenAmount > 0) {
            // 3. Execute the trade and get the EXACT amount returned by the off-chain reality
            uint256 outputAmount = _operate(frozenAmount, roundId);
            // 4. Construct the precise exchange rate based on the actual execution
            finalExchangeRate = toPrice(outputAmount, frozenAmount);
        } else {
            // Fallback to 1:1 or preview rate if round was empty
            finalExchangeRate = _getFallbackExchangeRate();
        }

        _exchangeRateByRound[roundId] = finalExchangeRate;

        emit RoundSettled(roundId, finalExchangeRate);
    }

    // PRIVATES

    /**
     * @notice Burns receipts for a settled round and pays out the matching exchange-asset amount.
     * @dev Caller authorization (must be the owner or an operator approved by the owner) is checked
     *      here; round-state and id-validity checks live in the public entry point. Follows CEI:
     *      burn first, compute the payout, then transfer — the ERC-1155 `_burn` debits the owner's
     *      balance up front so a reentrant `tokensReceived` (ERC-777) callback on `safeTransfer`
     *      cannot drain.
     * @param caller The address that invoked the redemption
     * @param receiver The address that receives the exchange asset
     * @param owner The address whose receipts are burned
     * @param id The round id being exchanged
     * @param amount The number of receipts to burn
     * @return exchangeAmount The amount of exchange asset paid to `receiver`
     */

    // @audit This function follows the CEI pattern to avoid out-of-order execution. The only
    // external call is `safeTransfer` that is done at the end of the function where the state
    // of the contract is consistent and a reentrancy is protected by the `_burn` function that
    // will check the balance of the user

    function _redeemExchangeAsset(
        address caller,
        address receiver,
        address owner,
        uint256 id,
        uint256 amount
    ) private returns (uint256 exchangeAmount) {
        if (caller != owner && !isApprovedForAll(owner, caller)) {
            revert CallerCannotRedeem(caller, owner, id, amount);
        }

        // If _asset is ERC777, `transfer` can trigger a reentrancy AFTER the transfer happens through the
        // `tokensReceived` hook. On the other hand, the `tokensToSend` hook, that is triggered before the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer after the burn so that any reentrancy would happen after the
        // shares are burned and after the assets are transferred, which is a valid state.
        _burn(owner, id, amount);

        exchangeAmount = _exchangeRateByRound[id].quote(amount);

        SafeERC20.safeTransfer(
            IERC20(_exchangeAsset),
            receiver,
            exchangeAmount
        );

        emit WithdrawExchangeAsset(
            _msgSender(),
            receiver,
            owner,
            exchangeAmount,
            id,
            amount
        );
    }

    /**
     * @notice Batch variant of `_redeemExchangeAsset`. Burns receipts for several settled rounds in
     *         one call and pays out the cumulative exchange-asset amount.
     * @dev Caller authorization is checked here; round-state and id-validity checks live in the
     *      public entry point. Follows the same CEI ordering as `_redeemExchangeAsset` — the batch
     *      burn debits owner balances before the single trailing `safeTransfer`.
     * @param caller The address that invoked the redemption
     * @param receiver The address that receives the exchange asset
     * @param owner The address whose receipts are burned
     * @param ids The round ids being exchanged
     * @param amounts The receipts burned per round id (aligned with `ids`)
     * @return exchangeAmount The total exchange asset paid to `receiver`
     */

    // @audit This function follows the CEI pattern to avoid out-of-order execution. The only
    // external call is `safeTransfer` that is done at the end of the function where the state
    // of the contract is consistent and a reentrancy is protected by the `_burnBatch` function that
    // will check the balance of the user

    function _redeemExchangeAssetBatch(
        address caller,
        address receiver,
        address owner,
        uint256[] memory ids,
        uint256[] memory amounts
    ) private returns (uint256 exchangeAmount) {
        if (caller != owner && !isApprovedForAll(owner, caller)) {
            revert CallerCannotRedeemBatch(caller, owner, ids, amounts);
        }

        // If _asset is ERC777, `transfer` can trigger a reentrancy AFTER the transfer happens through the
        // `tokensReceived` hook. On the other hand, the `tokensToSend` hook, that is triggered before the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer after the burn so that any reentrancy would happen after the
        // shares are burned and after the assets are transferred, which is a valid state.
        _burnBatch(owner, ids, amounts);

        for (uint256 i = 0; i < ids.length; i++) {
            exchangeAmount += _exchangeRateByRound[ids[i]].quote(amounts[i]);
        }

        SafeERC20.safeTransfer(
            IERC20(_exchangeAsset),
            receiver,
            exchangeAmount
        );

        emit WithdrawExchangeAssetBatch(
            caller,
            receiver,
            owner,
            exchangeAmount,
            ids,
            amounts
        );
    }
}
