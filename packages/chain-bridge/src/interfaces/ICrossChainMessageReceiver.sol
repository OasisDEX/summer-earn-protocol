pragma solidity 0.8.28;

import {BridgeTypes} from "../libraries/BridgeTypes.sol";

interface ICrossChainMessageReceiver {
    function receiveMessage(
        BridgeTypes.DeliveredMessageParams calldata params
    ) external;

    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
