// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IAggregationRouterV6
 * @notice Minimal interface for the 1inch AggregationRouterV6 swap entry point
 */
interface IAggregationRouterV6 {
    /**
     * @notice Parameters describing a swap to be executed by the router
     * @param srcToken The token being sold
     * @param dstToken The token being bought
     * @param srcReceiver The address that receives the source tokens (the executor)
     * @param dstReceiver The address that receives the destination tokens
     * @param amount The amount of source token to swap
     * @param minReturnAmount The minimum acceptable amount of destination token
     * @param flags Bit flags controlling swap behavior
     */
    struct SwapDescription {
        IERC20 srcToken;
        IERC20 dstToken;
        address payable srcReceiver;
        address payable dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
    }

    /**
     * @notice Performs a token swap using the provided executor and swap description
     * @param executor The address of the executor contract that performs the swap
     * @param desc The swap description parameters
     * @param permit Optional permit data used to approve the source token
     * @param data Encoded calldata forwarded to the executor
     * @return returnAmount The amount of destination token received
     * @return spentAmount The amount of source token actually spent
     */
    function swap(
        address executor,
        SwapDescription calldata desc,
        bytes calldata permit,
        bytes calldata data
    ) external payable returns (uint256 returnAmount, uint256 spentAmount);
}
