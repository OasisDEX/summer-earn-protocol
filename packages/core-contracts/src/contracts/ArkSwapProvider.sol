// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IArk} from "../interfaces/IArk.sol";
import {IArkSwapProvider} from "../interfaces/IArkSwapProvider.sol";
import {IFleetCommander} from "../interfaces/IFleetCommander.sol";
import {ArkParams} from "../types/ArkTypes.sol";
import {Ark} from "./Ark.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title ArkSwapProvider
 * @author SummerFi
 *
 * @notice Abstract base for Arks that can exit positions through a curator-whitelisted
 *         DEX-aggregator router (`_swap`), bounded by a curator-configured `slippage`. Concrete
 *         Arks implement `withdrawUsingSwap` on top of `_swap` / `_applySlippage` and typically
 *         forward the proceeds to the FleetCommander's buffer ark via `_boardToBufferArk`.
 *
 * @dev Extracted from `ArkWithWithdrawalRequest` so the router-swap machinery can be reused by
 *      synchronous Arks (e.g. swap-based RWA Arks) that have no async-withdrawal surface.
 *      `ArkWithWithdrawalRequest` inherits this contract, so its subclasses are unaffected.
 */
abstract contract ArkSwapProvider is IArkSwapProvider, Ark {
    using SafeERC20 for IERC20;

    /// @notice Current slippage tolerance applied to `_swap`-bound exits, in basis points of
    ///         `SLIPPAGE_BASE`.
    uint256 public slippage;
    /// @notice Denominator for `slippage` (10_000 = 100%).
    uint256 public constant SLIPPAGE_BASE = 10000;
    /// @notice Hard cap on `slippage` (1_000 / 10_000 = 10%).
    uint256 public constant MAX_SLIPPAGE = 1000; // 10%
    /// @notice DEX-aggregator routers approved for `_swap`. Mutated by the curator via
    ///         `whitelistRouter`.
    mapping(address router => bool isWhitelisted) public whitelistedRouters;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Wires the ark with its standard `ArkParams` and the initial swap-slippage tolerance.
     * @param _params Standard ark configuration (asset, commander, deposit caps, etc.).
     * @param _slippage Initial `_swap` slippage in basis points of `SLIPPAGE_BASE`. Must be
     *                  `<= MAX_SLIPPAGE`.
     */
    constructor(ArkParams memory _params, uint256 _slippage) Ark(_params) {
        if (_slippage > MAX_SLIPPAGE) {
            revert SlippageTooHigh();
        }
        slippage = _slippage;
    }

    // ============================================================
    //                       EXTERNAL FUNCTIONS
    // ============================================================

    /// @inheritdoc IArkSwapProvider
    function whitelistRouter(
        address router,
        bool isWhitelisted
    ) external onlyCurator(config.commander) {
        whitelistedRouters[router] = isWhitelisted;
        emit RouterWhitelisted(router, isWhitelisted);
    }

    /// @inheritdoc IArkSwapProvider
    function setSlippage(
        uint256 _slippage
    ) external onlyCurator(config.commander) {
        if (_slippage > MAX_SLIPPAGE) {
            revert SlippageTooHigh();
        }
        slippage = _slippage;
        emit SlippageSet(_slippage);
    }

    // ============================================================
    //                       INTERNAL FUNCTIONS
    // ============================================================

    /**
     * @notice Subtracts `slippage` basis points from `amount`, used to derive a safe
     *         `amountOutMin` for `_swap`.
     * @param amount The fair-value amount the swap should return on the happy path
     * @return amountWithSlippage `amount * (SLIPPAGE_BASE - slippage) / SLIPPAGE_BASE`
     */
    function _applySlippage(
        uint256 amount
    ) internal view returns (uint256 amountWithSlippage) {
        amountWithSlippage =
            (amount * (SLIPPAGE_BASE - slippage)) /
            SLIPPAGE_BASE;
    }

    /**
     * @notice Executes a token swap through a whitelisted router.
     * @dev SECURITY: `amountOutMin` MUST be derived from a source the keeper cannot
     *      manipulate — typically the implementing vault's own share-to-asset conversion
     *      (e.g. convertToExitAssets(shares)).
     *
     *      Implementing contracts are responsible for computing `amountOutMin` before
     *      calling this function. The pattern should always be:
     *
     *          uint256 fairValue = vault.convertToAssets(sharesToSell); // or equivalent
     *          uint256 amountOutMin = _applySlippage(fairValue);
     *          _swap(..., amountOutMin, ...);
     *
     * @param sellToken  Token to sell (e.g. vault shares)
     * @param buyToken   Token to buy (must be config.asset for harvest flows)
     * @param router     Must be whitelisted via whitelistRouter()
     * @param amountIn   Amount of sellToken to sell
     * @param amountOutMin Minimum acceptable output — MUST NOT come from keeper input
     * @param swapCalldata Calldata forwarded to the router
     * @return amountOut Actual buy-token amount received (>= amountOutMin).
     */
    function _swap(
        address sellToken,
        address buyToken,
        address router,
        uint256 amountIn,
        uint256 amountOutMin,
        bytes memory swapCalldata
    ) internal returns (uint256 amountOut) {
        if (!whitelistedRouters[router]) {
            revert RouterNotWhitelisted();
        }
        IERC20(sellToken).forceApprove(router, amountIn);
        uint256 buyTokenBalanceBefore = IERC20(buyToken).balanceOf(
            address(this)
        );
        Address.functionCall(router, swapCalldata);
        uint256 buyTokenBalanceAfter = IERC20(buyToken).balanceOf(
            address(this)
        );
        amountOut = buyTokenBalanceAfter - buyTokenBalanceBefore;
        if (amountOut < amountOutMin) {
            revert ReceivedLessThanExpected();
        }
        emit Swapped(sellToken, router, amountIn, swapCalldata);
    }

    /// @dev Forwards `amount` of the configured asset to the FleetCommander's buffer ark. Used by
    ///      subclass swap-exit / sweep / claim flows after the underlying returns to this Ark.
    /// @param amount Asset amount to forward to the buffer ark.
    function _boardToBufferArk(uint256 amount) internal {
        address bufferArk = IFleetCommander(config.commander).bufferArk();
        IERC20(address(config.asset)).forceApprove(bufferArk, amount);
        IArk(bufferArk).board(amount, "");
    }
}
