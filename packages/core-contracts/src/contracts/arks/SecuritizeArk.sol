// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AggregatorV3Interface} from "../../interfaces/external/Chainlink/AggregatorV3Interface.sol";
import "../ArkWithWithdrawalRequest.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {PERCENTAGE_FACTOR, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import "@summerfi/price-solidity/contracts/PriceUtils.sol";
import {IDSToken} from "../../interfaces/securitize/IDSToken.sol";
import {IDSRegistryService} from "../../interfaces/securitize/IDSRegistryService.sol";
import {ISecuritizeOnRamp} from "../../interfaces/securitize/ISecuritizeOnRamp.sol";
import {ISecuritizeArk} from "../../interfaces/arks/ISecuritizeArk.sol";

/**
 * @title SecuritizeArk
 * @notice Ark for allocating into a Securitize DS Protocol security token (`DSToken`) via an
 *         off-chain, issuer-mediated (custodial) settlement model. The base asset (e.g. USDC) is
 *         sent to a Securitize-designated `custodianWallet`; Securitize issues the DSToken to this
 *         Ark off-chain. Redemption reverses the flow. Valuation uses an external NAV oracle.
 *
 * @dev Asset tracking model:
 * totalAssets() = (tokenBalance * oraclePrice) + pendingDepositAssets + (pendingWithdrawalShares * oraclePrice)
 *
 * Prerequisites (off-chain, performed by Securitize):
 * - This Ark's address AND the `custodianWallet` MUST be KYC'd and registered as investor wallets
 *   in the registry service, otherwise every DSToken transfer reverts. See `isArkOnboarded()`.
 *
 * Deposits are HYBRID (keeper-selectable via `setUseOnRampSubscription`):
 * a) On-ramp path (default): Securitize registers a per-fund on-ramp contract in the DSToken's
 *    service registry (id 16384). `_board` approves the base asset to the on-ramp and calls
 *    `swap(amount, minOut)`, which forwards the asset (minus fee) to the fund custodian and MINTS
 *    DSTokens to this Ark in the same transaction at Securitize's NAV — fully synchronous, no
 *    pending-deposit bookkeeping. `minOut` is derived from THIS Ark's oracle minus
 *    `depositSlippage`, so every subscription cross-checks Securitize's NAV against the RedStone
 *    feed (and implicitly caps the on-ramp fee at `depositSlippage`).
 * b) Custodial fallback: send the base asset to `custodianWallet` and track
 *    `pendingDepositAssets` until the keeper confirms off-chain issuance via
 *    `clearPendingDeposit()` (see the rebasing caveat in `_validateReceivedShares`). Used when
 *    the on-ramp is unavailable (subscriptions toggled off, fee above tolerance, min-subscription
 *    constraints, or the service deregistered).
 *
 * Withdrawals are ASYNC only — there is no on-chain off-ramp:
 * 1. `requestWithdrawal`: compliance pre-check, then transfer the DSToken to `custodianWallet`
 *    for off-chain redemption; increase `pendingWithdrawalShares`.
 * 2. `sweep`: the base asset returns from Securitize; the keeper sweeps it to the buffer ark
 *    after the `sweepSlippage` check.
 * 3. Emergency fallbacks: governor-only `emergencySweep()` / `emergencyClearPendingDeposit()` and
 *    keeper `setArkFrozen(...)`.
 *
 * NAV / oracle sources — the single-source fund NAV is available on-chain two ways:
 * 1. Securitize's `ISecuritizeNavProvider`, resolvable via `onRamp().navProvider().rate()`. This
 *    is the operator-set value the on-ramp prices with, but it carries no freshness timestamp and
 *    its service id is marked deprecated in newer DS Protocol sources.
 * 2. The RedStone `*_FUNDAMENTAL` push feed (`AggregatorV3Interface`): same value, with `updatedAt`.
 * This Ark prices with (2) to enforce `ORACLE_HEARTBEAT_TIMEOUT`, and cross-checks (1) via the
 * on-ramp `minOut` on every synchronous subscription.
 */
