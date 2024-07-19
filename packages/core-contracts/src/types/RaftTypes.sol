// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/**
 * @notice Swap params used by Raft contract
 */
struct SwapData {
    address tokenIn;
    uint256 amountIn;
    uint256 amountOutMin;
    uint24 poolFee;
}