// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BaseSuperstateArk} from "./BaseSuperstateArk.sol";
import {Ark} from "../Ark.sol";
import {IArk} from "../../interfaces/IArk.sol";
import {ArkParams} from "../../types/ArkTypes.sol";

import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

import {ISuperstateToken, SupportedStablecoin} from "../../interfaces/superstate/ISuperstateToken.sol";
import {ISuperstateRedeem} from "../../interfaces/superstate/ISuperstateRedeem.sol";
import {ISuperstateSubscribeArk} from "../../interfaces/arks/ISuperstateSubscribeArk.sol";

/**
 * @title SuperstateSubscribeArk
 * @notice Ark for synchronous interaction with Superstate Tokenized Funds (primarily USTB).
 * @dev Structurally mirrors `SuperstateStandardArk` (shared `BaseSuperstateArk` machinery for
 *      oracle, sweep, and `pendingWithdrawalShares`), with two Subscribe-specific differences:
 *      (a) `_board` calls `SUPERSTATE_SUBSCRIBE.subscribe()` on-chain so shares mint in the same
 *      transaction (no `pendingDepositAssets` cycle), and (b) `_disembark` attempts synchronous
 *      redemption via `SUPERSTATE_REDEEM.redeem()`.
 *
 * **Lifecycle:**
 *   1. Board:     Approves USDC to `SUPERSTATE_SUBSCRIBE` and calls `subscribe()`, which pulls
 *                 USDC and mints fund tokens to this contract in the same transaction.
 *   2. Disembark: Synchronously redeems shares via `SUPERSTATE_REDEEM.redeem()`. If RedemptionIdle
 *                 is closed, paused, or out of idle USDC, the call reverts with
 *                 `DirectWithdrawalNotAvailable` — the keeper is expected to detect this and route
 *                 the withdrawal through `requestWithdrawal` (async path) instead.
 *   3. Keeper:    Calls `requestWithdrawal()` to use the async off-chain path explicitly (single
 *                 outstanding tranche at a time, settled later by `sweep()`).
 *
 * **Allowlist:**
 *   This contract MUST be on the Superstate on-chain AllowList for the target fund.
 *   Both `subscribe()` and fund-token transfers check the allowlist.
 *
 * **Oracle:**
 *   The constructor validates that `_oracle` matches `SUPERSTATE_SUBSCRIBE.superstateOracle()`
 *   to ensure price consistency between the fund contract and this Ark.
 */
