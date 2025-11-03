// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IPsm3 {
    function previewSwapExactIn(
        address assetIn,
        address assetOut,
        uint256 amountIn
    ) external view returns (uint256 amountOut);

    function previewSwapExactOut(
        address assetIn,
        address assetOut,
        uint256 amountOut
    ) external view returns (uint256 amountIn);

    function swapExactIn(
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address receiver,
        uint256 referralCode
    ) external returns (uint256 amountOut);

    function swapExactOut(
        address assetIn,
        address assetOut,
        uint256 amountOut,
        uint256 maxAmountIn,
        address receiver,
        uint256 referralCode
    ) external returns (uint256 amountIn);

    function pocket() external view returns (address);

    function usdc() external view returns (address);
}
