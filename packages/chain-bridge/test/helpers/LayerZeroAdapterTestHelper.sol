// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {LayerZeroAdapter} from "../../src/adapters/LayerZeroAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";

/**
 * @title LayerZeroAdapterTestHelper
 * @notice Helper contract for testing LayerZeroAdapter
 * @dev Exposes internal functions for testing purposes
 */
contract LayerZeroAdapterTestHelper is LayerZeroAdapter {
    /**
     * @notice Constructor for LayerZeroAdapterTestHelper
     * @param _endpoint Address of the LayerZero endpoint
     * @param _crossChainRegistry Address of the CrossChainRegistry contract
     * @param _accessManager Address of the AccessManager contract
     * @param _supportedChains Array of supported chain IDs
     * @param _lzEids Array of corresponding LayerZero endpoint IDs
     * @param _initialOwner Address of the owner
     */
    constructor(
        address _endpoint,
        address _crossChainRegistry,
        address _accessManager,
        uint16[] memory _supportedChains,
        uint32[] memory _lzEids,
        address _initialOwner,
        uint32 _readChannelThreshold
    )
        LayerZeroAdapter(
            _endpoint,
            _crossChainRegistry,
            _accessManager,
            _supportedChains,
            _lzEids,
            _initialOwner,
            _readChannelThreshold
        )
    {}

    /**
     * @notice Test function for lzReceive
     * @param origin Origin of the message
     * @param guid Guid of the message
     * @param payload Message payload
     * @param sender Sender of the message
     * @param extraData Extra data of the message
     */
    function lzReceiveTest(
        Origin calldata origin,
        bytes32 guid,
        bytes calldata payload,
        address sender,
        bytes calldata extraData
    ) external {
        _lzReceive(origin, guid, payload, sender, extraData);
    }

    function setLzMessageToOperationId(
        bytes32 guid,
        bytes32 operationId
    ) external {
        lzMessageToOperationId[guid] = operationId;
    }

    function setExpectedReadChainByGuid(
        bytes32 guid,
        uint16 expectedChainId
    ) external {
        expectedReadChainByGuid[guid] = expectedChainId;
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

    function testSkipper() public {}
}
