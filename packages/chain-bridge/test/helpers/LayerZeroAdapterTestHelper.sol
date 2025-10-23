// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {LayerZeroAdapter} from "../../src/adapters/LayerZeroAdapter.sol";
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
        address _initialOwner
    )
        LayerZeroAdapter(
            _endpoint,
            _crossChainRegistry,
            _accessManager,
            _supportedChains,
            _lzEids,
            _initialOwner
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

    /**
     * @notice Test function for lzCompose
     * @param _from The OApp address that sent the compose message
     * @param _guid Global unique identifier for tracking the packet
     * @param _message OFT-encoded compose message
     * @param _caller Address of the caller
     * @param _extraData Additional data provided by the caller
     */
    function lzComposeTest(
        address _from,
        bytes32 _guid,
        bytes calldata _message,
        address _caller,
        bytes calldata _extraData
    ) external payable {
        this.lzCompose(_from, _guid, _message, _caller, _extraData);
    }

    /**
     * @notice Helper to set OFT mapping for testing
     * @param token Token address
     * @param oft OFT contract address
     */
    function setOftForTokenTest(address token, address oft) external {
        oftForToken[token] = oft;
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
