// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AggregatorV3Interface} from "../../interfaces/external/Chainlink/AggregatorV3Interface.sol";
import "../ArkWithWithdrawalRequest.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {PERCENTAGE_FACTOR, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import "@summerfi/price-solidity/contracts/PriceUtils.sol";

/**
 * @title WisdomTreeArk
 * @notice Ark for managing off-chain WisdomTree tokenised assets (e.g. WTBTC).
 *
 * @dev Asset tracking model:
 * totalAssets() = (actualShares * oraclePrice) + pendingDepositAssets + (pendingWithdrawalShares * oraclePrice)
 *
 * Lifecycle:
 * 1. Deposit (`_board`):
 * - If it's the first deposit in the queue (`pendingDepositAssets == 0`),
 * the Ark snapshots its live share balance into `cachedShareBalance`.
 * - USDC is transferred to `custodianWallet`.
 * - `pendingDepositAssets` increases by the sent amount.
 *
 * 2. Share Delivery & Deposit Clearance (`clearPendingDeposit`):
 * - WisdomTree mints shares and transfers them to this Ark off-chain.
 * - While `pendingDepositAssets > 0`, `totalAssets` uses `cachedShareBalance` to prevent double-counting.
 * - The Keeper calls `clearPendingDeposit(amount)`. The contract mathematically verifies
 * that the expected shares (minus `depositSlippage`) have actually arrived before allowing clearance.
 * - Supports partial clearances: `pendingDepositAssets` decreases, and `cachedShareBalance` updates
 * safely to capture the newly delivered shares.
 *
 * 3. Withdrawal Request (`requestWithdrawal`):
 * - Only allowed when `pendingDepositAssets == 0` (prevents concurrent deposit/withdrawal cycles).
 * - Calculates equivalent shares using the oracle and transfers them to `custodianWallet`.
 * - Increases `pendingWithdrawalShares`.
 *
 * 4. Sweep (`sweep`):
 * - USDC arrives from WisdomTree. Keeper calls `sweep()`.
 * - Verifies that returned USDC meets the expected `sweepSlippage` threshold based on current oracle price.
 * - `pendingWithdrawalShares = 0`. USDC swept to `bufferArk`.
 *
 * 5. Emergency Fallbacks:
 * - `emergencySweep()` and `emergencyClearPendingDeposit()` allow the Governor to safely bypass
 * slippage and oracle checks in case of extreme market volatility, partial fills the Keeper cannot process, or oracle
 * deadlocks.
 */
