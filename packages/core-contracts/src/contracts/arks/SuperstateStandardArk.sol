// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BaseSuperstateArk} from "./BaseSuperstateArk.sol";
import {Ark} from "../Ark.sol";
import {IArk} from "../../interfaces/IArk.sol";
import {ArkParams} from "../../types/ArkTypes.sol";

import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

import {ISuperstateStandardArk} from "../../interfaces/arks/ISuperstateStandardArk.sol";

/**
 * @title SuperstateStandardArk
 * @notice Ark for asynchronous interaction with Superstate Tokenized Funds (USTB, USCC).
 * @dev All operations settle off-chain with T+1/T+2 delays, managed via pending state and a Keeper.
 *
 * **Lifecycle:**
 *   1. Board:    USDC is transferred to `DEPOSIT_ADDRESS` (the fund token contract). Superstate
 *                mints fund tokens off-chain. The amount is tracked in `pendingDepositAssets`.
 *   2. Clear:    Keeper calls `clearPendingDeposit()` once fund tokens arrive at this contract.
 *   3. Withdraw: Keeper calls `requestWithdrawal()` which burns fund tokens via
 *                `SHARE_TOKEN.offchainRedeem()`. Superstate delivers USDC off-chain.
 *   4. Sweep:    Keeper calls `sweep()` once USDC arrives, forwarding it to the buffer ark.
 *
 * **Allowlist:**
 *   This contract MUST be on the Superstate on-chain AllowList for the target fund.
 *   Calls to `offchainRedeem()` will revert if the caller is not allowlisted.
 *
 * **Freeze:**
 *   The keeper can freeze the ark via `setArkFrozen()`, locking `totalAssets()` to a snapshot
 *   value and preventing new boards, withdrawals, and sweeps. Use `emergencySweep` (governor)
 *   to recover assets while frozen.
 */
