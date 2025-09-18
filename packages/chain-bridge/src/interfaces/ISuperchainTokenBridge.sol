// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/// @title ISuperchainTokenBridge
/// @notice Minimal interface for OP Stack Superchain Token Bridge for ERC-7802 tokens
/// @dev Docs: https://docs.optimism.io/interop/superchain-erc20
interface ISuperchainTokenBridge {
    /// @notice Initiate a crosschain ERC20 transfer (burn on source, mint on destination)
    /// @param token ERC20 token address (must implement ERC-7802 crosschainBurn/crosschainMint)
    /// @param dstChainId Destination chain identifier (may be canonical or mapped)
    /// @param to Recipient on the destination chain (adapter peer)
    /// @param amount Amount to transfer
    function sendERC20(
        address token,
        uint256 dstChainId,
        address to,
        uint256 amount
    ) external;
}
