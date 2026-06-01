// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IArk} from "../interfaces/IArk.sol";
import {IFleetCommander} from "../interfaces/IFleetCommander.sol";

import {IArkWithWithdrawalRequest} from "../interfaces/IArkWithWithdrawalRequest.sol";
import {ArkConfig, ArkParams} from "../types/ArkTypes.sol";
import {Ark} from "./Ark.sol";

import {IDistributor} from "../interfaces/merkl/IDistributor.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {Constants} from "@summerfi/constants/Constants.sol";

/**
 * @title ArkWithWithdrawalRequest
 * @author SummerFi
 *
 * @notice Abstract base for Arks whose withdrawal path is asynchronous: a `requestWithdrawal` step
 *         initiates the off-chain settlement, and a separate `sweep` (or `claimWithdrawal`) step
 *         brings the underlying asset back to this Ark and forwards it to the FleetCommander's
 *         buffer ark. Adds a whitelisted-router swap utility for exits that route through a DEX
 *         aggregator.
 *
 * @dev Concrete subclasses must still implement the abstract hooks defined on `Ark` (`_board`,
 *      `_disembark`, `_withdrawableTotalAssets`, `_harvest`, `_validateBoardData`,
 *      `_validateDisembarkData`) AND the async-withdrawal hooks declared on
 *      `IArkWithWithdrawalRequest` (`requestWithdrawal`, `claimWithdrawal`, `withdrawUsingSwap`,
 *      `isWithdrawalClaimRequired`, `withdrawalRequestId`, `assetsInWithdrawalQueue`). Slippage on
 *      the internal `_swap` helper is bounded by `MAX_SLIPPAGE` and configured by the curator.
 */
abstract contract ArkWithWithdrawalRequest is IArkWithWithdrawalRequest, Ark {
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

    /// @inheritdoc IArkWithWithdrawalRequest
    function sweep()
        public
        virtual
        onlyKeeper
        nonReentrant
        returns (address[] memory sweptTokens, uint256[] memory sweptAmounts)
    {
        IERC20 asset = config.asset;
        sweptTokens = new address[](1);
        sweptAmounts = new uint256[](1);

        sweptTokens[0] = address(asset);
        sweptAmounts[0] = asset.balanceOf(address(this));

        address bufferArk = address(
            IFleetCommander(config.commander).bufferArk()
        );
        // @dev First-position arg is `msg.sender` (the keeper) here, NOT the FleetCommander
        //      address that the `Disembarked` event's `commander` parameter nominally represents.
        //      Preserved as-is for subgraph compatibility with the original event signature.
        emit Disembarked(msg.sender, address(asset), sweptAmounts[0]);

        if (sweptAmounts[0] > 0 && address(this) != bufferArk) {
            asset.forceApprove(bufferArk, sweptAmounts[0]);
            IArk(bufferArk).board(sweptAmounts[0], bytes(""));
        }

        emit ArkSwept(sweptTokens, sweptAmounts);
    }

    /// @inheritdoc IArkWithWithdrawalRequest
    function whitelistRouter(
        address router,
        bool isWhitelisted
    ) external onlyCurator(config.commander) {
        whitelistedRouters[router] = isWhitelisted;
        emit RouterWhitelisted(router, isWhitelisted);
    }

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

    /// @inheritdoc IArkWithWithdrawalRequest
    function setSlippage(
        uint256 _slippage
    ) external onlyCurator(config.commander) {
        if (_slippage > MAX_SLIPPAGE) {
            revert SlippageTooHigh();
        }
        slippage = _slippage;
        emit SlippageSet(_slippage);
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
    ///      subclass sweep/claim flows after off-chain settlement returns the underlying.
    /// @param amount Asset amount to forward to the buffer ark.
    function _boardToBufferArk(uint256 amount) internal {
        address bufferArk = IFleetCommander(config.commander).bufferArk();
        IERC20(address(config.asset)).forceApprove(bufferArk, amount);
        IArk(bufferArk).board(amount, "");
    }
}