contract SuperstateStandardArk is BaseSuperstateArk, ISuperstateStandardArk {
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                              IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Address to which USDC is sent during boarding (typically the fund token contract).
    address public immutable DEPOSIT_ADDRESS;

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Validated USDC amounts subscribed, awaiting minting of fund tokens (handles T+1/T+2 delays).
    uint256 public pendingDepositAssets;
    /// @notice Frozen share balance used while deposits are pending to prevent double-counting.
    uint256 public cachedShareBalance;
    /// @notice When true, totalAssets() returns a frozen snapshot and board/withdraw are blocked.
    bool public isArkFrozen;
    /// @notice Snapshot of totalAssets() taken when the ark was frozen.
    uint256 private _frozenTotalAssets;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyNotFrozen() {
        if (isArkFrozen) revert ArkIsFrozen();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param _shareToken  The Superstate fund token (e.g. USTB or USCC).
     * @param _depositAddress  Address to send USDC to during boarding (typically the fund token contract).
     * @param _oracle  Price feed returning the price of 1 fund share in base-asset terms.
     * @param _sweepSlippage  Tolerance for USDC-vs-shares mismatch during sweep.
     * @param _depositSlippage  Tolerance for shares-received validation during clearPendingDeposit.
     * @param _params  Standard Ark initialization parameters.
     */
    constructor(
        address _shareToken,
        address _depositAddress,
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
        if (_depositAddress == address(0)) revert InvalidDepositAddress();
        DEPOSIT_ADDRESS = _depositAddress;
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
        if (isArkFrozen) {
            return _frozenTotalAssets;
        }

        uint256 currentShares = pendingDepositAssets > 0
            ? cachedShareBalance
            : SHARE_TOKEN.balanceOf(address(this));
        uint256 totalShares = currentShares + pendingWithdrawalShares;
        assets = _sharesToAssets(totalShares) + pendingDepositAssets;
    }

    /*//////////////////////////////////////////////////////////////
                      KEEPER & LIFECYCLE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Removes a fulfilled deposit amount from `pendingDepositAssets`.
     * @dev Called by the keeper after Superstate issues shares (T+1/T+2) to this contract.
     *      Validates that the share-balance delta since `cachedShareBalance` covers the
     *      oracle-implied expected shares minus `depositSlippage`.
     */
    function clearPendingDeposit() external onlyKeeper {
        _validateReceivedShares(pendingDepositAssets, cachedShareBalance);
        _clearPendingDeposit(pendingDepositAssets);
    }

    /**
     * @notice Adds the Standard-ark preconditions (`onlyNotFrozen`, no active pending deposit) on
     *         top of the base `requestWithdrawal`, which burns shares via `offchainRedeem` and
     *         tracks them in `pendingWithdrawalShares`.
     * @param amount The base-asset amount to redeem
     */
    function requestWithdrawal(
        uint256 amount
    ) public override onlyKeeper onlyNotFrozen {
        if (pendingDepositAssets > 0) revert PendingDepositActive();
        super.requestWithdrawal(amount);
    }

    /// @notice Emergency clear pending deposit function for the governor.
    /// @dev Bypasses `_validateReceivedShares`; lets the governor accept the current share balance
    ///      as valid for `amount` of the pending queue when the keeper path is deadlocked
    ///      (partial fills, oracle staleness). `emergencySweep` lives on `BaseSuperstateArk`.
    /// @param amount The pending-deposit asset amount to clear (must be <= pendingDepositAssets)
    function emergencyClearPendingDeposit(
        uint256 amount
    ) external onlyGovernor {
        if (amount > pendingDepositAssets) revert InsufficientPendingDeposit();
        _clearPendingDeposit(amount);
    }

    /**
     * @inheritdoc BaseSuperstateArk
     * @dev Adds `onlyNotFrozen` to the inherited sweep so that freezing the ark also gates routine
     *      settlement. Use `emergencySweep` (governor) to recover assets while frozen.
     */
    function sweep()
        public
        override
        onlyNotFrozen
        returns (address[] memory sweptTokens, uint256[] memory sweptAmounts)
    {
        return super.sweep();
    }

    /// @notice Freezes the Ark, locking the total assets value.
    /// @param _isArkFrozen Whether to freeze (true) or unfreeze (false) the Ark
    /// @param frozenTotalAssets The total-assets value to lock while frozen; pass type(uint256).max to snapshot the current totalAssets()
    function setArkFrozen(
        bool _isArkFrozen,
        uint256 frozenTotalAssets
    ) external onlyKeeper {
        if (_isArkFrozen) {
            _frozenTotalAssets = frozenTotalAssets == type(uint256).max
                ? totalAssets()
                : frozenTotalAssets;
        }
        isArkFrozen = _isArkFrozen;
        emit ArkIsFrozenUpdated(_isArkFrozen, _frozenTotalAssets);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc Ark
     * @dev Transfers USDC to `DEPOSIT_ADDRESS` and records the amount as pending.
     *      Only one pending deposit can be active at a time. The share balance is
     *      snapshotted into `cachedShareBalance` so that `totalAssets()` does not
     *      double-count while the deposit is pending.
     */
    function _board(
        uint256 amount,
        bytes calldata
    ) internal override onlyNotFrozen {
        if (pendingDepositAssets > 0) {
            revert PendingDepositActive();
        }

        cachedShareBalance = SHARE_TOKEN.balanceOf(address(this));
        pendingDepositAssets += amount;

        IERC20Metadata(address(config.asset)).safeTransfer(
            DEPOSIT_ADDRESS,
            amount
        );

        emit SubscriptionExecuted(amount, DEPOSIT_ADDRESS);
    }

    /// @inheritdoc Ark
    function _disembark(
        uint256,
        bytes calldata
    ) internal view override onlyNotFrozen {}

    /// @inheritdoc Ark
    function _withdrawableTotalAssets()
        internal
        pure
        override
        returns (uint256)
    {
        return 0;
    }

    /// @dev Decrements `pendingDepositAssets` and refreshes `cachedShareBalance`.
    function _clearPendingDeposit(uint256 amountCleared) internal {
        pendingDepositAssets -= amountCleared;
        cachedShareBalance = SHARE_TOKEN.balanceOf(address(this));
        emit PendingDepositCleared(amountCleared);
    }
}
