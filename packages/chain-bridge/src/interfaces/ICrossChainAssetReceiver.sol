pragma solidity ^0.8.28;

interface ICrossChainAssetReceiver {
    function receiveMessageWithAssets(
        address asset,
        uint256 amount,
        bytes calldata message,
        uint16 sourceChainId
    ) external;

    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
