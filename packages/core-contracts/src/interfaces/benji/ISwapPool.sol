// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title ISwapPool
 * @notice Minimal interface for the Franklin Templeton `SwapPool` used by `BenjiArk`.
 * @dev The SwapPool swaps a registered/authorized token pair at a fixed 1:1 rate with decimal
 *      normalization (e.g. a 6-decimal stable leg <-> 18-decimal iBENJI). Neither `swap` overload
 *      returns the received amount, so callers MUST measure the `toToken` balance delta to learn how
 *      much was delivered. `swap` pulls `fromToken` from `msg.sender` via `transferFrom`, so the
 *      caller must approve the pool first. Only the subset of functions actually consumed by the Ark
 *      is declared here.
 */
interface ISwapPool {
    /**
     * @notice Swap `amount` of `fromToken` for the 1:1 decimal-normalized amount of `toToken`,
     *         delivering the output to `msg.sender`.
     * @param fromToken The token being sold (pulled from `msg.sender`)
     * @param toToken The token being bought (sent to `msg.sender`)
     * @param amount The amount of `fromToken` to swap, in `fromToken` decimals
     */
    function swap(address fromToken, address toToken, uint256 amount) external;

    /**
     * @notice Swap and deliver the output to an explicit `destination`.
     * @param fromToken The token being sold (pulled from `msg.sender`)
     * @param toToken The token being bought
     * @param amount The amount of `fromToken` to swap, in `fromToken` decimals
     * @param destination The recipient of `toToken` (defaults to `msg.sender` if zero)
     */
    function swap(
        address fromToken,
        address toToken,
        uint256 amount,
        address destination
    ) external;

    /**
     * @notice Returns the pool's available balance of `token`.
     * @param token The token to query
     * @return The pool-held balance, in `token` decimals
     */
    function getTokenBalance(address token) external view returns (uint256);

    /**
     * @notice Whether `trader` may swap the `tokenA`/`tokenB` pair (pair authorized and, if the pair
     *         enforces trader authorization, the trader is on the allow-list).
     */
    function isTraderAllowed(
        address trader,
        address tokenA,
        address tokenB
    ) external view returns (bool);

    /**
     * @notice Whether the `tokenA`/`tokenB` pair is authorized for swapping.
     */
    function isTokenPairAuthorized(
        address tokenA,
        address tokenB
    ) external view returns (bool);

    /**
     * @notice Whether the pool is currently paused (all swaps revert while paused).
     */
    function paused() external view returns (bool);
}
