// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

contract TestMockReceiver {
    bool public lastCalled;
    string public lastMessage;

    receive() external payable {}

    function receiveCall(string memory message) external payable {
        lastCalled = true;
        lastMessage = message;
    }
}
