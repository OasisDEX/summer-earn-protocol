pragma solidity 0.8.28;

interface ICrossChainMessageReceiver {
    function receiveMessage(
        uint16 sourceChainId,
        bytes calldata message
    ) external;

    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
