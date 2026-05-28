// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BaseSuperstateArk} from "./BaseSuperstateArk.sol";
import {Ark} from "../Ark.sol";
import {IArk} from "../../interfaces/IArk.sol";
import {ArkParams} from "../../types/ArkTypes.sol";

import {PERCENTAGE_FACTOR, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

import {ISuperstateStandardArk} from "../../interfaces/arks/ISuperstateStandardArk.sol";
import {ISuperstateToken} from "../../interfaces/superstate/ISuperstateToken.sol";

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
 *   value and preventing new boards or withdrawals.
 */
contract SuperstateStandardArk is BaseSuperstateArk, ISuperstateStandardArk {
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for IERC20;
    using PercentageUtils for uint256;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum allowed deposit slippage. Under the Percentage library convention (100% = 100 * 1e18) this equals 0.5%.
    Percentage public constant MAX_DEPOSIT_SLIPPAGE =
        Percentage.wrap(PERCENTAGE_FACTOR / 2);

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
    /// @notice Slippage tolerance when validating shares received after a deposit clears.
    Percentage public depositSlippage;
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
    ) BaseSuperstateArk(_shareToken, _oracle, _params) {
        if (_depositAddress == address(0)) revert InvalidDepositAddress();

        DEPOSIT_ADDRESS = _depositAddress;
        _setSweepSlippage(_sweepSlippage);
        _setDepositSlippage(_depositSlippage);
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
     */
    function clearPendingDeposit() external onlyKeeper {
        _validateReceivedShares(pendingDepositAssets);
        _clearPendingDeposit(pendingDepositAssets);
    }

    /**
     * @notice Converts the requested asset amount to shares via the oracle, then calls
     *         `offchainRedeem()` on the fund token to burn them. The burned shares are tracked
     *         in `pendingWithdrawalShares` until Superstate delivers USDC and the keeper sweeps.
     */
    function requestWithdrawal(
        uint256 amount
    ) external override onlyKeeper onlyNotFrozen {
        if (pendingDepositAssets > 0) revert PendingDepositActive();

        uint256 sharesToRedeem = _assetsToShares(amount);

        pendingWithdrawalShares += sharesToRedeem;

        ISuperstateToken(address(SHARE_TOKEN)).offchainRedeem(sharesToRedeem);

        emit RedemptionExecuted(sharesToRedeem, amount);
        emit WithdrawalRequested(amount, 0);
    }

    /// @notice Emergency sweep function for the governor to recover any remaining base asset.
    function emergencySweep()
        external
        onlyGovernor
        nonReentrant
        returns (address[] memory sweptTokens, uint256[] memory sweptAmounts)
    {
        uint256 returnedAssets = config.asset.balanceOf(address(this));
        return _sweep(returnedAssets);
    }

    /// @notice Emergency clear pending deposit function for the governor.
    function emergencyClearPendingDeposit(
        uint256 amount
    ) external onlyGovernor {
        if (amount > pendingDepositAssets) revert InsufficientPendingDeposit();
        _clearPendingDeposit(amount);
    }

    /// @notice Freezes the Ark, locking the total assets value.
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

    /// @notice Sets the deposit slippage percentage.
    function setDepositSlippage(
        Percentage newDepositSlippage
    ) external onlyKeeper {
        _setDepositSlippage(newDepositSlippage);
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

    function _setDepositSlippage(Percentage newDepositSlippage) internal {
        if (newDepositSlippage > MAX_DEPOSIT_SLIPPAGE) {
            revert InvalidDepositSlippage(
                newDepositSlippage,
                MAX_DEPOSIT_SLIPPAGE
            );
        }
        emit DepositSlippageUpdated(depositSlippage, newDepositSlippage);
        depositSlippage = newDepositSlippage;
    }

    /// @dev Decrements `pendingDepositAssets` and refreshes `cachedShareBalance`.
    function _clearPendingDeposit(uint256 amountCleared) internal {
        pendingDepositAssets -= amountCleared;
        cachedShareBalance = SHARE_TOKEN.balanceOf(address(this));
        emit PendingDepositCleared(amountCleared);
    }

    /// @dev Reverts if newly arrived shares are below the expected amount minus deposit slippage.
    function _validateReceivedShares(uint256 amount) internal view {
        if (amount > pendingDepositAssets) revert InsufficientPendingDeposit();
        uint256 currentShares = SHARE_TOKEN.balanceOf(address(this));
        uint256 newlyArrivedShares = currentShares - cachedShareBalance;
        uint256 expectedShares = _assetsToShares(amount);
        uint256 expectedSharesMinusSlippage = expectedShares.subtractPercentage(
            depositSlippage
        );

        if (newlyArrivedShares < expectedSharesMinusSlippage) {
            revert SharesNotArrived(expectedShares, newlyArrivedShares);
        }
    }
}
