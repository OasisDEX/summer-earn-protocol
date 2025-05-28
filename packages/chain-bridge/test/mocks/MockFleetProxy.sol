// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ICrossChainAssetReceiver} from "../../src/interfaces/ICrossChainAssetReceiver.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract MockFleetProxy is ICrossChainAssetReceiver {
    address public immutable asset;
    bool public receivedAssets;
    address public lastAsset;
    uint256 public lastAmount;
    bytes public lastMessage;
    uint16 public lastSourceChainId;
    bool public shouldRevert;

    constructor(address _asset) {
        asset = _asset;
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function receiveMessageWithAssets(
        address _asset,
        uint256 _amount,
        bytes calldata _message,
        uint16 _sourceChainId
    ) external override {
        if (shouldRevert) {
            revert("MockFleetProxy: forced revert");
        }

        receivedAssets = true;
        lastAsset = _asset;
        lastAmount = _amount;
        lastMessage = _message;
        lastSourceChainId = _sourceChainId;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external pure override returns (bool) {
        return
            interfaceId == type(ICrossChainAssetReceiver).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }
}
