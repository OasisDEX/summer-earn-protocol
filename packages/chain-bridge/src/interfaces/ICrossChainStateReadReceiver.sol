pragma solidity ^0.8.28;

interface ICrossChainStateReadReceiver {
    function receiveStateRead(
        bytes calldata resultData,
        address requestor,
        uint16 sourceChainId,
        bytes32 requestId
    ) external;

    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
