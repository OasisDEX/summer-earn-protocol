// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICrossChainAssetReceiver} from "../../src/interfaces/ICrossChainAssetReceiver.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";

contract MockFleetProxy is ICrossChainAssetReceiver {
    address public immutable ASSET;
    bool public receivedAssets;
    address public lastAsset;
    uint256 public lastAmount;
    bytes public lastMessage;
    uint16 public lastSourceChainId;
    bool public shouldRevert;

    constructor(address _asset) {
        ASSET = _asset;
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function receiveMessageWithAssets(
        BridgeTypes.DeliveredTransferParams calldata params
    ) external override {
        if (shouldRevert) {
            revert("MockFleetProxy: forced revert");
        }

        receivedAssets = true;
        lastAsset = params.asset;
        lastAmount = params.amount;
        lastMessage = params.message;
        lastSourceChainId = params.sourceChainId;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external pure override returns (bool) {
        return
            interfaceId == type(ICrossChainAssetReceiver).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    function testSkipper() public {}
}