contract WisdomTreeArk is ArkWithWithdrawalRequest, ERC721Holder {
    using SafeERC20 for IERC20;
    using PriceUtils for Price;
    using PercentageUtils for uint256;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                                  ENUMS
    //////////////////////////////////////////////////////////////*/

    /// @notice Default slippage (0.02%)
    uint256 public constant DEFAULT_SWAP_SLIPPAGE = 2;

    /// @notice Maximum sweep slippage (0.5%)
    Percentage public constant MAX_SWEEP_SLIPPAGE =
        Percentage.wrap(PERCENTAGE_FACTOR / 2);

    /// @notice Maximum deposit slippage (0.5%)
    Percentage public constant MAX_DEPOSIT_SLIPPAGE =
        Percentage.wrap(PERCENTAGE_FACTOR / 2);

    /// @notice Timeout for the oracle heartbeat (24 hours)
    uint256 public constant ORACLE_HEARTBEAT_TIMEOUT = 24 hours;

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Reverts when the constructor or `setCustodianWallet` is given the zero address.
    error InvalidTargetWallet();
    /// @notice Reverts when the constructor is given a zero oracle address.
    error InvalidOracleAddress();
    /// @notice Reverts when the constructor is given a zero share-token address.
    error InvalidShareTokenAddress();
    /// @notice Reverts when the Chainlink oracle returns a non-positive answer.
    error OraclePriceNotPositive();
    /// @notice Reverts when the oracle's `updatedAt` is older than `ORACLE_HEARTBEAT_TIMEOUT`.
    error StaleOraclePrice();
    /// @notice Reverts when `emergencyClearPendingDeposit` is called with `amount` greater than
    ///         the currently pending deposit.
    error InsufficientPendingDeposit();
    /// @notice Reverts when an operation (e.g. `_board`, `requestWithdrawal`) is attempted while a
    ///         deposit is already pending.
    error PendingDepositActive();
    /// @notice Reverts when `requestWithdrawal` is called while a withdrawal cycle is already in
    ///         flight (`pendingWithdrawalShares > 0`).
    error PendingWithdrawalActive();
    /// @notice Reverts when a state-changing entry point is invoked while the ark is frozen via
    ///         `setArkFrozen`.
    error ArkIsFrozen();
    /// @notice Reverts when `setDepositSlippage` or the constructor is given a value above
    ///         `MAX_DEPOSIT_SLIPPAGE`.
    /// @param newSlippage The supplied slippage
    /// @param maxSlippage The hard cap (`MAX_DEPOSIT_SLIPPAGE`)
    error InvalidDepositSlippage(
        Percentage newSlippage,
        Percentage maxSlippage
    );
    /// @notice Reverts when `setSweepSlippage` or the constructor is given a value above
    ///         `MAX_SWEEP_SLIPPAGE`.
    /// @param newSlippage The supplied slippage
    /// @param maxSlippage The hard cap (`MAX_SWEEP_SLIPPAGE`)
    error InvalidSweepSlippage(Percentage newSlippage, Percentage maxSlippage);
    /// @notice Reverts in `sweep` when the assets returned by WisdomTree convert to fewer shares
    ///         (at current oracle price) than `pendingWithdrawalShares - sweepSlippage`.
    /// @param receivedAssets The asset balance the ark holds at sweep time
    /// @param expectedShares `pendingWithdrawalShares` at sweep time
    /// @param receivedShares Asset balance converted back to shares via the oracle
    error InsufficientAssetsReturned(
        uint256 receivedAssets,
        uint256 expectedShares,
        uint256 receivedShares
    );
    /// @notice Reverts in `clearPendingDeposit` when the share delta since `cachedShareBalance` is
    ///         below the oracle-implied expected shares minus `depositSlippage`.
    /// @param expectedShares Oracle-implied shares for `pendingDepositAssets`
    /// @param actualNewShares Live share balance minus `cachedShareBalance`
    error SharesNotArrived(uint256 expectedShares, uint256 actualNewShares);

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when `clearPendingDeposit` or `emergencyClearPendingDeposit` reduces
    ///         `pendingDepositAssets`.
    /// @param amountCleared The amount removed from `pendingDepositAssets`
    event PendingDepositCleared(uint256 amountCleared);

    /// @notice Emitted by `requestWithdrawal` after shares are sent to the WisdomTree custodian for
    ///         off-chain redemption.
    /// @param shares Shares transferred to the custodian wallet
    /// @param expectedAssets Underlying asset amount the keeper requested (informational)
    event SharesSentForRedemption(uint256 shares, uint256 expectedAssets);

    /// @notice Emitted when the WisdomTree custodian wallet is rotated.
    event CustodianWalletUpdated(address oldWallet, address newWallet);

    /// @notice Emitted whenever `setArkFrozen` is called.
    /// @param isFrozen The new frozen flag
    /// @param frozenTotalAssets The `totalAssets` reading captured at freeze time (0 when
    ///                          unfreezing)
    event ArkIsFrozenUpdated(bool isFrozen, uint256 frozenTotalAssets);

    /// @notice Emitted by `setSweepSlippage` after the cap is updated.
    event SweepSlippageUpdated(
        Percentage oldSweepSlippage,
        Percentage newSweepSlippage
    );

    /// @notice Emitted by `setDepositSlippage` after the cap is updated.
    event DepositSlippageUpdated(
        Percentage oldDepositSlippage,
        Percentage newDepositSlippage
    );

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The WisdomTree wallet that receives USDC
    address public custodianWallet;

    /// @notice The WisdomTree share token contract (e.g. WTGXX)
    IERC20 public immutable shareToken;

    /// @notice Chainlink price feed: price of 1 WisdomTree share denominated in underlying asset
    AggregatorV3Interface public immutable oracle;

    /// @notice Decimals reported by the Chainlink oracle
    uint8 public immutable oracleDecimals;

    /// @notice Decimals of the underlying asset (e.g. 6 for USDC)
    uint8 public immutable assetDecimals;

    /// @notice Decimals of the WisdomTree share token
    uint8 public immutable shareDecimals;

    /// @notice One full asset with the correct decimals
    uint256 public immutable ONE_ASSET;

    /// @notice Validated USDC amounts deposited to WisdomTree, awaiting corresponding share issuance clearance.
    uint256 public pendingDepositAssets;

    /// @notice Frozen share balance used while deposits are pending to prevent double-counting newly minted shares.
    uint256 public cachedShareBalance;

    /// @notice Expected returning USDC amount equivalent to redeemed shares.
    uint256 public pendingWithdrawalShares;

    /// @notice Report of shares is given from cache or not
    bool public isArkFrozen;

    /// @notice Maximum slippage for the sweep swap
    Percentage public sweepSlippage;

    /// @notice Maximum slippage for deposit clearance
    Percentage public depositSlippage;

    /// @notice Total assets of the ark when it was frozen
    uint256 private _frozenTotalAssets;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Wires the ark to its off-chain counterparties and slippage bounds.
     * @param _custodianWallet WisdomTree-controlled wallet that receives USDC on `_board` and
     *                         returns USDC after settlement.
     * @param _shareToken WisdomTree share token (e.g. WTGXX) issued for accepted USDC deposits.
     * @param _oracle Chainlink price feed for "1 share denominated in underlying asset".
     * @param _sweepSlippage Initial sweep slippage cap; must be `<= MAX_SWEEP_SLIPPAGE` (0.5%).
     * @param _depositSlippage Initial deposit slippage cap; must be `<= MAX_DEPOSIT_SLIPPAGE` (0.5%).
     * @param _params Standard `ArkParams` (asset, commander, deposit caps, etc.).
     */
    constructor(
        address _custodianWallet,
        address _shareToken,
        address _oracle,
        Percentage _sweepSlippage,
        Percentage _depositSlippage,
        ArkParams memory _params
    ) ArkWithWithdrawalRequest(_params, DEFAULT_SWAP_SLIPPAGE) {
        if (_custodianWallet == address(0)) revert InvalidTargetWallet();
        if (_oracle == address(0)) revert InvalidOracleAddress();
        if (_shareToken == address(0)) revert InvalidShareTokenAddress();

        custodianWallet = _custodianWallet;
        shareToken = IERC20(_shareToken);
        oracle = AggregatorV3Interface(_oracle);
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
        oracleDecimals = AggregatorV3Interface(_oracle).decimals();
        shareDecimals = IERC20Metadata(_shareToken).decimals();
        assetDecimals = IERC20Metadata(_params.asset).decimals();
        ONE_ASSET = 10 ** assetDecimals;
    }

    /// @notice Gates a function on `isArkFrozen == false`. Reverts with `ArkIsFrozen` while the
    ///         governor has the ark quarantined via `setArkFrozen(true, ...)`.
    modifier onlyNotFrozen() {
        if (isArkFrozen) revert ArkIsFrozen();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArk
     * @notice totalAssets = (actual shares * oracle price) + pending deposits + pending withdrawals
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

        // If there is an active deposit queue, we use the cached share balance.
        // This prevents double-counting shares that arrive before the keeper clears the deposit.
        uint256 currentShares = pendingDepositAssets > 0
            ? cachedShareBalance
            : shareToken.balanceOf(address(this));
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
     * @notice Converts WisdomTree shares to underlying asset amount using the oracle
     * @param shares Amount in `shareDecimals`
     * @return Equivalent amount in `assetDecimals`
     */
    function sharesToAssets(uint256 shares) external view returns (uint256) {
        return _sharesToAssets(shares);
    }

    /*//////////////////////////////////////////////////////////////
                         KEEPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the WisdomTree target wallet receiving USDC.
     * @param _custodianWallet The new custodian wallet address
     */
    function setCustodianWallet(address _custodianWallet) external onlyKeeper {
        if (_custodianWallet == address(0)) revert InvalidTargetWallet();
        emit CustodianWalletUpdated(custodianWallet, _custodianWallet);
        custodianWallet = _custodianWallet;
    }

    /**
     * @notice Freezes or unfreezes the ark. While frozen, `_board`, `_disembark`,
     *         `requestWithdrawal`, and `sweep` revert via `onlyNotFrozen`, and `totalAssets()`
     *         returns the snapshot taken at freeze time instead of recomputing from live state.
     * @dev Pass `type(uint256).max` as `frozenTotalAssets` to snapshot the current `totalAssets()`
     *      at freeze time; pass any other value to override the snapshot. The value is ignored when
     *      unfreezing. Restricted to the keeper role.
     * @param _isArkFrozen The new frozen flag
     * @param frozenTotalAssets `type(uint256).max` to snapshot live `totalAssets()`, otherwise the
     *                          literal value used while frozen
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
     * @notice Clears the full pending deposit after WisdomTree has actually delivered the
     *         corresponding shares on-chain.
     * @dev `_validateReceivedShares` enforces that the share-balance delta since
     *      `cachedShareBalance` covers the oracle-implied expected shares minus `depositSlippage`,
     *      so the keeper cannot accidentally clear before the off-chain mint settles. Partial
     *      clearance is not supported here; the governor must use `emergencyClearPendingDeposit`.
     *      Restricted to the keeper role.
     */
    function clearPendingDeposit() external onlyKeeper {
        _validateReceivedShares(pendingDepositAssets);
        _clearPendingDeposit(pendingDepositAssets);
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @dev Computes the share amount equivalent to `amount` via the oracle, transfers the shares to
     *      `custodianWallet`, and increases `pendingWithdrawalShares`. Reverts with
     *      `PendingDepositActive` if a deposit cycle is in flight or `PendingWithdrawalActive` if a
     *      withdrawal cycle is already in flight — these cycles are intentionally single-threaded.
     */
    function requestWithdrawal(
        uint256 amount
    ) external override onlyKeeper onlyNotFrozen {
        // Prevent concurrent deposit/withdrawal cycles
        if (pendingWithdrawalShares > 0) revert PendingWithdrawalActive();
        if (pendingDepositAssets > 0) revert PendingDepositActive();

        uint256 sharesToRedeem = _assetsToShares(amount);

        // Transfer the WisdomTree shares off-chain (back to the target wallet)
        shareToken.safeTransfer(custodianWallet, sharesToRedeem);

        // Record the total pending withdrawal shares for calculations
        pendingWithdrawalShares += sharesToRedeem;

        emit SharesSentForRedemption(sharesToRedeem, amount);
        emit WithdrawalRequested(amount, 0);
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @dev No-op: WisdomTree processes withdrawals entirely off-chain.
     */
    function claimWithdrawal() external override onlyKeeper {
        // No-op
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @dev No-op: Swap-based exits are not supported for this Ark.
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
     * @dev Called by keeper after WisdomTree returns the USDC equivalent for the retired shares.
     */
    function sweep()
        public
        override
        onlyKeeper
        onlyNotFrozen
        nonReentrant
        returns (address[] memory sweptTokens, uint256[] memory sweptAmounts)
    {
        IERC20 asset = config.asset;

        // Check that the amount of assets returned in shares with current oracle price
        // is not less than the amount of shares requested minus the sweep slippage
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
     * @notice Bypass-slippage variant of `sweep`. Sends every USDC the ark currently holds to the
     *         FleetCommander buffer ark and clears `pendingWithdrawalShares`.
     * @dev Used when WisdomTree returns less than `pendingWithdrawalShares - sweepSlippage`, which
     *      would block the keeper-facing `sweep`. The slippage check is intentionally skipped here;
     *      the governor should adjust `sweepSlippage` or address the root cause before re-enabling
     *      normal flow. Restricted to the governor role.
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
     * @notice Partial-clearance variant of `clearPendingDeposit` that accepts the current share
     *         balance as valid without running the slippage check.
     * @dev Used when WisdomTree partially fills a deposit in a way the keeper-facing flow cannot
     *      reconcile, or when oracle staleness blocks the share-arrival validation. The supplied
     *      `amount` must be `<= pendingDepositAssets`. Restricted to the governor role.
     * @param amount The portion of `pendingDepositAssets` to clear.
     */
    function emergencyClearPendingDeposit(
        uint256 amount
    ) external onlyGovernor {
        if (amount > pendingDepositAssets) revert InsufficientPendingDeposit();
        _clearPendingDeposit(amount);
    }

    /**
     * @dev Shared sweep tail used by both `sweep` and `emergencySweep`. Clears
     *      `pendingWithdrawalShares`, forwards the asset balance to the FleetCommander's buffer
     *      ark (skipping if this ark *is* the buffer), and emits the `Disembarked` / `ArkSwept`
     *      events the indexer consumes.
     * @param amountToSweep The asset amount to forward to the buffer
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
        // to keep compatibility with the indexer
        emit Disembarked(msg.sender, address(asset), sweptAmounts[0]);

        if (sweptAmounts[0] > 0 && address(this) != bufferArk) {
            asset.forceApprove(bufferArk, sweptAmounts[0]);
            IArk(bufferArk).board(sweptAmounts[0], bytes(""));
        }

        emit ArkSwept(sweptTokens, sweptAmounts);
    }

    /**
     * @notice Sets the sweep slippage
     * @param newSweepSlippage The new sweep slippage
     */
    function setSweepSlippage(Percentage newSweepSlippage) external onlyKeeper {
        if (newSweepSlippage > MAX_SWEEP_SLIPPAGE) {
            revert InvalidSweepSlippage(newSweepSlippage, MAX_SWEEP_SLIPPAGE);
        }

        emit SweepSlippageUpdated(sweepSlippage, newSweepSlippage);

        sweepSlippage = newSweepSlippage;
    }

    /**
     * @notice Sets the deposit slippage
     * @param newDepositSlippage The new deposit slippage
     */
    function setDepositSlippage(
        Percentage newDepositSlippage
    ) external onlyKeeper {
        if (newDepositSlippage > MAX_DEPOSIT_SLIPPAGE) {
            revert InvalidDepositSlippage(
                newDepositSlippage,
                MAX_DEPOSIT_SLIPPAGE
            );
        }

        emit DepositSlippageUpdated(depositSlippage, newDepositSlippage);

        depositSlippage = newDepositSlippage;
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Caches placeholder deposit and sends USDC to WisdomTree target wallet.
     * @dev If this is the start of a deposit queue, snapshots the real share balance.
     */
    function _board(
        uint256 amount,
        bytes calldata
    ) internal override onlyNotFrozen {
        if (pendingDepositAssets > 0) {
            revert PendingDepositActive();
        }
        cachedShareBalance = shareToken.balanceOf(address(this));
        pendingDepositAssets += amount;

        config.asset.safeTransfer(custodianWallet, amount);
    }

    /**
     * @dev No-op: Withdrawals are fully asynchronous via `requestWithdrawal` and `sweep`.
     */
    function _disembark(
        uint256,
        bytes calldata
    ) internal view override onlyNotFrozen {}

    /**
     * @dev Always 0: Synchronous withdrawal is not supported.
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
     * @dev No-op: No rewards generated by this Ark.
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

    function _validateBoardData(bytes calldata) internal override {}
    function _validateDisembarkData(bytes calldata) internal override {}

    /*//////////////////////////////////////////////////////////////
                            ORACLE HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Converts WisdomTree shares to underlying asset amount via Chainlink oracle.
     */
    function _sharesToAssets(uint256 shares) internal view returns (uint256) {
        if (shares == 0) return 0;

        Price memory assetPerSharePrice = _fetchOracleAssetPerSharePrice();

        // Convert Base (Shares) to Quote (Asset)
        return assetPerSharePrice.invert().quote(shares);
    }

    /**
     * @dev Converts underlying asset amount to WisdomTree shares via Chainlink oracle.
     */
    function _assetsToShares(
        uint256 assetAmount
    ) internal view returns (uint256) {
        if (assetAmount == 0) return 0;

        Price memory assetPerSharePrice = _fetchOracleAssetPerSharePrice();

        // Convert Quote (Asset) to Base (Shares)
        return assetPerSharePrice.quote(assetAmount);
    }

    /**
     * @dev Fetches the oracle asset per share price and returns it as a Price type
     *      for which the base amount is 1 Share and the quote amount is the oracle price
     *      adjusted for the asset decimals
     */
    function _fetchOracleAssetPerSharePrice()
        internal
        view
        returns (Price memory)
    {
        (, int256 answer, , uint256 updatedAt, ) = oracle.latestRoundData();
        if (answer <= 0) revert OraclePriceNotPositive();

        if (block.timestamp - updatedAt > ORACLE_HEARTBEAT_TIMEOUT) {
            revert StaleOraclePrice();
        }

        // The oracle returns the price of 1 share denominated in the underlying asset.
        // Therefore, the Base Asset is the WisdomTree share, and Quote Asset is the underlying asset.
        return
            toPriceFromOraclePrice(
                10 ** shareDecimals, // baseAmount (1 Share)
                answer, // oracle price of 1 Share in Assets
                oracleDecimals, // decimals of oracle price
                assetDecimals // decimals of quote asset (Asset)
            );
    }

    /**
     * @dev Reduces `pendingDepositAssets` by `amountCleared` and resets `cachedShareBalance` to
     *      the live balance so subsequent `totalAssets()` reads pick up the freshly delivered
     *      shares. Used by both the keeper-facing full clearance and the governor-only partial
     *      clearance paths.
     */
    function _clearPendingDeposit(uint256 amountCleared) internal {
        pendingDepositAssets -= amountCleared;
        cachedShareBalance = shareToken.balanceOf(address(this));

        emit PendingDepositCleared(amountCleared);
    }

    /// @dev Reverts unless the share-balance delta since `cachedShareBalance` covers the
    ///      oracle-implied expected shares minus `depositSlippage`. Defends against clearing a
    ///      pending deposit before WisdomTree has actually minted the matching shares.
    function _validateReceivedShares(uint256 amount) internal view {
        if (amount > pendingDepositAssets) revert InsufficientPendingDeposit();
        uint256 currentShares = shareToken.balanceOf(address(this));
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
