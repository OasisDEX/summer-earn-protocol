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

import {ISuperstateToken, SupportedStablecoin} from "../../interfaces/superstate/ISuperstateToken.sol";
import {ISuperstateRedeem} from "../../interfaces/superstate/ISuperstateRedeem.sol";
import {ISuperstateSubscribeArk} from "../../interfaces/arks/ISuperstateSubscribeArk.sol";

/**
 * @title SuperstateSubscribeArk
 * @notice Ark for synchronous interaction with Superstate Tokenized Funds (primarily USTB).
 * @dev Unlike SuperstateStandardArk, this contract calls `subscribe()` on-chain during boarding
 *      to mint fund tokens immediately, and attempts synchronous redemption via the RedemptionIdle
 *      contract during disembarkation.
 *
 * **Lifecycle:**
 *   1. Board:     Approves USDC to `SUPERSTATE_SUBSCRIBE` and calls `subscribe()`, which pulls
 *                 USDC and mints fund tokens to this contract in the same transaction.
 *   2. Disembark: Attempts synchronous redemption via `SUPERSTATE_REDEEM.redeem()` (or `withdraw()`).
 *                 If that reverts (e.g. market closed, insufficient idle USDC), falls back to the
 *                 async path: shares are transferred to the redeem contract and the keeper calls
 *                 `sweep()` once USDC arrives.
 *   3. Keeper:    Can call `requestWithdrawal()` to explicitly use the async path, bypassing the
 *                 synchronous attempt.
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
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlySelf() {
        if (_msgSender() != address(this)) revert OnlySelf();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param _shareToken  The Superstate fund token (e.g. USTB).
     * @param _superstateSubscribe  Contract exposing `subscribe()` (typically the token proxy itself).
     * @param _superstateRedeem  Contract exposing `redeem()` / `withdraw()` (e.g. RedemptionIdle).
     * @param _oracle  Price feed for the fund token; must match `_superstateSubscribe.superstateOracle()`.
     * @param _params  Standard Ark initialization parameters.
     */
    constructor(
        address _shareToken,
        address _superstateSubscribe,
        address _superstateRedeem,
        address _oracle,
        ArkParams memory _params
    ) BaseSuperstateArk(_shareToken, _oracle, _params) {
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
                          KEEPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Explicitly initiates an async redemption. Useful when the keeper wants to bypass
     *         the synchronous attempt and go straight to the off-chain path.
     */
    function requestWithdrawal(uint256 amount) external override onlyKeeper {
        uint256 sharesToRedeem = _assetsToShares(amount);

        pendingWithdrawalShares += sharesToRedeem;
        SHARE_TOKEN.safeTransfer(address(SUPERSTATE_REDEEM), sharesToRedeem);

        emit RedemptionExecuted(sharesToRedeem, address(SUPERSTATE_REDEEM));
        emit WithdrawalRequested(amount, 0);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Approves USDC to the subscribe contract and calls `subscribe()` to mint fund tokens synchronously.
    function _board(uint256 amount, bytes calldata) internal override {
        IERC20Metadata(address(config.asset)).forceApprove(
            address(SUPERSTATE_SUBSCRIBE),
            amount
        );
        SUPERSTATE_SUBSCRIBE.subscribe(
            address(this),
            amount,
            address(config.asset)
        );

        emit SubscriptionExecuted(amount, address(SUPERSTATE_SUBSCRIBE));
    }

    /**
     * @dev Mirrors ERC4626Ark._disembark: full exits use `_directRedeemShares` (exact shares,
     *      avoids rounding issues), partial exits use `_directWithdrawAmount` (asset-denominated).
     *      Both attempt synchronous settlement first; if that reverts (e.g. market closed) the
     *      async off-chain path is taken via `_withdrawShares`.
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        // TODO: Check if the amount is the current balance of the ark without taking into account
        // the pending withdrawals and in that case redeem all the balance at once. If the
        // direct redeem/withdraw fails then check if there is a pending withdrawal and if so
        // then bail out as we don't want to accumulate withdrawal requests.

        // To prevent dust in the ark we check if the amount is equal to the total assets
        // and if there are no pending withdrawals. In that case we redeem all the shares
        // at once.
        if (amount == totalAssets() && assetsInWithdrawalQueue() == 0) {
            uint256 allShares = SHARE_TOKEN.balanceOf(address(this));
            try this._directRedeemShares(allShares) {
                emit RedemptionExecuted(allShares, address(SUPERSTATE_REDEEM));
            } catch {
                _withdrawShares(allShares, amount);
            }
        } else {
            try this._directWithdrawAmount(amount) {
                uint256 shares = _assetsToShares(amount);
                emit RedemptionExecuted(shares, address(SUPERSTATE_REDEEM));
            } catch {
                _withdrawShares(_assetsToShares(amount), amount);
            }
        }
    }

    /**
     * @dev Synchronous full-exit path: approves and calls `SUPERSTATE_REDEEM.redeem` with an
     *      exact share amount, expecting config.asset to arrive at this address immediately.
     *      Called via `this.` so the revert can be caught by `_disembark`.
     * @param sharesToRedeem The exact number of fund-token shares to redeem.
     */
    function _directRedeemShares(uint256 sharesToRedeem) external onlySelf {
        SHARE_TOKEN.forceApprove(address(SUPERSTATE_REDEEM), sharesToRedeem);
        SUPERSTATE_REDEEM.redeem(sharesToRedeem, address(this));
    }

    /**
     * @dev Synchronous partial-exit path: approves and calls `SUPERSTATE_REDEEM.withdraw` with
     *      an asset-denominated amount, expecting config.asset to arrive at this address immediately.
     *      Called via `this.` so the revert can be caught by `_disembark`.
     * @param amount The asset-denominated amount to withdraw.
     */
    function _directWithdrawAmount(uint256 amount) external onlySelf {
        uint256 shares = _assetsToShares(amount);
        SHARE_TOKEN.forceApprove(address(SUPERSTATE_REDEEM), shares);
        SUPERSTATE_REDEEM.withdraw(address(SHARE_TOKEN), address(this), amount);
    }

    /**
     * @dev Async off-chain path: transfers shares to the redeem contract and increments
     *      `pendingWithdrawalShares`. The keeper must call `sweep()` once USDC arrives.
     * @param sharesToRedeem The number of fund-token shares being sent off-chain.
     * @param amount The asset-denominated amount, emitted in WithdrawalRequested.
     */
    function _withdrawShares(uint256 sharesToRedeem, uint256 amount) internal {
        SHARE_TOKEN.safeTransfer(address(SUPERSTATE_REDEEM), sharesToRedeem);
        pendingWithdrawalShares += sharesToRedeem;

        emit RedemptionExecuted(sharesToRedeem, address(SUPERSTATE_REDEEM));
        emit WithdrawalRequested(amount, 0);
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