contract SecuritizeArk is
    ISecuritizeArk,
    ArkWithWithdrawalRequest,
    ERC721Holder
{
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

    /// @notice DS Protocol service id for the registry service (per `IDSServiceConsumer`).
    uint256 public constant REGISTRY_SERVICE_ID = 4;

    /// @notice DS Protocol service id for the Securitize on-ramp (subscription/swap) contract.
    /// @dev Named `DEPRECATED_SECURITIZE_SWAP` in newer DS Protocol sources but live for the
    ///      integrated funds; resolved dynamically so a re-registration is picked up automatically.
    uint256 public constant SECURITIZE_SWAP_SERVICE_ID = 16384;

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The Securitize-controlled wallet that receives the configured asset on deposit and
    ///         returns it after off-chain settlement.
    address public custodianWallet;

    /// @notice The Securitize DSToken (fund share token) this Ark holds. Transfers are
    ///         compliance-gated; see `IDSToken`.
    IERC20 public immutable shareToken;

    /// @notice The Securitize registry service, used to verify this Ark (and counterparties) are
    ///         registered investor wallets before attempting compliance-gated transfers.
    IDSRegistryService public immutable registryService;

    /// @notice Price feed: price of 1 DSToken denominated in the underlying asset (NAV oracle).
    /// @dev RedStone `*_FUNDAMENTAL` push feed. NOTE: the same NAV is also resolvable fully
    ///      on-chain via `onRamp().navProvider().rate()` (Securitize's operator-set TSSO root),
    ///      but that source has no `updatedAt`/staleness signal, so this feed is primary; the two
    ///      are cross-checked on every on-ramp subscription via the oracle-derived `minOut`.
    AggregatorV3Interface public immutable oracle;

    /// @notice Decimals reported by the NAV oracle (RedStone AggregatorV3 feed)
    uint8 public immutable oracleDecimals;

    /// @notice Decimals of the underlying asset configured on this ark (e.g. 6 for USDC)
    uint8 public immutable assetDecimals;

    /// @notice Decimals of the Securitize DSToken (share token)
    uint8 public immutable shareDecimals;

    /// @notice One whole DSToken share, in `shareDecimals` (10 ** shareDecimals)
    uint256 public immutable ONE_SHARE;

    /// @notice Validated configured-asset amount sent to Securitize, awaiting corresponding share
    ///         issuance clearance.
    uint256 public pendingDepositAssets;

    /// @notice Frozen share balance used while deposits are pending to prevent double-counting newly minted shares.
    uint256 public cachedShareBalance;

    /// @notice DSToken shares sent to the custodian for off-chain redemption, pending
    ///         settlement via `sweep`. Denominated in DSToken units.
    uint256 public pendingWithdrawalShares;

    /// @notice True while the ark is quarantined by `setArkFrozen`. Gates state-changing entry
    ///         points via `onlyNotFrozen` and forces `totalAssets()` to return the
    ///         `_frozenTotalAssets` snapshot instead of recomputing from live state.
    bool public isArkFrozen;

    /// @notice Tolerance applied to the expected vs. actual returned configured-asset amount during
    ///         `sweep`, denominated as a `Percentage` (units defined by the `Percentage` type).
    Percentage public sweepSlippage;

    /// @notice Maximum slippage for deposit clearance
    Percentage public depositSlippage;

    /// @notice When true (default), `_board` subscribes synchronously through the Securitize
    ///         on-ramp (`swap`). When false, it falls back to the asynchronous custodial transfer
    ///         tracked via `pendingDepositAssets`.
    bool public useOnRampSubscription;

    /// @notice Total assets of the ark when it was frozen
    uint256 private _frozenTotalAssets;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Wires the ark to its off-chain counterparties and slippage bounds.
     * @param _custodianWallet Securitize-controlled wallet that receives the configured asset on
     *                         `_board` and returns it after settlement.
     * @param _shareToken Securitize DSToken (fund share token) issued for accepted asset deposits.
     * @param _oracle NAV price feed for "1 DSToken denominated in the underlying asset".
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
        // Resolve the registry service directly from the DSToken (service id 4 per
        // IDSServiceConsumer) so it cannot be misconfigured independently of the token.
        address resolvedRegistry = IDSToken(_shareToken).getDSService(
            REGISTRY_SERVICE_ID
        );
        if (resolvedRegistry == address(0)) revert InvalidRegistryAddress();
        registryService = IDSRegistryService(resolvedRegistry);
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
        ONE_SHARE = 10 ** shareDecimals;
        // Default to the synchronous on-ramp subscription path; the keeper can fall back to the
        // custodial path via setUseOnRampSubscription(false).
        useOnRampSubscription = true;
    }

    /// @notice Gates a function on `isArkFrozen == false`. Reverts with `ArkIsFrozen` while the
    ///         keeper has the ark quarantined via `setArkFrozen(true, ...)`.
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
     * @notice Converts DSToken shares to underlying asset amount using the oracle
     * @param shares Amount in `shareDecimals`
     * @return assets Equivalent amount in `assetDecimals`
     */
    function sharesToAssets(
        uint256 shares
    ) external view returns (uint256 assets) {
        return _sharesToAssets(shares);
    }

    /**
     * @notice Whether this Ark is currently a registered investor wallet in the Securitize registry
     *         and may therefore hold/transfer the DSToken. Onboarding is performed off-chain by
     *         Securitize before the Ark can be used.
     */
    function isArkOnboarded() external view returns (bool) {
        return registryService.isWallet(address(this));
    }

    /**
     * @notice Resolves the fund's Securitize on-ramp (subscription/swap) contract from the
     *         DSToken's service registry.
     * @dev Resolved dynamically (not cached) so Securitize re-registrations are picked up.
     *      Returns the zero address if no on-ramp is registered.
     */
    function onRamp() public view returns (ISecuritizeOnRamp) {
        return
            ISecuritizeOnRamp(
                IDSToken(address(shareToken)).getDSService(
                    SECURITIZE_SWAP_SERVICE_ID
                )
            );
    }

    /*//////////////////////////////////////////////////////////////
                         KEEPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the Securitize custodian wallet receiving the configured asset.
     * @dev Restricted to the keeper role.
     * @param _custodianWallet The new custodian wallet address
     */
    function setCustodianWallet(address _custodianWallet) external onlyKeeper {
        if (_custodianWallet == address(0)) revert InvalidTargetWallet();
        emit CustodianWalletUpdated(custodianWallet, _custodianWallet);
        custodianWallet = _custodianWallet;
    }

    /**
     * @notice Switches `_board` between the synchronous on-ramp `swap` path and the asynchronous
     *         custodial-transfer fallback.
     * @dev The path is explicit (no silent fallback): if the on-ramp becomes unavailable, boarding
     *      reverts until the keeper flips this flag — the custodial path requires an off-chain
     *      subscription order with Securitize, so it must never be entered accidentally.
     *      Restricted to the keeper role.
     * @param _useOnRampSubscription True for the on-ramp path, false for the custodial path
     */
    function setUseOnRampSubscription(
        bool _useOnRampSubscription
    ) external onlyKeeper {
        useOnRampSubscription = _useOnRampSubscription;
        emit UseOnRampSubscriptionUpdated(_useOnRampSubscription);
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
     * @notice Clears the full pending deposit after Securitize has actually delivered the
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

        // Compliance pre-flight: surface a typed error instead of an opaque DSToken revert if the
        // transfer to the custodian would fail (e.g. custodian unregistered, token paused, balance
        // locked, destination restricted). Also implicitly asserts this Ark (the sender) is a
        // registered wallet.
        (uint256 code, string memory reason) = IDSToken(address(shareToken))
            .preTransferCheck(address(this), custodianWallet, sharesToRedeem);
        if (code != 0) revert TransferNotCompliant(code, reason);

        // Transfer the Securitize DSToken off-chain (back to the custodian wallet)
        shareToken.safeTransfer(custodianWallet, sharesToRedeem);

        // Record the total pending withdrawal shares for calculations
        pendingWithdrawalShares += sharesToRedeem;

        emit SharesSentForRedemption(sharesToRedeem, amount);
        emit WithdrawalRequested(amount, 0);
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @dev No-op: Securitize processes withdrawals entirely off-chain.
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
     * @notice Sweeps the returned configured asset to the buffer and clears
     *         `pendingWithdrawalShares`.
     * @dev Called by keeper after Securitize returns the configured-asset equivalent for the
     *      retired shares.
     * @return sweptTokens Single-element array containing the configured asset address.
     * @return sweptAmounts Single-element array containing the asset amount forwarded to the
     *                     buffer ark.
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
     * @notice Bypass-slippage variant of `sweep`. Sends the full balance of the configured asset
     *         held by the ark to the FleetCommander buffer ark and clears
     *         `pendingWithdrawalShares`.
     * @dev Used when Securitize returns less than `pendingWithdrawalShares - sweepSlippage`, which
     *      would block the keeper-facing `sweep`. The slippage check is intentionally skipped here;
     *      the governor should adjust `sweepSlippage` or address the root cause before re-enabling
     *      normal flow. Restricted to the governor role.
     * @return sweptTokens Single-element array containing the configured asset address.
     * @return sweptAmounts Single-element array containing the asset amount forwarded to the
     *                     buffer ark.
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
     * @dev Used when Securitize partially fills a deposit in a way the keeper-facing flow cannot
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
     * @dev Restricted to the keeper role. Reverts with `InvalidSweepSlippage` if the supplied
     *      value exceeds `MAX_SWEEP_SLIPPAGE`.
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
     * @dev Restricted to the keeper role. Reverts with `InvalidDepositSlippage` if the supplied
     *      value exceeds `MAX_DEPOSIT_SLIPPAGE`.
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
     * @notice Boards the configured asset into the fund — synchronously via the Securitize
     *         on-ramp `swap` (default) or via the asynchronous custodial transfer (fallback).
     * @dev See the contract-level docs for the two paths and the keeper toggle.
     */
    function _board(
        uint256 amount,
        bytes calldata
    ) internal override onlyNotFrozen {
        // The Ark must be a registered investor wallet to receive/hold the DSToken (the on-ramp
        // enforces the same); fail fast rather than stranding the base asset.
        if (!registryService.isWallet(address(this))) revert ArkNotRegistered();

        if (useOnRampSubscription) {
            _subscribeViaOnRamp(amount);
        } else {
            // Custodial fallback: requires a matching off-chain subscription order.
            if (pendingDepositAssets > 0) {
                revert PendingDepositActive();
            }
            cachedShareBalance = shareToken.balanceOf(address(this));
            pendingDepositAssets += amount;

            config.asset.safeTransfer(custodianWallet, amount);
        }
    }

    /**
     * @dev Synchronous primary-market subscription through the Securitize on-ramp: approves the
     *      base asset and calls `swap(amount, minOut)`. The on-ramp forwards the asset (minus its
     *      fee) to the fund custodian and mints DSTokens to this Ark in the same transaction at
     *      Securitize's NAV. `minOut` is derived from THIS Ark's RedStone oracle minus
     *      `depositSlippage`, cross-checking the two NAV sources and capping the effective on-ramp
     *      fee at `depositSlippage`.
     */
    function _subscribeViaOnRamp(uint256 amount) internal {
        ISecuritizeOnRamp ramp = onRamp();
        if (address(ramp) == address(0)) revert OnRampNotConfigured();
        if (!ramp.investorSubscriptionEnabled()) {
            revert OnRampSubscriptionDisabled();
        }

        uint256 sharesBefore = shareToken.balanceOf(address(this));
        uint256 expectedShares = _assetsToShares(amount);
        uint256 minOut = expectedShares.subtractPercentage(depositSlippage);

        config.asset.forceApprove(address(ramp), amount);
        ramp.swap(amount, minOut);

        uint256 received = shareToken.balanceOf(address(this)) - sharesBefore;
        if (received < minOut) {
            revert SharesNotArrived(expectedShares, received);
        }

        emit SubscribedViaOnRamp(amount, received);
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

    /// @dev No-op: this ark accepts no boardData payload.
    function _validateBoardData(bytes calldata) internal override {}

    /// @dev No-op: this ark accepts no disembarkData payload.
    function _validateDisembarkData(bytes calldata) internal override {}

    /*//////////////////////////////////////////////////////////////
                            ORACLE HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Converts DSToken shares to the underlying asset amount via the NAV oracle.
     */
    function _sharesToAssets(uint256 shares) internal view returns (uint256) {
        if (shares == 0) return 0;

        Price memory assetPerSharePrice = _fetchOracleAssetPerSharePrice();

        // Convert Base (Shares) to Quote (Asset)
        return assetPerSharePrice.invert().quote(shares);
    }

    /**
     * @dev Converts an underlying asset amount to DSToken shares via the NAV oracle.
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

        // The oracle prices one share in the underlying asset: base = DSToken share, quote = asset.
        return
            toPriceFromOraclePrice(
                ONE_SHARE, // base amount: one whole share
                answer, // oracle price of one share, in asset terms
                oracleDecimals, // decimals of the oracle price
                assetDecimals // decimals of the quote (asset)
            );
    }

    /**
     * @dev Reduces `pendingDepositAssets` by `amountCleared` and resets `cachedShareBalance` to
     *      the live balance so subsequent `totalAssets()` reads pick up the freshly delivered
     *      shares. Used by both the keeper-facing full clearance and the governor-only partial
     *      clearance paths.
     * @param amountCleared Amount of `pendingDepositAssets` to remove from the pending queue.
     */
    function _clearPendingDeposit(uint256 amountCleared) internal {
        pendingDepositAssets -= amountCleared;
        cachedShareBalance = shareToken.balanceOf(address(this));

        emit PendingDepositCleared(amountCleared);
    }

    /// @dev Reverts unless the share-balance delta since `cachedShareBalance` covers the
    ///      oracle-implied expected shares minus `depositSlippage`. Defends against clearing a
    ///      pending deposit before Securitize has actually issued the matching shares.
    /// @param amount Portion of `pendingDepositAssets` whose share-delivery is being validated.
    ///               Must be `<= pendingDepositAssets`; reverts with `InsufficientPendingDeposit`
    ///               otherwise.
    function _validateReceivedShares(uint256 amount) internal view {
        // The DSToken rebases: `balanceOf` can move between the `_board` snapshot
        // (`cachedShareBalance`) and clearance when the yield multiplier updates, which skews this
        // delta. `depositSlippage` absorbs an intra-window rebase; for funds with larger rebase
        // steps, denominate the snapshot/delta in the token's non-rebasing shares instead.
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