contract SuperstateSubscribeArk is BaseSuperstateArk, ISuperstateSubscribeArk {
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                              IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The Superstate Subscribe contract (usually the token proxy itself).
    ISuperstateToken public immutable SUPERSTATE_SUBSCRIBE;
    /// @notice The Superstate Redeem contract (RedemptionIdle contract).
    ISuperstateRedeem public immutable SUPERSTATE_REDEEM;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param _shareToken  The Superstate fund token (e.g. USTB).
     * @param _superstateSubscribe  Contract exposing `subscribe()` (typically the token proxy itself).
     * @param _superstateRedeem  Contract exposing `redeem()` (RedemptionIdle).
     * @param _oracle  Price feed for the fund token; must match `_superstateSubscribe.superstateOracle()`.
     * @param _sweepSlippage  Tolerance for USDC-vs-shares mismatch during sweep; `<= MAX_SWEEP_SLIPPAGE` (0.5%).
     * @param _depositSlippage  Tolerance for the post-`subscribe()` shares-received check; `<= MAX_DEPOSIT_SLIPPAGE` (0.5%).
     * @param _params  Standard Ark initialization parameters.
     */
    constructor(
        address _shareToken,
        address _superstateSubscribe,
        address _superstateRedeem,
        address _oracle,
        Percentage _sweepSlippage,
        Percentage _depositSlippage,
        ArkParams memory _params
    )
        BaseSuperstateArk(
            _shareToken,
            _oracle,
            _sweepSlippage,
            _depositSlippage,
            _params
        )
    {
        if (_superstateSubscribe == address(0))
            revert InvalidSubscribeAddress();
        if (_superstateRedeem == address(0)) revert InvalidRedeemAddress();

        SUPERSTATE_SUBSCRIBE = ISuperstateToken(_superstateSubscribe);
        SUPERSTATE_REDEEM = ISuperstateRedeem(_superstateRedeem);

        if (_oracle != SUPERSTATE_SUBSCRIBE.superstateOracle()) {
            revert InvalidOracleAddress();
        }

        SupportedStablecoin memory info = ISuperstateToken(_superstateSubscribe)
            .supportedStablecoins(address(_params.asset));
        if (info.sweepDestination == address(0)) {
            revert UnsupportedStablecoin();
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IArk
    function totalAssets()
        public
        view
        override(Ark, IArk)
        returns (uint256 assets)
    {
        uint256 totalShares = SHARE_TOKEN.balanceOf(address(this)) +
            pendingWithdrawalShares;
        assets = _sharesToAssets(totalShares);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Approves USDC to the subscribe contract, calls `subscribe()` to mint fund tokens
     *      synchronously, then asserts the share-balance delta is within `depositSlippage` of the
     *      oracle-implied expectation. Reverts with `SharesNotArrived` if Superstate underpaid
     *      (fee enabled, partial mint, etc.) so the loss surfaces on-chain instead of silently
     *      bleeding into `totalAssets()`.
     */
    function _board(uint256 amount, bytes calldata) internal override {
        uint256 sharesBefore = SHARE_TOKEN.balanceOf(address(this));

        IERC20Metadata(address(config.asset)).forceApprove(
            address(SUPERSTATE_SUBSCRIBE),
            amount
        );
        SUPERSTATE_SUBSCRIBE.subscribe(
            address(this),
            amount,
            address(config.asset)
        );

        _validateReceivedShares(amount, sharesBefore);

        emit SubscriptionExecuted(amount, address(SUPERSTATE_SUBSCRIBE));
    }

    /**
     * @dev Synchronously redeems shares for USDC via `SUPERSTATE_REDEEM.redeem`. For a full exit
     *      (asset amount equals the entire balance, no pending withdrawals) the contract redeems
     *      every share it holds to avoid leaving rounding dust; otherwise it redeems
     *      `_assetsToShares(amount)`. Reverts with `DirectWithdrawalNotAvailable` if the
     *      RedemptionIdle call reverts (market closed, paused, out of idle USDC, …) — the keeper
     *      is expected to detect this and route through `requestWithdrawal` (async path).
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        uint256 sharesToRedeem;
        if (amount == totalAssets() && assetsInWithdrawalQueue() == 0) {
            // Full exit: drain the entire share balance to avoid dust from oracle rounding.
            sharesToRedeem = SHARE_TOKEN.balanceOf(address(this));
        } else {
            sharesToRedeem = _assetsToShares(amount);
        }

        SHARE_TOKEN.forceApprove(address(SUPERSTATE_REDEEM), sharesToRedeem);
        try SUPERSTATE_REDEEM.redeem(sharesToRedeem, address(this)) {
            emit RedemptionExecuted(sharesToRedeem, amount);
        } catch {
            revert DirectWithdrawalNotAvailable();
        }
    }

    /**
     * @dev Returns the maximum synchronously withdrawable amount, capped by USDC
     *      available in the RedemptionIdle contract. Excludes shares already in
     *      the async withdrawal queue.
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256)
    {
        uint256 balanceRedemptionContract = IERC20Metadata(
            address(config.asset)
        ).balanceOf(address(SUPERSTATE_REDEEM));

        uint256 theoreticalWithdrawableAssets = totalAssets() -
            assetsInWithdrawalQueue();

        return
            Math.min(balanceRedemptionContract, theoreticalWithdrawableAssets);
    }
}
