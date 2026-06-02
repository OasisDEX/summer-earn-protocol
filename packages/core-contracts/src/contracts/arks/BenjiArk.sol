// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../ArkSwapProvider.sol";
import {ISwapPool} from "../../interfaces/benji/ISwapPool.sol";
import {IBenjiToken} from "../../interfaces/benji/IBenjiToken.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {PERCENTAGE_FACTOR, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

/**
 * @title BenjiArk
 * @notice Ark for allocating into Franklin Templeton's iBENJI share token (the `MoneyMarketFund`
 *         ERC20, par $1) through the Franklin-Templeton-maintained on-chain `SwapPool`. The SwapPool
 *         is the primary entry/exit: it swaps the base asset (the "stable leg") and iBENJI at a fixed
 *         1:1 rate with decimal normalization, so deposits and withdrawals are synchronous and
 *         atomic — unlike the off-chain custodial RWA Arks (WisdomTree / Securitize).
 *
 * @dev Asset tracking model (1:1 par, decimal-normalized):
 *      totalAssets() = sharesToAssets(iBENJI balance) + idle base-asset balance
 *
 * Lifecycle:
 * 1. Deposit (`_board`): approve the SwapPool and swap the base asset -> iBENJI 1:1; assert the
 *    received shares cover the oracle-free 1:1 expectation minus `depositSlippage`.
 * 2. Withdraw (`_disembark`): swap iBENJI -> base asset 1:1 for exactly the requested amount; the
 *    base `Ark.disembark` then forwards the asset to the FleetCommander. Synchronous.
 * 3. Escape (`withdrawUsingSwap`): if the SwapPool is paused/illiquid, the keeper exits iBENJI on a
 *    secondary market through a curator-whitelisted DEX router (the `SyrupArk` pattern), bounded by
 *    `slippage`, then boards the proceeds to the buffer ark.
 *
 * Because the SwapPool path is synchronous, this Ark has no async-withdrawal surface at all: it
 * extends `ArkSwapProvider` (Ark + the curator-whitelisted router-swap machinery: `_swap`,
 * `whitelistRouter`, `_applySlippage`, `setSlippage`, `_boardToBufferArk`) rather than
 * `ArkWithWithdrawalRequest`, so there are no inert `requestWithdrawal`/`claimWithdrawal` stubs.
 *
 * Confirmed against mainnet (SwapPool 0x2e508F…5eC2f, iBENJI 0x90276e…b48c):
 *  - Base-asset leg is USDC directly (no hop): USDC (6 dec) and iBENJI (18 dec) are both registered
 *    and the pair is authorized on both live SwapPools. The constructor enforces this via
 *    `isTokenPairAuthorized`. The pair enforces per-trader authorization, so this Ark must be
 *    authorized as a trader by Franklin Templeton before boarding (see `isArkOnboarded`).
 *  - iBENJI is a fixed-share ERC20 (18 dec) and is NOT rebasing: `balanceOf` changes only on
 *    mint/burn/transfer, and NAV is held at $1 par (the fund tracks `lastKnownPrice` off-chain).
 *    Combined with the SwapPool's fixed 1:1 rate, 1:1 decimal-normalized accounting is exact and no
 *    NAV oracle is required — contrast SecuritizeArk's rebasing DSToken + Chainlink NAV feed.
 *
 *  - SwapPool redemption is synchronous: `swap` settles iBENJI -> USDC atomically in one tx and
 *    returns nothing. Withdrawals therefore flow through `disembark`/`_disembark`, and
 *    `withdrawableTotalAssets()` reports the full held value — there is no queue to pre-stage and
 *    no claim step, hence no `IArkWithWithdrawalRequest` surface on this Ark.
 *  - iBENJI holder authorization (KYC/whitelist) is enforced by the token's own transfer policy and
 *    is NOT readable on-chain from the token (no public getter; its module registry is internal).
 *    This Ark reaches iBENJI only via the SwapPool, so the holder gate is enforced implicitly: if
 *    the Ark is not an authorized holder, the SwapPool's iBENJI delivery reverts inside the token
 *    and `_board` reverts. `isArkOnboarded()` therefore checks the readable trader gate only;
 *    holder authorization must be granted off-chain by Franklin Templeton.
 *
 * The full board/disembark cycle is validated against the real SwapPool + iBENJI in
 * `BenjiArk.fork.t.sol` by impersonating the SwapPool owner (trader auth) and the iBENJI
 * AuthorizationModule admin (holder auth). Still out of scope for this branch's scaffold:
 * deployment-package wiring (ArkType enum, deploy script, Ignition module).
 */
