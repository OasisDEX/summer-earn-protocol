// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IL2ToL2CrossDomainMessenger} from "../../src/interfaces/IL2ToL2CrossDomainMessenger.sol";

/// @title MockL2ToL2CrossDomainMessenger
/// @notice Mock implementation of IL2ToL2CrossDomainMessenger for testing
contract MockL2ToL2CrossDomainMessenger is IL2ToL2CrossDomainMessenger {
    address public _crossDomainMessageSender;
    uint256 public _crossDomainMessageSource;
    bytes32 public lastMessageHash;
    address public lastTarget;
    bytes public lastMessage;
    uint256 public lastChainId;

    /// @notice Set the cross domain message sender for testing
    function setCrossDomainMessageSender(address _sender) external {
        _crossDomainMessageSender = _sender;
    }

    /// @notice Set the cross domain message source for testing
    function setCrossDomainMessageSource(uint256 _source) external {
        _crossDomainMessageSource = _source;
    }

    /// @notice Mock sendMessage implementation
    function sendMessage(
        uint256 _chainId,
        address _target,
        bytes calldata _message
    ) external returns (bytes32 msgHash_) {
        lastChainId = _chainId;
        lastTarget = _target;
        lastMessage = _message;
        msgHash_ = keccak256(
            abi.encodePacked(_chainId, _target, _message, block.timestamp)
        );
        lastMessageHash = msgHash_;
        return msgHash_;
    }

    /// @notice Mock relayMessage implementation
    function relayMessage(bytes calldata _message) external {
        // In a real implementation, this would call the target contract
        // For testing, we'll just store the message
        lastMessage = _message;
    }

    /// @notice Get the sender of the current cross-domain message
    function crossDomainMessageSender() external view returns (address sender) {
        return _crossDomainMessageSender;
    }

    /// @notice Get the source chain ID of the current cross-domain message
    function crossDomainMessageSource()
        external
        view
        returns (uint256 sourceChainId)
    {
        return _crossDomainMessageSource;
    }
}
