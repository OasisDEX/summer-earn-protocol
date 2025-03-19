// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract MockLayerZeroEndpoint {
    mapping(address => uint256) public sentMessages;

    function send(
        uint16 _dstChainId,
        bytes memory _destination,
        bytes memory _payload,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes memory _adapterParams
    ) external payable {
        sentMessages[msg.sender]++;
    }

    function estimateFees(
        uint16 _dstChainId,
        address _userApplication,
        bytes memory _payload,
        bool _payInZRO,
        bytes memory _adapterParam
    ) external view returns (uint256 nativeFee, uint256 zroFee) {
        return (0.01 ether, 0);
    }

    // Function to simulate incoming message for testing
    function receiveMessage(
        address _targetContract,
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) external {
        // Call the target contract's lzReceive function
        (bool success, ) = _targetContract.call(
            abi.encodeWithSignature(
                "lzReceive(uint16,bytes,uint64,bytes)",
                _srcChainId,
                _srcAddress,
                _nonce,
                _payload
            )
        );
        require(success, "Failed to deliver message");
    }
}
