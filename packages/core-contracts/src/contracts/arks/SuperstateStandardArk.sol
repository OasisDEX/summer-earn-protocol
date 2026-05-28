// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../ArkWithWithdrawalRequest.sol";
import {PERCENTAGE_FACTOR, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import "@summerfi/price-solidity/contracts/PriceUtils.sol";
import {AggregatorV3Interface} from "../../interfaces/external/Chainlink/AggregatorV3Interface.sol";
import {IArk} from "../../interfaces/IArk.sol";
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
contract SuperstateStandardArk is
    ArkWithWithdrawalRequest,
    ISuperstateStandardArk
{
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for IERC20;
    using PriceUtils for Price;
    using PercentageUtils for uint256;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Default slippage tolerance (%) for swap-based withdrawals (unused, required by base)
    uint256 public constant DEFAULT_SWAP_SLIPPAGE = 2;
    /// @notice Maximum allowed sweep slippage (50%)
    Percentage public constant MAX_SWEEP_SLIPPAGE =
        Percentage.wrap(PERCENTAGE_FACTOR / 2);
    /// @notice Maximum allowed deposit slippage (50%)
    Percentage public constant MAX_DEPOSIT_SLIPPAGE =
        Percentage.wrap(PERCENTAGE_FACTOR / 2);
    /// @notice Oracle price is considered stale after this duration
    uint256 public constant ORACLE_HEARTBEAT_TIMEOUT = 24 hours;

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The Superstate fund token contract (USTB or USCC)
    IERC20Metadata public immutable SHARE_TOKEN;

    /// @notice Address to which USDC is sent during boarding (typically the fund token contract)
    address public immutable DEPOSIT_ADDRESS;

    /// @notice Superstate/Chainlink price feed: price of 1 Superstate share denominated in USDC
    AggregatorV3Interface public immutable ORACLE;

    /// @notice Decimals used by the oracle price feed
    uint8 public immutable ORACLE_DECIMALS;
    /// @notice Decimals of the base asset (e.g. USDC = 6)
    uint8 public immutable ASSET_DECIMALS;
    /// @notice Decimals of the fund share token (e.g. USCC = 6)
    uint8 public immutable SHARE_DECIMALS;
    /// @notice 1 unit of the base asset in its smallest denomination (10 ** ASSET_DECIMALS)
    uint256 public immutable ONE_ASSET;

    /// @notice Validated USDC amounts subscribed, awaiting minting of fund tokens (handles T+1/T+2 delays)
    uint256 public pendingDepositAssets;

    /// @notice Frozen share balance used while deposits are pending to prevent double-counting
    uint256 public cachedShareBalance;

    /// @notice Expected returning USDC amount equivalent to redeemed shares (handles T+1/T+2 delays)
    uint256 public pendingWithdrawalShares;

    /// @notice When true, totalAssets() returns a frozen snapshot and board/withdraw are blocked
    bool public isArkFrozen;
    /// @notice Slippage tolerance when validating USDC returned during sweep
    Percentage public sweepSlippage;
    /// @notice Slippage tolerance when validating shares received after a deposit clears
    Percentage public depositSlippage;
    /// @notice Snapshot of totalAssets() taken when the ark was frozen
    uint256 private _frozenTotalAssets;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param _shareToken  The Superstate fund token (e.g. USTB or USCC)
     * @param _depositAddress  Address to send USDC to during boarding (typically the fund token contract)
     * @param _oracle  Price feed returning the price of 1 fund share in base-asset terms
     * @param _sweepSlippage  Tolerance for USDC-vs-shares mismatch during sweep
     * @param _depositSlippage  Tolerance for shares-received validation during clearPendingDeposit
     * @param _params  Standard Ark initialization parameters
     */
    constructor(
        address _shareToken,
        address _depositAddress,
        address _oracle,
        Percentage _sweepSlippage,
        Percentage _depositSlippage,
        ArkParams memory _params
    ) ArkWithWithdrawalRequest(_params, DEFAULT_SWAP_SLIPPAGE) {
        if (_shareToken == address(0)) revert InvalidShareTokenAddress();
        if (_depositAddress == address(0)) revert InvalidDepositAddress();
        if (_oracle == address(0)) revert InvalidOracleAddress();

        SHARE_TOKEN = IERC20Metadata(_shareToken);
        DEPOSIT_ADDRESS = _depositAddress;
        ORACLE = AggregatorV3Interface(_oracle);

        if (_sweepSlippage > MAX_SWEEP_SLIPPAGE) {
            revert InvalidSweepSlippage(_sweepSlippage, MAX_SWEEP_SLIPPAGE);
        }
        if (_depositSlippage > MAX_DEPOSIT_SLIPPAGE) {
            revert InvalidDepositSlippage(
                _depositSlippage,
                MAX_DEPOSIT_SLIPPAGE
            );
        }
        sweepSlippage = _sweepSlippage;
        depositSlippage = _depositSlippage;

        ORACLE_DECIMALS = AggregatorV3Interface(_oracle).decimals();
        SHARE_DECIMALS = IERC20Metadata(_shareToken).decimals();
        ASSET_DECIMALS = IERC20Metadata(_params.asset).decimals();
        ONE_ASSET = 10 ** ASSET_DECIMALS;
    }

    modifier onlyNotFrozen() {
        if (isArkFrozen) revert ArkIsFrozen();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArk
     */
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

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function assetsInWithdrawalQueue() public view override returns (uint256) {
        return _sharesToAssets(pendingWithdrawalShares);
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function withdrawalRequestId() external pure override returns (uint256) {
        return 0;
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function isWithdrawalClaimRequired() external pure override returns (bool) {
        return false;
    }

    /**
     * @notice Converts shares to assets.
     */
    function sharesToAssets(uint256 shares) external view returns (uint256) {
        return _sharesToAssets(shares);
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
     * @inheritdoc IArkWithWithdrawalRequest
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

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function claimWithdrawal() external override onlyKeeper {
        // No-op: Superstate asynchronous process delivers USDC directly.
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function withdrawUsingSwap(
        uint256,
        bytes calldata
    ) external override onlyKeeper nonReentrant {
        // No-op
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @notice Sweeps returned USDC to buffer and clears `pendingWithdrawalShares`.
     * @dev Called by keeper after Superstate returns the USDC equivalent for the retired shares (T+1/T+2).
     */
    function sweep()
        public
        override
        onlyKeeper
        nonReentrant
        returns (address[] memory sweptTokens, uint256[] memory sweptAmounts)
    {
        IERC20 asset = config.asset;

        uint256 returnedAssets = asset.balanceOf(address(this));
        uint256 returnedShares = _assetsToShares(returnedAssets);

        uint256 pendingWithdrawalSharesMinusSlippage = pendingWithdrawalShares
            .subtractPercentage(sweepSlippage);

        if (returnedShares < pendingWithdrawalSharesMinusSlippage) {
            revert InsufficientAssetsReturned(
                returnedAssets,
                pendingWithdrawalShares,
                returnedShares
            );
        }

        return _sweep(returnedAssets);
    }

    /**
     * @notice Emergency sweep function for the governor to recover any remaining base asset.
     */
    function emergencySweep()
        external
        onlyGovernor
        nonReentrant
        returns (address[] memory sweptTokens, uint256[] memory sweptAmounts)
    {
        uint256 returnedAssets = config.asset.balanceOf(address(this));
        return _sweep(returnedAssets);
    }

    /**
     * @notice Emergency clear pending deposit function for the governor.
     */
    function emergencyClearPendingDeposit(
        uint256 amount
    ) external onlyGovernor {
        if (amount > pendingDepositAssets) revert InsufficientPendingDeposit();
        _clearPendingDeposit(amount);
    }

    /**
     * @notice Freezes the Ark, locking the total assets value.
     */
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

    /**
     * @notice Sets the sweep slippage percentage.
     */
    function setSweepSlippage(Percentage newSweepSlippage) external onlyKeeper {
        if (newSweepSlippage > MAX_SWEEP_SLIPPAGE)
            revert InvalidSweepSlippage(newSweepSlippage, MAX_SWEEP_SLIPPAGE);
        emit SweepSlippageUpdated(sweepSlippage, newSweepSlippage);
        sweepSlippage = newSweepSlippage;
    }

    /**
     * @notice Sets the deposit slippage percentage.
     */
    function setDepositSlippage(
        Percentage newDepositSlippage
    ) external onlyKeeper {
        if (newDepositSlippage > MAX_DEPOSIT_SLIPPAGE)
            revert InvalidDepositSlippage(
                newDepositSlippage,
                MAX_DEPOSIT_SLIPPAGE
            );
        emit DepositSlippageUpdated(depositSlippage, newDepositSlippage);
        depositSlippage = newDepositSlippage;
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

    /**
     * @inheritdoc Ark
     */
    function _disembark(
        uint256,
        bytes calldata
    ) internal view override onlyNotFrozen {}

    /**
     * @inheritdoc Ark
     */
    function _withdrawableTotalAssets()
        internal
        pure
        override
        returns (uint256)
    {
        return 0;
    }

    /**
     * @inheritdoc Ark
     */
    function _harvest(
        bytes calldata
    )
        internal
        pure
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        rewardTokens = new address[](0);
        rewardAmounts = new uint256[](0);
    }

    /**
     * @inheritdoc Ark
     */
    function _validateBoardData(bytes calldata) internal override {}

    /**
     * @inheritdoc Ark
     */
    function _validateDisembarkData(bytes calldata) internal override {}

    /**
     * @dev Clears `pendingWithdrawalShares`, transfers USDC to the buffer ark,
     *      and emits Disembarked + ArkSwept events.
     */
    function _sweep(
        uint256 amountToSweep
    )
        internal
        returns (address[] memory sweptTokens, uint256[] memory sweptAmounts)
    {
        IERC20 asset = config.asset;

        sweptTokens = new address[](1);
        sweptAmounts = new uint256[](1);

        sweptTokens[0] = address(asset);
        sweptAmounts[0] = amountToSweep;

        pendingWithdrawalShares = 0;

        address bufferArk = address(
            IFleetCommander(config.commander).bufferArk()
        );
        emit Disembarked(msg.sender, address(asset), sweptAmounts[0]);

        if (sweptAmounts[0] > 0 && address(this) != bufferArk) {
            asset.forceApprove(bufferArk, sweptAmounts[0]);
            IArk(bufferArk).board(sweptAmounts[0], bytes(""));
        }

        emit ArkSwept(sweptTokens, sweptAmounts);
    }

    /*//////////////////////////////////////////////////////////////
                            ORACLE HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Converts fund-token shares to base-asset amount using the oracle price.
    function _sharesToAssets(uint256 shares) internal view returns (uint256) {
        if (shares == 0) return 0;
        Price memory assetPerSharePrice = _fetchOracleAssetPerSharePrice();
        return assetPerSharePrice.invert().quote(shares);
    }

    /// @dev Converts base-asset amount to fund-token shares using the oracle price.
    function _assetsToShares(
        uint256 assetAmount
    ) internal view returns (uint256) {
        if (assetAmount == 0) return 0;
        Price memory assetPerSharePrice = _fetchOracleAssetPerSharePrice();
        return assetPerSharePrice.quote(assetAmount);
    }

    /// @dev Reads the oracle and constructs a Price(share → asset). Reverts on stale or non-positive data.
    function _fetchOracleAssetPerSharePrice()
        internal
        view
        returns (Price memory)
    {
        (, int256 answer, , uint256 updatedAt, ) = ORACLE.latestRoundData();
        if (answer <= 0) revert OraclePriceNotPositive();

        if (block.timestamp - updatedAt > ORACLE_HEARTBEAT_TIMEOUT) {
            revert StaleOraclePrice();
        }

        return
            toPriceFromOraclePrice(
                10 ** SHARE_DECIMALS,
                answer,
                ORACLE_DECIMALS,
                ASSET_DECIMALS
            );
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
