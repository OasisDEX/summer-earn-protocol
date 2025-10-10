// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/// @title ISuperchainTokenBridge
/// @notice Minimal interface for OP Stack Superchain Token Bridge for ERC-7802 tokens
/// @dev Docs: https://docs.optimism.io/interop/superchain-erc20
///
/// EXECUTION FLOW:
/// 1. sendERC20() burns tokens on source chain and initiates cross-chain message
/// 2. OP Stack autorelayer delivers message to destination chain
/// 3. Tokens are minted to the 'to' address on destination chain
/// 4. IMPORTANT: The autorelayer does NOT call any finalize/completion functions
///    - Manual keeper intervention required to complete the bridge operation
///    - The 'to' address (typically an adapter) must handle final delivery
interface ISuperchainTokenBridge {
    /// @notice Initiate a crosschain ERC20 transfer (burn on source, mint on destination)
    /// @param token ERC20 token address (must implement ERC-7802 crosschainBurn/crosschainMint)
    /// @param dstChainId Destination chain identifier (may be canonical or mapped)
    /// @param to Recipient on the destination chain (adapter peer)
    /// @param amount Amount to transfer
    /// @dev This function only initiates the transfer. Manual keeper execution required on destination.
    function sendERC20(
        address token,
        uint256 dstChainId,
        address to,
        uint256 amount
    ) external;
}
