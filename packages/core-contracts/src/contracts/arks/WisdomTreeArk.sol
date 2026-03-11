// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AggregatorV3Interface} from "../../interfaces/external/Chainlink/AggregatorV3Interface.sol";
import "../ArkWithWithdrawalRequest.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@summerfi/price-solidity/contracts/PriceUtils.sol";

/**
 * @title WisdomTreeArk
 * @notice Ark for managing off-chain WisdomTree tokenised assets (e.g. WTBTC).
 *
 * @dev Asset tracking model:
 *   totalAssets() = (actualShares * oraclePrice) + pendingDepositAssets + pendingWithdrawalAssets
 *
 *   Lifecycle:
 *   1. Deposit (`_board`):
 *      - If it's the first deposit in the queue (`pendingDepositAssets == 0`),
 *        the Ark snapshots its live share balance into `cachedShareBalance`.
 *      - USDC is transferred to `CUSTODIAN_WALLET`.
 *      - `pendingDepositAssets` increases by the sent amount.
 *
 *   2. Share Delivery & Keeper Deposit Clearance (`clearPendingDeposit`):
 *      - WisdomTree mints shares and transfers them to this Ark off-chain.
 *      - While `pendingDepositAssets > 0`, `totalAssets` uses `cachedShareBalance`,
 *        so the newly arriving shares are NOT double-counted.
 *      - The Keeper observes the incoming shares and calls `clearPendingDeposit`.
 *        This resets `pendingDepositAssets` to 0 (we assume no partial fills),
 *        releases the cache, and `totalAssets` switches back to using the pure live balance.
 *
 *   3. Withdrawal Request (`requestWithdrawal`):
 *      - Calculates equivalent shares and transfers them to `CUSTODIAN_WALLET`.
 *      - Reduces `cachedShareBalance` (if frozen) to prevent artificial value propping.
 *      - Increases `pendingWithdrawalAssets`.
 *
 *   4. Sweep (`sweep`):
 *      - USDC arrives from WisdomTree. Keeper calls `sweep()`.
 *      - `pendingWithdrawalAssets = 0`. USDC swept to `bufferArk`.
 */
contract WisdomTreeArk is ArkWithWithdrawalRequest, ERC721Holder {
    using SafeERC20 for IERC20;
    using PriceUtils for Price;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Default slippage (0.02%)
    uint256 public constant DEFAULT_SLIPPAGE = 2;

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidTargetWallet();
    error InvalidOracleAddress();
    error InvalidShareTokenAddress();
    error OraclePriceNotPositive();
    error InsufficientPendingDeposit();
    error PendingDepositActive();

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event PendingDepositCleared(uint256 amountCleared);
    event SharesSentForRedemption(uint256 shares, uint256 expectedAssets);

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    // TODO: not 100% sure it will be immutable - we might need an option for the keeper to change it
    /// @notice The WisdomTree wallet that receives USDC
    address public immutable CUSTODIAN_WALLET;

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
    uint256 public pendingWithdrawalAssets;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _custodianWallet,
        address _shareToken,
        address _oracle,
        ArkParams memory _params
    ) ArkWithWithdrawalRequest(_params, DEFAULT_SLIPPAGE) {
        if (_custodianWallet == address(0)) revert InvalidTargetWallet();
        if (_oracle == address(0)) revert InvalidOracleAddress();
        if (_shareToken == address(0)) revert InvalidShareTokenAddress();

        CUSTODIAN_WALLET = _custodianWallet;
        shareToken = IERC20(_shareToken);
        oracle = AggregatorV3Interface(_oracle);
        oracleDecimals = AggregatorV3Interface(_oracle).decimals();
        shareDecimals = IERC20Metadata(_shareToken).decimals();
        assetDecimals = IERC20Metadata(_params.asset).decimals();
        ONE_ASSET = 10 ** assetDecimals;
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
        // If there is an active deposit queue, we use the cached share balance.
        // This prevents double-counting shares that arrive before the keeper clears the deposit.
        uint256 currentShares = pendingDepositAssets > 0
            ? cachedShareBalance
            : shareToken.balanceOf(address(this));

        assets =
            _sharesToAssets(currentShares) +
            pendingWithdrawalAssets +
            pendingDepositAssets;
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function assetsInWithdrawalQueue() public view override returns (uint256) {
        return pendingWithdrawalAssets;
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
     * @notice Removes a fulfilled deposit amount from `pendingDepositAssets`.
     * @dev Called by the keeper after WisdomTree issues shares to this contract.
     *      Assumes full clearance (no partial fills).
     */
    function clearPendingDeposit() external onlyKeeper {
        emit PendingDepositCleared(pendingDepositAssets);

        pendingDepositAssets = 0;
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @notice Calculates the equivalent shares for the requested `amount` and sends them to the `CUSTODIAN_WALLET`.
     * @dev Also records the expected returning USDC in `pendingWithdrawalAssets`. Reverts if deposit is pending.
     */
    function requestWithdrawal(uint256 amount) external override onlyKeeper {
        // Prevent concurrent deposit/withdrawal cycles
        if (pendingDepositAssets > 0) revert PendingDepositActive();

        uint256 sharesToRedeem = _assetsToShares(amount);

        // Transfer the WisdomTree shares off-chain (back to the target wallet)
        shareToken.safeTransfer(CUSTODIAN_WALLET, sharesToRedeem);

        // Record the expected returning USDC amount to keep totalAssets continuous
        pendingWithdrawalAssets += amount;

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
     * @notice Sweeps returned USDC to buffer and clears `pendingWithdrawalAssets`.
     * @dev Called by keeper after WisdomTree returns the USDC equivalent for the retired shares.
     */
    function sweep()
        public
        override
        onlyKeeper
        nonReentrant
        returns (address[] memory sweptTokens, uint256[] memory sweptAmounts)
    {
        pendingWithdrawalAssets = 0;
        return super.sweep();
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Caches placeholder deposit and sends USDC to WisdomTree target wallet.
     * @dev If this is the start of a deposit queue, snapshots the real share balance.
     */
    function _board(uint256 amount, bytes calldata) internal override {
        if (pendingDepositAssets == 0) {
            cachedShareBalance = shareToken.balanceOf(address(this));
        }

        pendingDepositAssets += amount;

        config.asset.safeTransfer(CUSTODIAN_WALLET, amount);
    }

    /**
     * @dev No-op: Withdrawals are fully asynchronous via `requestWithdrawal` and `sweep`.
     */
    function _disembark(uint256, bytes calldata) internal pure override {}

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

        Price memory sharesToAssetPrice = _fetchOracleSharesToAssetPrice();

        return sharesToAssetPrice.quote(shares);
    }

    /**
     * @dev Converts underlying asset amount to WisdomTree shares via Chainlink oracle.
     */
    function _assetsToShares(
        uint256 assetAmount
    ) internal view returns (uint256) {
        if (assetAmount == 0) return 0;

        Price memory assetToSharesPrice = _fetchOracleSharesToAssetPrice()
            .invert();

        return assetToSharesPrice.quote(assetAmount);
    }

    /**
     * @dev Fetches the oracle shares to asset price and returns it as a Price type
     *      for which the base amount is ONE_ASSET and the quote amount is the oracle price
     *      adjusted for the shares decimals)
     */
    function _fetchOracleSharesToAssetPrice()
        internal
        view
        returns (Price memory)
    {
        (, int256 answer, , , ) = oracle.latestRoundData();
        if (answer <= 0) revert OraclePriceNotPositive();

        return
            toPriceFromOraclePrice(
                ONE_ASSET,
                answer,
                oracleDecimals,
                shareDecimals
            );
    }
}
