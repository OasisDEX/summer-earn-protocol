// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {LayerZeroAdapter} from "../../src/adapters/LayerZeroAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";

/**
 * @title LayerZeroAdapterTestHelper
 * @notice Helper contract that exposes internal functions of LayerZeroAdapter for testing
 */
contract LayerZeroAdapterTestHelper is LayerZeroAdapter {
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
     * @notice Exposes the internal _updateTransferStatus function for testing
     */
    function updateTransferStatus(
        bytes32 transferId,
        BridgeTypes.TransferStatus status
    ) external {
        _updateTransferStatus(transferId, status);
    }

    /**
     * @notice Exposes the internal _getLayerZeroEid function for testing
     */
    function getLayerZeroEid(uint16 chainId) external view returns (uint32) {
        return _getLayerZeroEid(chainId);
    }

    /**
     * @notice Alias for backwards compatibility with tests
     * @dev To maintain compatibility with existing tests that expect _getLayerZeroChainId
     */
    function getLayerZeroChainId(
        uint16 chainId
    ) external view returns (uint32) {
        return _getLayerZeroEid(chainId);
    }

    /**
     * @notice Implements a test version of lzReceive functionality
     */
    function lzReceiveTest(
        uint32 srcEid,
        bytes memory srcAddress,
        bytes memory payload
    ) external {
        // Convert LayerZero EID to our chain ID format
        uint16 srcChainId = lzEidToChain[srcEid];
        require(srcChainId != 0, "UnsupportedChain");

        // Decode the payload to extract transfer information
        (
            bytes32 transferId,
            address asset,
            uint256 amount,
            address recipient
        ) = abi.decode(payload, (bytes32, address, uint256, address));

        // Store message hash to transfer ID mapping
        bytes32 guid = keccak256(
            abi.encodePacked(srcEid, srcAddress, block.timestamp)
        );
        lzMessageToTransferId[guid] = transferId;

        try
            IBridgeRouter(bridgeRouter).receiveAsset(
                transferId,
                asset,
                recipient,
                amount
            )
        {
            // Update transfer status to completed
            _updateTransferStatus(
                transferId,
                BridgeTypes.TransferStatus.COMPLETED
            );

            // Emit event for successful transfer receipt
            emit TransferReceived(transferId, asset, amount, recipient);
        } catch (bytes memory reason) {
            // Update transfer status to failed
            _updateTransferStatus(
                transferId,
                BridgeTypes.TransferStatus.FAILED
            );

            // Emit event for failed relay
            emit RelayFailed(transferId, reason);
        }
    }
}
