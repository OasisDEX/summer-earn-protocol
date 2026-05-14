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

    error InvalidTargetWallet();
    error InvalidOracleAddress();
    error InvalidShareTokenAddress();
    error OraclePriceNotPositive();
    error StaleOraclePrice();
    error InsufficientPendingDeposit();
    error PendingDepositActive();
    error PendingWithdrawalActive();
    error ArkIsFrozen();
    error InvalidDepositSlippage(
        Percentage newSlippage,
        Percentage maxSlippage
    );
    error InvalidSweepSlippage(Percentage newSlippage, Percentage maxSlippage);
    error InsufficientAssetsReturned(
        uint256 receivedAssets,
        uint256 expectedShares,
        uint256 receivedShares
    );
    error SharesNotArrived(uint256 expectedShares, uint256 actualNewShares);

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event PendingDepositCleared(uint256 amountCleared);
    event SharesSentForRedemption(uint256 shares, uint256 expectedAssets);
    event CustodianWalletUpdated(address oldWallet, address newWallet);
    event ArkIsFrozenUpdated(bool isFrozen, uint256 frozenTotalAssets);
    event SweepSlippageUpdated(
        Percentage oldSweepSlippage,
        Percentage newSweepSlippage
    );
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
     * @notice Freezes or unfreezes deposits for this Ark.
     * @param _isArkFrozen The new frozen state
     * @param frozenTotalAssets The total assets of the ark when it was frozen
     * @dev we use type(uint256).max as default trigger
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
     * @notice Removes a fulfilled deposit amount from `pendingDepositAssets`.
     * @dev Called by the keeper after WisdomTree issues shares to this contract.
     *      Assumes full clearance (no partial fills).
     */
    function clearPendingDeposit() external onlyKeeper {
        _validateReceivedShares(pendingDepositAssets);
        _clearPendingDeposit(pendingDepositAssets);
    }

    /**
     * @notice Removes a fulfilled deposit amount from `pendingDepositAssets`.
     * @dev Called by the keeper after WisdomTree issues shares to this contract to
     *      clear a partial deposit.
     */
    function clearPendingDeposit(uint256 amount) external onlyKeeper {
        _validateReceivedShares(amount);
        _clearPendingDeposit(amount);
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @notice Calculates the equivalent shares for the requested `amount` and sends them to the `custodianWallet`.
     * @dev Also records the the pending withdrawal shares. Reverts if deposit is pending.
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
     * @notice Sweeps returned USDC to buffer without slippage checks.
     * @dev Called by governor in case of emergency or unexpected slippage.
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
     * @notice Accepts current share balance as valid
     * @dev Called by governor in case of execution delays causing slippage reverts,
     * or if WisdomTree partially fills an order in a way the Keeper cannot process.
     * @param amount The amount of pending USDC deposit to forcefully clear.
     */
    function emergencyClearPendingDeposit(
        uint256 amount
    ) external onlyGovernor {
        if (amount > pendingDepositAssets) revert InsufficientPendingDeposit();
        _clearPendingDeposit(amount);
    }

    /**
     * @notice Internal function for sweeping assets
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
     * @notice Removes a fulfilled deposit amount from `pendingDepositAssets`.
     * @param amountCleared The amount of USDC pending deposit to clear.
     */
    function _clearPendingDeposit(uint256 amountCleared) internal {
        pendingDepositAssets -= amountCleared;
        cachedShareBalance = shareToken.balanceOf(address(this));

        emit PendingDepositCleared(amountCleared);
    }

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
