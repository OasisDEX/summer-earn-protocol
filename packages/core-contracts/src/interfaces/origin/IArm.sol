// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IArm {
    function requestWithdrawal(uint256 amount) external;
    function swapExactTokensForTokens(
        address inToken,
        address outToken,
        uint256 amountIn,
        uint256 amountOutMin,
        address to
    ) external;
}
