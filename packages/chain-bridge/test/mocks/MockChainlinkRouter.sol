// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract MockChainlinkRouter {
    mapping(address => uint256) public sentMessages;

    struct EVMTokenAmount {
        address token;
        uint256 amount;
    }

    struct EVM2AnyMessage {
        bytes receiver;
        bytes data;
        EVMTokenAmount[] tokenAmounts;
        address feeToken;
        bytes extraArgs;
    }

    function ccipSend(
        uint64 destinationChainSelector,
        EVM2AnyMessage calldata message
    ) external payable returns (bytes32) {
        sentMessages[msg.sender]++;
        return keccak256(abi.encode(destinationChainSelector, message));
    }

    function getFee(
        uint64 destinationChainSelector,
        EVM2AnyMessage calldata message
    ) external view returns (uint256) {
        return 0.01 ether;
    }

    // Function to simulate incoming message for testing
    function receiveMessage(
        address _targetContract,
        bytes32 messageId,
        bytes calldata data
    ) external {
        // Call the target contract's ccipReceive function
        (bool success, ) = _targetContract.call(
            abi.encodeWithSignature(
                "ccipReceive(bytes32,bytes)",
                messageId,
                data
            )
        );
        require(success, "Failed to deliver message");
    }
}