contract BenjiArk is ArkSwapProvider {
    using SafeERC20 for IERC20;
    using PercentageUtils for uint256;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Default slippage (0.02%) applied to the whitelisted-router escape swaps.
    uint256 public constant DEFAULT_SWAP_SLIPPAGE = 2;

    /// @notice Maximum deposit slippage (0.5%) tolerated on the 1:1 SwapPool board.
    Percentage public constant MAX_DEPOSIT_SLIPPAGE =
        Percentage.wrap(PERCENTAGE_FACTOR / 2);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Reverts when the constructor is given a zero SwapPool address.
    error InvalidSwapPoolAddress();
    /// @notice Reverts when the constructor is given a zero iBENJI share-token address.
    error InvalidShareTokenAddress();
    /// @notice Reverts when the constructor or `setDepositSlippage` is given a value above
    ///         `MAX_DEPOSIT_SLIPPAGE`.
    /// @param newSlippage The supplied slippage
    /// @param maxSlippage The hard cap (`MAX_DEPOSIT_SLIPPAGE`)
    error InvalidDepositSlippage(
        Percentage newSlippage,
        Percentage maxSlippage
    );
    /// @notice Reverts in `_board` when this Ark is not an authorized SwapPool trader for the
    ///         asset/iBENJI pair (so the swap would revert and strand the asset).
    error ArkNotAuthorized();
    /// @notice Reverts in the constructor when the configured asset/iBENJI pair is not authorized on
    ///         the SwapPool (so the Ark could never board or disembark). Pair authorization is a
    ///         pool-wide setting independent of this Ark's per-trader authorization.
    error PairNotAuthorized();
    /// @notice Reverts in `_board` when the iBENJI received from the SwapPool is below the 1:1
    ///         expectation minus `depositSlippage`.
    /// @param expectedShares 1:1 decimal-normalized shares for the deposited amount
    /// @param receivedShares iBENJI balance delta actually delivered by the SwapPool
    error SharesNotReceived(uint256 expectedShares, uint256 receivedShares);
    /// @notice Reverts in `_disembark` when the base asset received from the SwapPool is below the
    ///         requested amount (the 1:1 redemption underdelivered).
    /// @param requestedAssets The asset amount the keeper asked to free
    /// @param receivedAssets The base-asset balance delta delivered by the SwapPool
    error InsufficientAssetsReceived(
        uint256 requestedAssets,
        uint256 receivedAssets
    );

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted by `setDepositSlippage` after the cap is updated.
    /// @param oldDepositSlippage The previous `depositSlippage`
    /// @param newDepositSlippage The newly configured `depositSlippage`
    event DepositSlippageUpdated(
        Percentage oldDepositSlippage,
        Percentage newDepositSlippage
    );

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The Franklin Templeton SwapPool used for 1:1 base-asset <-> iBENJI swaps.
    ISwapPool public immutable swapPool;

    /// @notice The iBENJI share token (`MoneyMarketFund`) this Ark holds.
    IBenjiToken public immutable shareToken;

    /// @notice Decimals of the configured base asset (the SwapPool stable leg, e.g. 6).
    uint8 public immutable assetDecimals;

    /// @notice Decimals of the iBENJI share token (e.g. 18).
    uint8 public immutable shareDecimals;

    /// @notice Tolerance applied to the 1:1 expected vs. actual iBENJI received during `_board`.
    Percentage public depositSlippage;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Wires the Ark to the SwapPool and iBENJI, and sets the board slippage bound.
     * @param _swapPool Franklin Templeton SwapPool (1:1 swap facility).
     * @param _shareToken iBENJI share token (`MoneyMarketFund`).
     * @param _depositSlippage Initial board slippage cap; must be `<= MAX_DEPOSIT_SLIPPAGE` (0.5%).
     * @param _params Standard `ArkParams` (asset, commander, deposit caps, etc.).
     */
    constructor(
        address _swapPool,
        address _shareToken,
        Percentage _depositSlippage,
        ArkParams memory _params
    ) ArkSwapProvider(_params, DEFAULT_SWAP_SLIPPAGE) {
        if (_swapPool == address(0)) revert InvalidSwapPoolAddress();
        if (_shareToken == address(0)) revert InvalidShareTokenAddress();
        if (_depositSlippage > MAX_DEPOSIT_SLIPPAGE) {
            revert InvalidDepositSlippage(
                _depositSlippage,
                MAX_DEPOSIT_SLIPPAGE
            );
        }

        swapPool = ISwapPool(_swapPool);
        shareToken = IBenjiToken(_shareToken);
        depositSlippage = _depositSlippage;
        assetDecimals = IERC20Metadata(_params.asset).decimals();
        shareDecimals = IERC20Metadata(_shareToken).decimals();

        // The asset/iBENJI pair must be authorized on the SwapPool for this Ark to ever board or
        // disembark; fail at deployment rather than stranding funds at the first keeper action.
        if (
            !ISwapPool(_swapPool).isTokenPairAuthorized(
                _params.asset,
                _shareToken
            )
        ) {
            revert PairNotAuthorized();
        }
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
     * @notice Converts an iBENJI share amount to the equivalent base-asset amount at 1:1 par.
     * @param shares Amount in `shareDecimals`
     * @return assets Equivalent amount in `assetDecimals`
     */
    function sharesToAssets(uint256 shares) external view returns (uint256) {
        return _sharesToAssets(shares);
    }

    /**
     * @notice Whether this Ark is an authorized SwapPool trader for the asset/iBENJI pair and may
     *         therefore swap. Trader authorization is granted off-chain by Franklin Templeton.
     * @dev This reflects the SwapPool trader gate only. iBENJI also requires the Ark to be an
     *      authorized *holder*, which is enforced by the token and is not readable here; if missing,
     *      it surfaces as a revert when the SwapPool delivers iBENJI during `_board`.
     */
    function isArkOnboarded() external view returns (bool) {
        return
            swapPool.isTraderAllowed(
                address(this),
                address(config.asset),
                address(shareToken)
            );
    }

    /*//////////////////////////////////////////////////////////////
                            KEEPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
        emit Disembarked(msg.sender, address(config.asset), amount);
        _boardToBufferArk(assetBought);
    }

    /**
     * @notice Sets the board (deposit) slippage tolerance.
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
     * @notice Swaps the boarded base asset into iBENJI 1:1 via the SwapPool.
     * @dev Fail fast if this Ark is not an authorized trader (the swap would otherwise revert and
     *      strand the asset). Validates the received iBENJI against the 1:1 expectation minus
     *      `depositSlippage`.
     */
    function _board(uint256 amount, bytes calldata) internal override {
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
     * @notice Swaps iBENJI back into the base asset 1:1 via the SwapPool so the base `disembark`
     *         can forward exactly `amount` to the FleetCommander.
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        uint256 shares = _assetsToShares(amount);
        uint256 assetBefore = _balanceOfAsset();
        IERC20(address(shareToken)).forceApprove(address(swapPool), shares);
        swapPool.swap(address(shareToken), address(config.asset), shares);
        uint256 receivedAssets = _balanceOfAsset() - assetBefore;
        if (receivedAssets < amount) {
            revert InsufficientAssetsReceived(amount, receivedAssets);
        }
    }

    /**
     * @dev Synchronously withdrawable = idle base asset + value of held iBENJI (swappable now).
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256)
    {
        return
            _balanceOfAsset() +
            _sharesToAssets(shareToken.balanceOf(address(this)));
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

    /// @dev No-op: this ark accepts no boardData payload.
    function _validateBoardData(bytes calldata) internal override {}

    /// @dev No-op: this ark accepts no disembarkData payload.
    function _validateDisembarkData(bytes calldata) internal override {}

    /*//////////////////////////////////////////////////////////////
                          NORMALIZATION HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Converts an iBENJI share amount to the base-asset amount at 1:1 par by rescaling decimals.
     */
    function _sharesToAssets(uint256 shares) internal view returns (uint256) {
        return _normalizeDecimals(shares, shareDecimals, assetDecimals);
    }

    /**
     * @dev Converts a base-asset amount to the iBENJI share amount at 1:1 par by rescaling decimals.
     */
    function _assetsToShares(
        uint256 assetAmount
    ) internal view returns (uint256) {
        return _normalizeDecimals(assetAmount, assetDecimals, shareDecimals);
    }

    /**
     * @dev Rescales `amount` from `fromDecimals` to `toDecimals` (1:1 value), mirroring the
     *      SwapPool's own decimal normalization. Downscaling truncates toward zero. The 1:1 basis is
     *      valid because iBENJI is a non-rebasing fixed-share token held at $1 par and the SwapPool
     *      swaps at a fixed 1:1 rate; if iBENJI ever moves off par this must become NAV-based.
     */
    function _normalizeDecimals(
        uint256 amount,
        uint8 fromDecimals,
        uint8 toDecimals
    ) internal pure returns (uint256) {
        if (amount == 0) return 0;
        if (fromDecimals == toDecimals) return amount;
        if (toDecimals > fromDecimals) {
            return amount * (10 ** (toDecimals - fromDecimals));
        }
        return amount / (10 ** (fromDecimals - toDecimals));
    }
}
