// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title EnsoRouterSwapper
 * @notice Abstract base contract for contracts that route token swaps through
 *         the Enso aggregator router.
 *
 * @dev Encapsulates the approve → call → reset-allowance pattern used to
 *      interact with Enso. Inheriting contracts call `_ensoSwap` which
 *      reverts on empty calldata or a failed router call.
 *
 *      The router allowance is always reset to zero after the call — whether
 *      the call succeeds, fails, or the router underspends the approval.
 */
abstract contract EnsoRouterSwapper {
    using SafeERC20 for IERC20;

    /// @notice The immutable Enso router address all swaps are routed through.
    address public immutable ENSO_ROUTER;

    /// @notice Reverts when the provided Enso router address is the zero address.
    error InvalidRouterAddress();
    /// @notice Reverts when `_ensoSwap` is called with empty calldata.
    error EmptySwapData();
    /// @notice Reverts when the low-level call to the Enso router returns false.
    error SwapFailed();

    /**
     * @param _ensoRouter Address of the deployed Enso router. Must be non-zero.
     */
    constructor(address _ensoRouter) {
        if (_ensoRouter == address(0)) revert InvalidRouterAddress();
        ENSO_ROUTER = _ensoRouter;
    }

    /**
     * @notice Executes a swap through the Enso router.
     * @dev Reverts with `EmptySwapData` when `data` is empty. Approves
     *      `ENSO_ROUTER` for `amountIn` of `tokenIn`, calls the router, then
     *      unconditionally resets the allowance to zero — even when the router
     *      underspends the approval. Reverts with `SwapFailed` when the
     *      low-level call returns false.
     * @param tokenIn  The ERC20 token (or ERC4626 share) to swap from.
     * @param amountIn The amount to approve and expect the router to consume.
     * @param data     Calldata forwarded verbatim to the Enso router.
     */
    function _ensoSwap(
        address tokenIn,
        uint256 amountIn,
        bytes calldata data
    ) internal {
        if (data.length == 0) revert EmptySwapData();
        IERC20(tokenIn).forceApprove(ENSO_ROUTER, amountIn);
        (bool success, ) = ENSO_ROUTER.call(data);
        IERC20(tokenIn).forceApprove(ENSO_ROUTER, 0);
        if (!success) revert SwapFailed();
    }
}
