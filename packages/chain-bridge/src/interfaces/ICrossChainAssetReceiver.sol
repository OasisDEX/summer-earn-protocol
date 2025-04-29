pragma solidity ^0.8.28;

interface ICrossChainAssetReceiver {
    function receiveMessageWithAssets(
        address asset,
        uint256 amount,
        bytes calldata message
    ) external;

    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
