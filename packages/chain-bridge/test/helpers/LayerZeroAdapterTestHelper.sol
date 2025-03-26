// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {LayerZeroAdapter} from "../../src/adapters/LayerZeroAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
import {console} from "forge-std/console.sol";
/**
 * @title LayerZeroAdapterTestHelper
 * @notice Helper contract for testing LayerZeroAdapter
 * @dev Exposes internal functions for testing purposes
 */
contract LayerZeroAdapterTestHelper is LayerZeroAdapter {
    /**
     * @notice Constructor for LayerZeroAdapterTestHelper
     * @param _endpoint Address of the LayerZero endpoint
     * @param _bridgeRouter Address of the bridge router
     * @param _supportedChains Array of supported chain IDs
     * @param _lzEids Array of corresponding LayerZero endpoint IDs
     * @param _owner Address of the owner
     */
    constructor(
        address _endpoint,
        address _bridgeRouter,
        uint16[] memory _supportedChains,
        uint32[] memory _lzEids,
        address _owner
    )
        LayerZeroAdapter(
            _endpoint,
            _bridgeRouter,
            _supportedChains,
            _lzEids,
            _owner
        )
    {}

    /**
     * @notice Test function for lzReceive
     * @param origin Origin of the message
     * @param requestId Request ID of the message
     * @param payload Message payload
     * @param sender Sender of the message
     * @param extraData Extra data of the message
     */
    function lzReceiveTest(
        Origin calldata origin,
        bytes32 requestId,
        bytes calldata payload,
        address sender,
        bytes calldata extraData
    ) external {
        console.log("lzReceiveTest called");
        _lzReceive(origin, requestId, payload, sender, extraData);
    }

    /**
     * @notice Exposes the internal updateOperationStatus function for testing
     * @param operationId ID of the operation
     * @param status New status
     */
    function updateOperationStatus(
        bytes32 operationId,
        BridgeTypes.OperationStatus status
    ) external {
        _updateOperationStatus(operationId, status);
    }

    function updateReceiveStatus(
        bytes32 requestId,
        BridgeTypes.OperationStatus status
    ) external {
        _updateReceiveStatus(requestId, status);
    }

    /**
     * @notice Exposes the internal getLayerZeroChainId function for testing
     * @param chainId Chain ID
     * @return LayerZero EID
     */
    function getLayerZeroChainId(
        uint16 chainId
    ) external view returns (uint32) {
        return _getLayerZeroEid(chainId);
    }
}
