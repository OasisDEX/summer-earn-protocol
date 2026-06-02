// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBenjiArk} from "../../interfaces/arks/IBenjiArk.sol";
import {IBenjiToken} from "../../interfaces/benji/IBenjiToken.sol";
import {ISwapPool} from "../../interfaces/benji/ISwapPool.sol";
import {IArk} from "../../interfaces/IArk.sol";
import {IArkSwapProvider} from "../../interfaces/IArkSwapProvider.sol";
import {ArkParams} from "../../types/ArkTypes.sol";
import {Ark} from "../Ark.sol";
import {ArkSwapProvider} from "../ArkSwapProvider.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {TokenLibrary} from "@summerfi/dutch-auction/lib/TokenLibrary.sol";
import {PERCENTAGE_FACTOR, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

/**
 * @title BenjiArk
 * @notice Ark for allocating into Franklin Templeton's iBENJI share token (the `MoneyMarketFund`
 *         ERC20, par $1) through the Franklin-Templeton-maintained on-chain `SwapPool`s. The
 *         SwapPools are the primary entry/exit: they swap the base asset (the "stable leg") and
 *         iBENJI at a fixed 1:1 rate with decimal normalization, so deposits and withdrawals are
 *         synchronous and atomic — unlike the off-chain custodial RWA Arks (WisdomTree /
 *         Securitize).
 *
 * @dev Pool selection model: Franklin Templeton operates multiple SwapPools for the same
 *      USDC/iBENJI pair. The curator whitelists eligible pools via `whitelistSwapPool`, and the
 *      keeper selects one per rebalance by passing `abi.encode(address pool)` as
 *      `boardData`/`disembarkData`. `requiresKeeperData` MUST therefore be true in `ArkParams`
 *      (enforced by the constructor), which also makes the public `withdrawableTotalAssets()`
 *      report 0 — exits flow through keeper-driven rebalances.
 *
 * Asset tracking model (1:1 par, decimal-normalized):
 *      totalAssets() = sharesToAssets(iBENJI balance) + idle base-asset balance
 *
 * Lifecycle:
 * 1. Deposit (`_board`): approve the keeper-selected SwapPool and swap the base asset -> iBENJI
 *    1:1; assert the received shares cover the 1:1 expectation minus `depositSlippage`.
 * 2. Withdraw (`_disembark`): swap iBENJI -> base asset 1:1 through the keeper-selected pool for
 *    the requested amount; the base `Ark.disembark` then forwards the asset to the FleetCommander.
 *    Synchronous.
 * 3. Escape (`withdrawUsingSwap`): if the SwapPools are paused/illiquid, the keeper exits iBENJI on
 *    a secondary market through a curator-whitelisted DEX router (the `SyrupArk` pattern), bounded
 *    by `slippage`, then boards the proceeds to the buffer ark.
 *
 * Because the SwapPool path is synchronous, this Ark has no async-withdrawal surface at all: it
 * extends `ArkSwapProvider` (Ark + the curator-whitelisted router-swap machinery: `_swap`,
 * `whitelistRouter`, `_applySlippage`, `setSlippage`, `_boardToBufferArk`) rather than
 * `ArkWithWithdrawalRequest`, so there are no inert `requestWithdrawal`/`claimWithdrawal` stubs.
 *
 * Integration notes (verified on Ethereum mainnet):
 *  - Base-asset leg is USDC directly (no hop): USDC (6 dec) and iBENJI (18 dec) are both registered
 *    and the pair is authorized on both live SwapPools. `whitelistSwapPool` enforces this via
 *    `isTokenPairAuthorized` when a pool is whitelisted. The pair enforces per-trader
 *    authorization, so this Ark must be authorized as a trader by Franklin Templeton on each pool
 *    before boarding through it (see `isArkOnboarded`).
 *  - iBENJI is a fixed-share ERC20 (18 dec) and is NOT rebasing: `balanceOf` changes only on
 *    mint/burn/transfer, and NAV is held at $1 par (the fund tracks `lastKnownPrice` off-chain).
 *    Combined with the SwapPools' fixed 1:1 rate, 1:1 decimal-normalized accounting is exact and no
 *    NAV oracle is required — contrast SecuritizeArk's rebasing DSToken + Chainlink NAV feed.
 *  - SwapPool redemption is synchronous: `swap` settles iBENJI -> USDC atomically in one tx and
 *    returns nothing. Withdrawals therefore flow through `disembark`/`_disembark` with the keeper
 *    supplying the pool; there is no queue to pre-stage and no claim step, hence no
 *    `IArkWithWithdrawalRequest` surface on this Ark.
 *  - iBENJI holder authorization (KYC/whitelist) is enforced by the token's own transfer policy and
 *    is NOT readable on-chain from the token (no public getter; its module registry is internal).
 *    This Ark reaches iBENJI only via the SwapPools, so the holder gate is enforced implicitly: if
 *    the Ark is not an authorized holder, a SwapPool's iBENJI delivery reverts inside the token
 *    and `_board` reverts. `isArkOnboarded(pool)` therefore checks the readable trader gate only;
 *    holder authorization must be granted off-chain by Franklin Templeton.
 *
 * The full board/disembark cycle is exercised against the production SwapPools and iBENJI in
 * `BenjiArk.fork.t.sol` by impersonating the SwapPool owner (trader authorization) and the iBENJI
 * AuthorizationModule admin (holder authorization).
 */
contract BenjiArk is IBenjiArk, ArkSwapProvider {
    using SafeERC20 for IERC20;
    using PercentageUtils for uint256;
    using TokenLibrary for uint256;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Default slippage (0.02%) applied to the whitelisted-router escape swaps.
    uint256 public constant DEFAULT_SWAP_SLIPPAGE = 2;

    /// @notice Maximum deposit slippage (0.5%) tolerated on the 1:1 SwapPool board.
    Percentage public constant MAX_DEPOSIT_SLIPPAGE =
        Percentage.wrap(PERCENTAGE_FACTOR / 2);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The iBENJI share token (`MoneyMarketFund`) this Ark holds.
    IBenjiToken public immutable shareToken;

    /// @notice Decimals of the configured base asset (the SwapPool stable leg, e.g. 6).
    uint8 public immutable assetDecimals;

    /// @notice Decimals of the iBENJI share token (e.g. 18).
    uint8 public immutable shareDecimals;

    /// @notice Tolerance applied to the 1:1 expected vs. actual iBENJI received during `_board`.
    Percentage public depositSlippage;

    /// @notice Franklin Templeton SwapPools approved by the curator for board/disembark. The
    ///         keeper selects one per rebalance via `boardData`/`disembarkData`.
    mapping(address swapPool => bool isWhitelisted) public whitelistedSwapPools;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Wires the Ark to iBENJI and sets the board slippage bound. SwapPools are not fixed
     *         at deployment: the curator whitelists them via `whitelistSwapPool` and the keeper
     *         selects one per rebalance.
     * @param _shareToken iBENJI share token (`MoneyMarketFund`).
     * @param _depositSlippage Initial board slippage cap; must be `<= MAX_DEPOSIT_SLIPPAGE` (0.5%).
     * @param _params Standard `ArkParams` (asset, commander, deposit caps, etc.).
     *                `requiresKeeperData` must be true — the keeper supplies the SwapPool address.
     */
    constructor(
        address _shareToken,
        Percentage _depositSlippage,
        ArkParams memory _params
    ) ArkSwapProvider(_params, DEFAULT_SWAP_SLIPPAGE) {
        if (_shareToken == address(0)) revert InvalidShareTokenAddress();
        if (!_params.requiresKeeperData) revert MustRequireKeeperData();
        if (_depositSlippage > MAX_DEPOSIT_SLIPPAGE) {
            revert InvalidDepositSlippage(
                _depositSlippage,
                MAX_DEPOSIT_SLIPPAGE
            );
        }

        shareToken = IBenjiToken(_shareToken);
        depositSlippage = _depositSlippage;
        assetDecimals = IERC20Metadata(_params.asset).decimals();
        shareDecimals = IERC20Metadata(_shareToken).decimals();
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArk
     * @notice totalAssets = value of held iBENJI (1:1 par) + idle base-asset balance.
     */
    function totalAssets()
        public
        view
        override(Ark, IArk)
        returns (uint256 assets)
    {
        assets =
            _sharesToAssets(shareToken.balanceOf(address(this))) +
            _balanceOfAsset();
    }

    /**
     * @inheritdoc IBenjiArk
     */
    function sharesToAssets(uint256 shares) external view returns (uint256) {
        return _sharesToAssets(shares);
    }

    /**
     * @inheritdoc IBenjiArk
     * @dev This reflects the given pool's trader gate only. iBENJI also requires the Ark to be an
     *      authorized *holder*, which is enforced by the token and is not readable here; if missing,
     *      it surfaces as a revert when the SwapPool delivers iBENJI during `_board`.
     */
    function isArkOnboarded(address swapPool) external view returns (bool) {
        return
            ISwapPool(swapPool).isTraderAllowed(
                address(this),
                address(config.asset),
                address(shareToken)
            );
    }

    /*//////////////////////////////////////////////////////////////
                       KEEPER & CURATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IBenjiArk
     * @dev Restricted to the curator. When whitelisting, the asset/iBENJI pair must already be
     *      authorized on the pool (reverts with `PairNotAuthorized` otherwise) so the keeper cannot
     *      be handed a pool that strands the asset on the first board.
     */
    function whitelistSwapPool(
        address swapPool,
        bool isWhitelisted
    ) external onlyCurator(config.commander) {
        if (swapPool == address(0)) revert InvalidSwapPoolAddress();
        if (
            isWhitelisted &&
            !ISwapPool(swapPool).isTokenPairAuthorized(
                address(config.asset),
                address(shareToken)
            )
        ) {
            revert PairNotAuthorized();
        }
        whitelistedSwapPools[swapPool] = isWhitelisted;
        emit SwapPoolWhitelisted(swapPool, isWhitelisted);
    }

    /**
     * @inheritdoc IArkSwapProvider
     * @notice Secondary-market escape: sells iBENJI for the base asset through a curator-whitelisted
     *         DEX router when the SwapPool path is unavailable (paused/illiquid), then boards the
     *         proceeds to the FleetCommander buffer ark.
     * @dev `amountOutMin` is derived from the 1:1 fair value (`amount`) minus `slippage`, never from
     *      keeper input. Mirrors `SyrupArk.withdrawUsingSwap`.
     * @param amount Base-asset amount to free (drives both the share input and the min-out floor).
     * @param data ABI-encoded `SwapData` (whitelisted router + router calldata).
     */
    function withdrawUsingSwap(
        uint256 amount,
        bytes calldata data
    ) external override onlyKeeper nonReentrant {
        uint256 shares = _assetsToShares(amount);
        SwapData memory swapData = abi.decode(data, (SwapData));
        uint256 assetBought = _swap(
            address(shareToken),
            address(config.asset),
            swapData.router,
            shares,
            _applySlippage(amount),
            swapData.swapCalldata
        );
        // Emit the amount actually realized (>= amount minus `slippage`), not the requested
        // amount, so accounting reflects secondary-market slippage.
        emit Disembarked(msg.sender, address(config.asset), assetBought);
        _boardToBufferArk(assetBought);
    }

    /**
     * @inheritdoc IBenjiArk
     * @dev Restricted to the curator (consistent with `setSlippage` on `ArkSwapProvider` — slippage
     *      bounds are risk parameters, not keeper operations). Reverts with
     *      `InvalidDepositSlippage` if the supplied value exceeds `MAX_DEPOSIT_SLIPPAGE`.
     * @param newDepositSlippage The new deposit slippage
     */
    function setDepositSlippage(
        Percentage newDepositSlippage
    ) external onlyCurator(config.commander) {
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
     * @notice Swaps the boarded base asset into iBENJI 1:1 via the keeper-selected SwapPool.
     * @dev The pool is decoded from `data` and was validated against the curator whitelist by
     *      `_validateBoardData`. Fail fast if this Ark is not an authorized trader on it (the swap
     *      would otherwise revert and strand the asset). Validates the received iBENJI against the
     *      1:1 expectation minus `depositSlippage`.
     */
    function _board(uint256 amount, bytes calldata data) internal override {
        ISwapPool swapPool = ISwapPool(abi.decode(data, (address)));
        if (
            !swapPool.isTraderAllowed(
                address(this),
                address(config.asset),
                address(shareToken)
            )
        ) {
            revert ArkNotAuthorized();
        }

        uint256 sharesBefore = shareToken.balanceOf(address(this));
        config.asset.forceApprove(address(swapPool), amount);
        swapPool.swap(address(config.asset), address(shareToken), amount);
        uint256 receivedShares = shareToken.balanceOf(address(this)) -
            sharesBefore;

        uint256 expectedShares = _assetsToShares(amount);
        if (
            receivedShares < expectedShares.subtractPercentage(depositSlippage)
        ) {
            revert SharesNotReceived(expectedShares, receivedShares);
        }
    }

    /**
     * @notice Swaps iBENJI back into the base asset 1:1 via the keeper-selected SwapPool so the
     *         base `disembark` can forward exactly `amount` to the FleetCommander.
     * @dev The pool is decoded from `data` and was validated against the curator whitelist by
     *      `_validateDisembarkData`. Uses any idle base asset first and only swaps the shortfall.
     *      Swapping the full `amount` unconditionally would let a 1-wei base-asset donation inflate
     *      `totalAssets()` above the iBENJI position and make a full exit try to swap more shares
     *      than the Ark holds, reverting every `disembark(totalAssets())` until the dust is swept.
     */
    function _disembark(uint256 amount, bytes calldata data) internal override {
        uint256 idleAssets = _balanceOfAsset();
        if (idleAssets >= amount) return;

        ISwapPool swapPool = ISwapPool(abi.decode(data, (address)));
        uint256 shortfall = amount - idleAssets;
        uint256 shares = _assetsToShares(shortfall);
        IERC20(address(shareToken)).forceApprove(address(swapPool), shares);
        swapPool.swap(address(shareToken), address(config.asset), shares);
        uint256 receivedAssets = _balanceOfAsset() - idleAssets;
        if (receivedAssets < shortfall) {
            revert InsufficientAssetsReceived(shortfall, receivedAssets);
        }
    }

    /**
     * @dev Only the idle base-asset balance is withdrawable without keeper input: redeeming the
     *      iBENJI position requires the keeper to select a SwapPool via `disembarkData`. Note the
     *      public `withdrawableTotalAssets()` already reports 0 because `requiresKeeperData` is
     *      true; this conservative value covers any internal callers.
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256)
    {
        return _balanceOfAsset();
    }

    /**
     * @dev No-op: iBENJI accrues at par (no claimable rewards token for this Ark).
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

    /// @dev `boardData` must be a curator-whitelisted SwapPool address.
    function _validateBoardData(bytes calldata data) internal override {
        _validateSwapPoolData(data);
    }

    /// @dev `disembarkData` must be a curator-whitelisted SwapPool address.
    function _validateDisembarkData(bytes calldata data) internal override {
        _validateSwapPoolData(data);
    }

    /// @dev Reverts unless `data` is exactly one ABI-encoded address of a curator-whitelisted
    ///      SwapPool.
    /// @param data Keeper-supplied `boardData`/`disembarkData`.
    function _validateSwapPoolData(bytes calldata data) internal view {
        if (data.length != 32) revert InvalidSwapPoolData();
        address swapPool = abi.decode(data, (address));
        if (!whitelistedSwapPools[swapPool]) {
            revert SwapPoolNotWhitelisted(swapPool);
        }
    }

    /*//////////////////////////////////////////////////////////////
                          NORMALIZATION HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Converts an iBENJI share amount to the base-asset amount at 1:1 par by rescaling
     *      decimals via `TokenLibrary.convertDecimals` (truncates toward zero when downscaling),
     *      mirroring the SwapPools' own decimal normalization. The 1:1 basis is valid because
     *      iBENJI is a non-rebasing fixed-share token held at $1 par and the SwapPools swap at a
     *      fixed 1:1 rate; if iBENJI ever moves off par this must become NAV-based.
     */
    function _sharesToAssets(uint256 shares) internal view returns (uint256) {
        return shares.convertDecimals(shareDecimals, assetDecimals);
    }

    /**
     * @dev Converts a base-asset amount to the iBENJI share amount at 1:1 par by rescaling
     *      decimals. See `_sharesToAssets` for the validity of the 1:1 basis.
     */
    function _assetsToShares(
        uint256 assetAmount
    ) internal view returns (uint256) {
        return assetAmount.convertDecimals(assetDecimals, shareDecimals);
    }
}
