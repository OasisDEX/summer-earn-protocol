pragma solidity ^0.8.28;

interface ICrossChainStateReadReceiver {
    function receiveStateRead(
        bytes calldata resultData,
        address requestor,
        bytes32 requestId,
        uint16 sourceChainId
    ) external;

    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
