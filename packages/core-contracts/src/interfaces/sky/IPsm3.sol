// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IPsm3
/// @notice Minimal interface for the Sky PSM3 swap module
interface IPsm3 {
    /// @notice Previews the output amount for an exact-input swap
    /// @param assetIn The asset being sold
    /// @param assetOut The asset being bought
    /// @param amountIn The exact input amount
    /// @return amountOut The expected output amount
    function previewSwapExactIn(
        address assetIn,
        address assetOut,
        uint256 amountIn
    ) external view returns (uint256 amountOut);

    /// @notice Previews the input amount required for an exact-output swap
    /// @param assetIn The asset being sold
    /// @param assetOut The asset being bought
    /// @param amountOut The exact output amount
    /// @return amountIn The required input amount
    function previewSwapExactOut(
        address assetIn,
        address assetOut,
        uint256 amountOut
    ) external view returns (uint256 amountIn);

    /// @notice Swaps an exact input amount for at least a minimum output
    /// @param assetIn The asset being sold
    /// @param assetOut The asset being bought
    /// @param amountIn The exact input amount
    /// @param minAmountOut The minimum acceptable output amount
    /// @param receiver The recipient of the output asset
    /// @param referralCode An optional referral code
    /// @return amountOut The output amount received
    function swapExactIn(
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address receiver,
        uint256 referralCode
    ) external returns (uint256 amountOut);

    /// @notice Swaps up to a maximum input for an exact output amount
    /// @param assetIn The asset being sold
    /// @param assetOut The asset being bought
    /// @param amountOut The exact output amount desired
    /// @param maxAmountIn The maximum acceptable input amount
    /// @param receiver The recipient of the output asset
    /// @param referralCode An optional referral code
    /// @return amountIn The input amount spent
    function swapExactOut(
        address assetIn,
        address assetOut,
        uint256 amountOut,
        uint256 maxAmountIn,
        address receiver,
        uint256 referralCode
    ) external returns (uint256 amountIn);

    /// @notice Returns the address of the pocket that holds the PSM's liquidity
    /// @return The pocket address
    function pocket() external view returns (address);

    /// @notice Returns the address of the USDC token used by the PSM
    /// @return The USDC token address
    function usdc() external view returns (address);
}
