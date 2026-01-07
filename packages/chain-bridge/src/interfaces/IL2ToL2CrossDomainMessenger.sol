// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/// @title IL2ToL2CrossDomainMessenger
/// @notice Interface for OP Stack L2ToL2CrossDomainMessenger
/// @dev Used for cross-chain messaging between OP Stack chains
interface IL2ToL2CrossDomainMessenger {
    /// @notice Send a message to another chain
    /// @param _chainId Destination chain ID
    /// @param _target Target contract on destination chain
    /// @param _message Message data to send
    /// @return msgHash_ The message hash for tracking
    function sendMessage(
        uint256 _chainId,
        address _target,
        bytes calldata _message
    ) external returns (bytes32 msgHash_);

    /// @notice Relay a message from another chain
    /// @param _message Message data to relay
    function relayMessage(bytes calldata _message) external;

    /// @notice Get the sender of the current cross-domain message
    /// @return sender The address that sent the cross-domain message
    function crossDomainMessageSender() external view returns (address sender);

    /// @notice Get the source chain ID of the current cross-domain message
    /// @return sourceChainId The chain ID where the message originated
    function crossDomainMessageSource()
        external
        view
        returns (uint256 sourceChainId);
}
