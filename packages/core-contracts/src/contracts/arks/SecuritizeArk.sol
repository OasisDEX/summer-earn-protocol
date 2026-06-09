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
 * @notice Ark for allocating into a Securitize DS Protocol security token (`DSToken`, e.g. VBILL,
 *         ACRED, STAC). Valuation uses an external NAV oracle.
 *
 * @dev Asset tracking model:
 * totalAssets() = (tokenBalance + pendingWithdrawalShares) * oraclePrice
 *
 * Deposits (synchronous, on-ramp subscription):
 * - Securitize subscriptions are operator-authorized: an EXCHANGE/ISSUER key signs an EIP-712
 *   `ExecutePreApprovedTransaction` (an internal `subscribe(...)`). The Ark cannot sign — Securitize
 *   provides the signed payload off-chain and the keeper passes it as `board` data
 *   (`requiresKeeperData = true`).
 * - `_validateBoardData` (the keeper board-data hook, run before `_board`) resolves the fund
 *   on-ramp (DS service id 16384) and checks the payload relays a `subscribe` to that on-ramp which
 *   mints to THIS Ark. `_board` then binds the payload to the boarded amount, approves the base
 *   asset, and relays `executePreApprovedTransaction`. The on-ramp forwards the asset (minus fee) to
 *   the fund custodian and MINTS the DSToken to this Ark in the same transaction. A post-mint check
 *   enforces the minted shares are within `depositSlippage` of the oracle-implied amount (catching
 *   NAV-source divergence or an excessive on-ramp fee). The relayed `subscribe` also onboards this
 *   Ark in the registry, so no separate onboarding step is needed.
 *
 * Withdrawals (asynchronous — there is no on-chain off-ramp):
 * 1. `requestWithdrawal`: compliance pre-check, then transfer the DSToken to `custodianWallet` for
 *    off-chain redemption; increase `pendingWithdrawalShares`.
 * 2. `sweep`: the base asset returns from Securitize; the keeper sweeps it to the buffer ark after
 *    the `sweepSlippage` check (governor `emergencySweep` bypasses it). `setArkFrozen` quarantines.
 *
 * NAV / oracle sources — the single-source fund NAV is available on-chain two ways:
 * 1. Securitize's `ISecuritizeNavProvider`, resolvable via `onRamp().navProvider().rate()`. This is
 *    the operator-set value the on-ramp prices with, but it carries no freshness timestamp and its
 *    service id is marked deprecated in newer DS Protocol sources.
 * 2. The RedStone `*_FUNDAMENTAL` push feed (`AggregatorV3Interface`): same value, with `updatedAt`.
 * This Ark prices with (2) to enforce `ORACLE_HEARTBEAT_TIMEOUT`, and cross-checks (1) via the
 * post-mint `depositSlippage` bound on every subscription.
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

    /// @notice Default slippage (0.02%) passed to the swap-helper base.
    uint256 public constant DEFAULT_SWAP_SLIPPAGE = 2;

    /// @notice Maximum sweep slippage (0.5%)
    Percentage public constant MAX_SWEEP_SLIPPAGE =
        Percentage.wrap(PERCENTAGE_FACTOR / 2);

    /// @notice Maximum deposit slippage (0.5%)
    Percentage public constant MAX_DEPOSIT_SLIPPAGE =
        Percentage.wrap(PERCENTAGE_FACTOR / 2);

    /// @notice Maximum configurable on-ramp subscription-fee tolerance (5%).
    Percentage public constant MAX_SUBSCRIPTION_FEE =
        Percentage.wrap(PERCENTAGE_FACTOR * 5);

    /// @notice Max age of a NAV answer before it is rejected as stale. Set above the funds'
    ///         ~daily RedStone update cadence to tolerate weekend/holiday gaps without freezing
    ///         valuation (a 24h bound trips on routine ~16h-old updates).
    uint256 public constant ORACLE_HEARTBEAT_TIMEOUT = 48 hours;

    /// @notice DS Protocol service id for the registry service (per `IDSServiceConsumer`).
    uint256 public constant REGISTRY_SERVICE_ID = 4;

    /// @notice DS Protocol service id for the Securitize on-ramp (subscription) contract.
    /// @dev Named `DEPRECATED_SECURITIZE_SWAP` in newer DS Protocol sources but live for the
    ///      integrated funds; resolved dynamically so a re-registration is picked up automatically.
    uint256 public constant SECURITIZE_SWAP_SERVICE_ID = 16384;

    /// @notice Selector of the on-ramp's `subscribe(string,address,string,uint8[],uint256[],
    ///         uint256[],uint256,uint256,uint256,bytes32)` — the only call `_board` will relay.
    bytes4 internal constant SUBSCRIBE_SELECTOR = 0x3ca90bd4;

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The Securitize-controlled wallet that receives the DSToken on redemption requests.
    address public custodianWallet;

    /// @notice The Securitize DSToken (fund share token) this Ark holds. Transfers are
    ///         compliance-gated; see `IDSToken`.
    IERC20 public immutable shareToken;

    /// @notice The Securitize registry service, resolved from the DSToken. Used to surface
    ///         onboarding status (`isArkOnboarded`).
    IDSRegistryService public immutable registryService;

    /// @notice NAV price feed: price of 1 DSToken denominated in the underlying asset.
    /// @dev RedStone `*_FUNDAMENTAL` push feed. The same NAV is also resolvable on-chain via
    ///      `onRamp().navProvider().rate()` (Securitize's operator-set source), but that has no
    ///      `updatedAt`/staleness signal, so this feed is primary; the two are cross-checked on
    ///      every subscription via the oracle-derived `depositSlippage` bound.
    AggregatorV3Interface public immutable oracle;

    /// @notice Decimals reported by the NAV oracle (RedStone AggregatorV3 feed)
    uint8 public immutable oracleDecimals;

    /// @notice Decimals of the underlying asset configured on this ark (e.g. 6 for USDC)
    uint8 public immutable assetDecimals;

    /// @notice Decimals of the Securitize DSToken (share token)
    uint8 public immutable shareDecimals;

    /// @notice One whole DSToken share, in `shareDecimals` (10 ** shareDecimals)
    uint256 public immutable ONE_SHARE;

    /// @notice DSToken shares sent to the custodian for off-chain redemption, pending settlement
    ///         via `sweep`. Denominated in DSToken units.
    uint256 public pendingWithdrawalShares;

    /// @notice Asset value requested at `requestWithdrawal` time. The `sweep` floor (post-slippage)
    ///         is measured against this fixed value, so live-NAV drift between request and
    ///         settlement cannot spuriously block the sweep.
    uint256 public pendingWithdrawalAssets;

    /// @notice True while the ark is quarantined by `setArkFrozen`. Gates state-changing entry
    ///         points via `onlyNotFrozen` and forces `totalAssets()` to return the
    ///         `_frozenTotalAssets` snapshot instead of recomputing from live state.
    bool public isArkFrozen;

    /// @notice Tolerance applied during `sweep` to the expected vs. returned asset amount.
    Percentage public sweepSlippage;

    /// @notice Tolerance applied to the minted-vs-oracle-implied shares on a subscription (NAV
    ///         source divergence between the RedStone feed and Securitize's navProvider).
    Percentage public depositSlippage;

    /// @notice Additional tolerance for the on-ramp's subscription fee, kept separate from the NAV
    ///         divergence `depositSlippage`. Governor-set; defaults to 0.
    Percentage public subscriptionFeeTolerance;

    /// @notice Total assets of the ark when it was frozen
    uint256 private _frozenTotalAssets;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Wires the ark to its counterparties and slippage bounds.
     * @param _custodianWallet Securitize-controlled wallet that receives the DSToken on redemption.
     * @param _shareToken Securitize DSToken (fund share token).
     * @param _oracle NAV price feed for "1 DSToken denominated in the underlying asset".
     * @param _sweepSlippage Initial sweep slippage cap; must be `<= MAX_SWEEP_SLIPPAGE` (0.5%).
     * @param _depositSlippage Initial deposit slippage cap; must be `<= MAX_DEPOSIT_SLIPPAGE` (0.5%).
     * @param _params Standard `ArkParams`. `requiresKeeperData` MUST be true (the on-ramp
     *               subscription payload is supplied as keeper board data).
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
        if (!_params.requiresKeeperData) revert MustRequireKeeperData();

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
    }

    /**
     * @notice Gates a function on `isArkFrozen == false`.
     */
    modifier onlyNotFrozen() {
        if (isArkFrozen) revert ArkIsFrozen();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArk
     * @notice totalAssets = (held shares + pending withdrawal shares) valued via the NAV oracle.
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
        uint256 totalShares = shareToken.balanceOf(address(this)) +
            pendingWithdrawalShares;
        assets = _sharesToAssets(totalShares);
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
     * @notice Whether this Ark is a registered investor wallet in the Securitize registry. The
     *         relayed subscription onboards the Ark on first deposit; this exposes the live status.
     */
    function isArkOnboarded() external view returns (bool) {
        return registryService.isWallet(address(this));
    }

    /**
     * @notice Resolves the fund's Securitize on-ramp from the DSToken's service registry.
     * @dev Resolved dynamically (not cached) so Securitize re-registrations are picked up. Returns
     *      the zero address if no on-ramp is registered.
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
     * @notice Updates the Securitize custodian wallet that receives the DSToken on redemption.
     * @dev Restricted to the governor role: the keeper must not be able to redirect redemption
     *      shares to an arbitrary (registered) wallet.
     */
    function setCustodianWallet(
        address _custodianWallet
    ) external onlyGovernor {
        if (_custodianWallet == address(0)) revert InvalidTargetWallet();
        emit CustodianWalletUpdated(custodianWallet, _custodianWallet);
        custodianWallet = _custodianWallet;
    }

    /**
     * @notice Freezes or unfreezes the ark. While frozen, `_board`, `requestWithdrawal`, and
     *         `sweep` revert via `onlyNotFrozen`, and `totalAssets()` returns the freeze snapshot.
     * @dev Pass `type(uint256).max` as `frozenTotalAssets` to snapshot live `totalAssets()`.
     *      Restricted to the keeper role.
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
     * @inheritdoc IArkWithWithdrawalRequest
     * @dev Compliance pre-checks, transfers the equivalent DSToken shares to `custodianWallet` for
     *      off-chain redemption, and increases `pendingWithdrawalShares`. Single-threaded: reverts
     *      `PendingWithdrawalActive` if a withdrawal cycle is already in flight.
     */
    function requestWithdrawal(
        uint256 amount
    ) external override onlyKeeper onlyNotFrozen {
        if (pendingWithdrawalShares > 0) revert PendingWithdrawalActive();

        uint256 sharesToRedeem = _assetsToShares(amount);

        // Surface a typed error instead of an opaque DSToken revert if the transfer would fail
        // (custodian unregistered, token paused, balance locked, destination restricted). Also
        // implicitly asserts this Ark (the sender) is a registered wallet.
        (uint256 code, string memory reason) = IDSToken(address(shareToken))
            .preTransferCheck(address(this), custodianWallet, sharesToRedeem);
        if (code != 0) revert TransferNotCompliant(code, reason);

        shareToken.safeTransfer(custodianWallet, sharesToRedeem);
        pendingWithdrawalShares += sharesToRedeem;
        pendingWithdrawalAssets += amount;

        emit SharesSentForRedemption(sharesToRedeem, amount);
        emit WithdrawalRequested(amount, 0);
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @dev No-op: Securitize processes redemptions entirely off-chain.
     */
    function claimWithdrawal() external override onlyKeeper {}

    /**
     * @inheritdoc IArkWithSwap
     * @dev No-op: swap-based exits are not supported for this Ark.
     */
    function withdrawUsingSwap(
        uint256,
        bytes calldata
    ) external override onlyKeeper nonReentrant {}

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @notice Sweeps the returned base asset to the buffer and clears `pendingWithdrawalShares`.
     */
    function sweep()
        public
        override
        onlyKeeper
        onlyNotFrozen
        nonReentrant
        returns (address[] memory sweptTokens, uint256[] memory sweptAmounts)
    {
        uint256 returnedAssets = config.asset.balanceOf(address(this));
        // Measure against the asset value snapshotted at request time (not a live-NAV
        // reconversion), so a NAV move between request and settlement can't spuriously block the
        // sweep. A genuine shortfall beyond `sweepSlippage` still reverts (use `emergencySweep`).
        uint256 minReturn = pendingWithdrawalAssets.subtractPercentage(
            sweepSlippage
        );
        if (returnedAssets < minReturn) {
            revert InsufficientAssetsReturned(
                returnedAssets,
                pendingWithdrawalAssets
            );
        }

        return _sweep(returnedAssets);
    }

    /**
     * @notice Bypass-slippage variant of `sweep`, sending the full asset balance to the buffer ark.
     * @dev Used when Securitize returns less than `pendingWithdrawalShares - sweepSlippage`.
     *      Restricted to the governor role.
     */
    function emergencySweep()
        external
        onlyGovernor
        nonReentrant
        returns (address[] memory sweptTokens, uint256[] memory sweptAmounts)
    {
        return _sweep(config.asset.balanceOf(address(this)));
    }

    /**
     * @notice Sets the sweep slippage. Restricted to the keeper role.
     */
    function setSweepSlippage(Percentage newSweepSlippage) external onlyKeeper {
        if (newSweepSlippage > MAX_SWEEP_SLIPPAGE) {
            revert InvalidSweepSlippage(newSweepSlippage, MAX_SWEEP_SLIPPAGE);
        }
        emit SweepSlippageUpdated(sweepSlippage, newSweepSlippage);
        sweepSlippage = newSweepSlippage;
    }

    /**
     * @notice Sets the deposit slippage. Restricted to the keeper role.
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

    /**
     * @notice Sets the on-ramp subscription-fee tolerance (separate from the NAV-divergence
     *         `depositSlippage`). Restricted to the governor role.
     */
    function setSubscriptionFeeTolerance(
        Percentage newTolerance
    ) external onlyGovernor {
        if (newTolerance > MAX_SUBSCRIPTION_FEE) {
            revert InvalidSubscriptionFeeTolerance(
                newTolerance,
                MAX_SUBSCRIPTION_FEE
            );
        }
        emit SubscriptionFeeToleranceUpdated(
            subscriptionFeeTolerance,
            newTolerance
        );
        subscriptionFeeTolerance = newTolerance;
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Subscribes to the fund by relaying a Securitize-signed `executePreApprovedTransaction`
     *         (an internal `subscribe`) supplied as keeper board data. Synchronous: DSToken is
     *         minted to this Ark in the same transaction.
     * @dev `_validateBoardData` (run by the `board` modifier before this) has already verified the
     *      payload relays a `subscribe` to the resolved on-ramp that mints to THIS Ark. Here we
     *      bind that payload to the boarded `amount`, relay it, and check the minted shares.
     * @param amount Base-asset amount to subscribe.
     * @param data ABI-encoded `(bytes signature, ISecuritizeOnRamp.ExecutePreApprovedTransaction)`.
     */
    function _board(
        uint256 amount,
        bytes calldata data
    ) internal override onlyNotFrozen {
        ISecuritizeOnRamp ramp = onRamp();

        (
            bytes memory signature,
            ISecuritizeOnRamp.ExecutePreApprovedTransaction memory txData
        ) = abi.decode(
                data,
                (bytes, ISecuritizeOnRamp.ExecutePreApprovedTransaction)
            );

        // The signed payload pulls THIS Ark's base asset, so the subscription amount it encodes
        // must equal the amount the keeper is boarding (the destination/recipient were checked in
        // `_validateBoardData`).
        (, uint256 liquidityAmount) = _decodeSubscribe(txData.data);
        if (liquidityAmount != amount) revert InvalidSubscriptionPayload();

        uint256 sharesBefore = shareToken.balanceOf(address(this));
        uint256 expectedShares = _assetsToShares(amount);
        // Allow for NAV-source divergence (depositSlippage) plus the on-ramp fee (feeTolerance).
        uint256 minShares = expectedShares
            .subtractPercentage(depositSlippage)
            .subtractPercentage(subscriptionFeeTolerance);

        config.asset.forceApprove(address(ramp), amount);
        ramp.executePreApprovedTransaction(signature, txData);

        uint256 received = shareToken.balanceOf(address(this)) - sharesBefore;
        if (received < minShares) {
            revert SharesNotArrived(expectedShares, received);
        }

        emit SubscribedViaOnRamp(amount, received);
    }

    /**
     * @dev Decodes the on-ramp's `subscribe(...)` calldata, returning the two fields the Ark binds:
     *      the investor wallet (must be this Ark, checked in `_validateBoardData`) and the liquidity
     *      amount (must equal the boarded amount, checked in `_board`). Reverts
     *      `InvalidSubscriptionPayload` unless `inner` is a `subscribe` call.
     */
    function _decodeSubscribe(
        bytes memory inner
    ) internal pure returns (address investorWallet, uint256 liquidityAmount) {
        if (inner.length < 4) revert InvalidSubscriptionPayload();
        bytes4 selector;
        assembly {
            selector := mload(add(inner, 0x20))
        }
        if (selector != SUBSCRIBE_SELECTOR) revert InvalidSubscriptionPayload();

        // Strip the 4-byte selector and decode the subscribe(...) arguments.
        bytes memory args = new bytes(inner.length - 4);
        for (uint256 i = 0; i < args.length; i++) {
            args[i] = inner[i + 4];
        }
        (, investorWallet, , , , , , liquidityAmount, , ) = abi.decode(
            args,
            (
                string,
                address,
                string,
                uint8[],
                uint256[],
                uint256[],
                uint256,
                uint256,
                uint256,
                bytes32
            )
        );
    }

    /**
     * @dev Shared sweep tail: clears `pendingWithdrawalShares` and forwards the asset balance to
     *      the FleetCommander's buffer ark (skipping if this ark *is* the buffer).
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
        pendingWithdrawalAssets = 0;

        address bufferArk = address(
            IFleetCommander(config.commander).bufferArk()
        );
        // First-position arg is msg.sender (the keeper), preserved for subgraph compatibility.
        emit Disembarked(msg.sender, address(asset), sweptAmounts[0]);

        if (sweptAmounts[0] > 0 && address(this) != bufferArk) {
            asset.forceApprove(bufferArk, sweptAmounts[0]);
            IArk(bufferArk).board(sweptAmounts[0], bytes(""));
        }

        emit ArkSwept(sweptTokens, sweptAmounts);
    }

    /**
     * @dev Disabled for nonzero amounts: this Ark exits only via the async
     *      `requestWithdrawal`/`sweep` cycle. A synchronous `disembark`/`move` would otherwise pull
     *      returned USDC out while `pendingWithdrawalShares` still counts it (double-counting +
     *      bricked sweep). `disembark(0, ...)` stays a no-op.
     */
    function _disembark(
        uint256 amount,
        bytes calldata
    ) internal view override onlyNotFrozen {
        if (amount > 0) revert DisembarkDisabled();
    }

    /**
     * @dev Always 0: synchronous withdrawal is not supported.
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
     * @dev No-op: no rewards generated by this Ark.
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
     * @dev `boardData` must be the Securitize-signed on-ramp subscription payload. Validated here
     *      (amount-independent); `_board` binds it to the boarded amount and relays it.
     */
    function _validateBoardData(bytes calldata data) internal override {
        _validateSubscriptionData(data);
    }

    /**
     * @dev Reverts unless `data` ABI-decodes to `(bytes signature, ExecutePreApprovedTransaction)`
     *      whose call relays a `subscribe(...)` to the resolved on-ramp that mints to THIS Ark. The
     *      subscription amount is bound to the boarded amount in `_board` (`amount` is not available
     *      to this hook).
     * @param data Keeper-supplied `boardData`.
     */
    function _validateSubscriptionData(bytes calldata data) internal view {
        ISecuritizeOnRamp ramp = onRamp();
        if (address(ramp) == address(0)) revert OnRampNotConfigured();
        address liquidityToken = ramp.liquidityToken();
        if (liquidityToken != address(config.asset)) {
            revert OnRampAssetMismatch(address(config.asset), liquidityToken);
        }

        (, ISecuritizeOnRamp.ExecutePreApprovedTransaction memory txData) = abi
            .decode(
                data,
                (bytes, ISecuritizeOnRamp.ExecutePreApprovedTransaction)
            );
        if (txData.destination != address(ramp)) {
            revert InvalidSubscriptionPayload();
        }
        (address investorWallet, ) = _decodeSubscribe(txData.data);
        if (investorWallet != address(this)) {
            revert InvalidSubscriptionPayload();
        }
    }

    /**
     * @dev No-op: this ark accepts no disembarkData payload.
     */
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
        return assetPerSharePrice.quote(assetAmount);
    }

    /**
     * @dev Fetches the NAV (1 share priced in the asset) as a `Price`, enforcing positivity and
     *      the heartbeat staleness bound.
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
                ONE_SHARE,
                answer,
                oracleDecimals,
                assetDecimals
            );
    }
}
