// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";
import {IReceiveAdapter} from "../interfaces/IReceiveAdapter.sol";
import {ISendAdapter} from "../interfaces/ISendAdapter.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {OApp, Origin, MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {OAppOptionsType3, EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title LayerZeroAdapter
 * @notice Adapter for the LayerZero bridge protocol
 * @dev Implements IBridgeAdapter interface and connects to LayerZero's messaging service using OApp standard
 */
contract LayerZeroAdapter is Ownable, OApp, OAppOptionsType3, IBridgeAdapter {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The BridgeRouter that manages this adapter
    address public immutable bridgeRouter;

    /// @notice Mapping of transfer IDs to their current status
    mapping(bytes32 transferId => BridgeTypes.TransferStatus status)
        public transferStatuses;

    /// @notice Mapping of LayerZero message hashes to transfer IDs
    mapping(bytes32 lzMessageHash => bytes32 transferId)
        public lzMessageToTransferId;

    /// @notice Mapping of supported chains to their LayerZero chain IDs
    mapping(uint16 chainId => uint32 lzEid) public chainToLzEid;

    /// @notice Inverse mapping of LayerZero chain IDs to our chain IDs
    mapping(uint32 lzEid => uint16 chainId) public lzEidToChain;

    /// @notice Message type for a standard transfer
    uint16 public constant TRANSFER = 1;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a transfer is initiated through LayerZero
    event TransferInitiated(
        bytes32 indexed transferId,
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient
    );

    /// @notice Emitted when a transfer is received through LayerZero
    event TransferReceived(
        bytes32 indexed transferId,
        address asset,
        uint256 amount,
        address recipient
    );

    /// @notice Emitted when a relay fails
    event RelayFailed(bytes32 indexed transferId, bytes reason);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a call is made by an unauthorized address
    error Unauthorized();

    /// @notice Thrown when the LayerZero endpoint is invalid
    error InvalidEndpoint();

    /// @notice Thrown when provided parameters are invalid
    error InvalidParams();

    /// @notice Thrown when a transfer operation fails
    error TransferFailed();

    /// @notice Thrown when a chain is not supported
    error UnsupportedChain();

    /// @notice Thrown when an asset is not supported for a specific chain
    error UnsupportedAsset();

    /// @notice Thrown when a direct adapter call is made instead of using LayerZero messaging
    error UseLayerZeroMessaging();

    /// @notice Thrown when an unsupported message type is received
    error UnsupportedMessageType();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the LayerZeroAdapter
     * @param _endpoint Address of the LayerZero endpoint contract
     * @param _bridgeRouter Address of the BridgeRouter contract
     * @param _supportedChains Array of chain IDs supported by this adapter
     * @param _lzEids Array of corresponding LayerZero endpoint IDs
     * @param _owner Address of the contract owner
     */
    constructor(
        address _endpoint,
        address _bridgeRouter,
        uint16[] memory _supportedChains,
        uint32[] memory _lzEids,
        address _owner
    ) OApp(_endpoint, _owner) OAppOptionsType3() Ownable(_owner) {
        if (_bridgeRouter == address(0)) revert InvalidParams();
        if (_supportedChains.length != _lzEids.length) revert InvalidParams();

        bridgeRouter = _bridgeRouter;

        // Setup chain ID mappings
        for (uint i = 0; i < _supportedChains.length; i++) {
            chainToLzEid[_supportedChains[i]] = _lzEids[i];
            lzEidToChain[_lzEids[i]] = _supportedChains[i];
        }
    }

    /*//////////////////////////////////////////////////////////////
                            OAPP RECEIVER
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Receives messages from LayerZero
     * @param _origin Source chain information
     * @param _guid Global unique identifier for tracking the packet
     * @param _payload Message payload
     * @param // _executor Address of the executor
     * @param // _extraData Additional data provided by the executor
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _payload,
        address,
        bytes calldata
    ) internal override {
        // Convert LayerZero EID to our chain ID format
        uint16 srcChainId = lzEidToChain[_origin.srcEid];
        if (srcChainId == 0) revert UnsupportedChain();

        // First two bytes of payload indicate message type
        uint16 messageType;

        if (_payload.length >= 2) {
            messageType = uint16(bytes2(_payload[:2]));
            bytes calldata actualPayload = _payload[2:];

            if (messageType == 1) {
                // ASSET_TRANSFER
                _handleAssetTransferMessage(_guid, actualPayload);
            } else if (messageType == 2) {
                // STATE_READ
                _handleStateReadMessage(srcChainId, actualPayload);
            } else if (messageType == 3) {
                // GENERAL_MESSAGE
                _handleGeneralMessage(actualPayload);
            } else if (messageType == 4) {
                // STATE_READ_RESULT
                _handleStateReadResultMessage(actualPayload);
            } else {
                revert UnsupportedMessageType();
            }
        } else {
            // For backward compatibility, treat as asset transfer if no message type
            _handleAssetTransferMessage(_guid, _payload);
        }
    }

    /**
     * @dev Handles asset transfer messages
     */
    function _handleAssetTransferMessage(
        bytes32 _guid,
        bytes calldata _payload
    ) internal {
        // Decode the payload to extract transfer information
        (
            bytes32 transferId,
            address asset,
            uint256 amount,
            address recipient
        ) = abi.decode(_payload, (bytes32, address, uint256, address));

        // Update message hash to transfer ID mapping
        lzMessageToTransferId[_guid] = transferId;

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

    /**
     * @dev Handles state read messages
     * This is called on the destination chain to perform the read
     */
    function _handleStateReadMessage(
        uint16 srcChainId,
        bytes calldata _payload
    ) internal {
        // Decode the payload
        (
            bytes32 requestId,
            address targetContract,
            bytes4 selector,
            bytes memory params,
            address requestor
        ) = abi.decode(_payload, (bytes32, address, bytes4, bytes, address));

        // Actually perform the contract call to get the data
        (bool success, bytes memory result) = targetContract.call(
            abi.encodePacked(selector, params)
        );

        // Send the result back to the source chain
        if (success) {
            // Get LayerZero endpoint ID for the source chain
            uint32 lzDstEid = _getLayerZeroEid(srcChainId);

            // Format state read result message
            bytes memory resultPayload = abi.encodePacked(
                uint16(4), // STATE_READ_RESULT message type
                abi.encode(requestId, result, requestor)
            );

            // Default options (can be customized as needed)
            bytes memory options = abi.encodePacked(
                uint16(1), // version
                uint64(500000) // gas limit as uint64
            );

            // Send the result back
            _lzSend(
                lzDstEid,
                resultPayload,
                options,
                MessagingFee(address(this).balance, 0),
                payable(address(this)) // refund address
            );
        }
    }

    /**
     * @dev Handles general messages
     */
    function _handleGeneralMessage(bytes calldata _payload) internal {
        // Decode the message payload
        (bytes memory message, address recipient, bytes32 messageId) = abi
            .decode(_payload, (bytes, address, bytes32));

        // Update status
        _updateTransferStatus(messageId, BridgeTypes.TransferStatus.COMPLETED);

        // Forward the message to the bridge router
        try
            IBridgeRouter(bridgeRouter).deliverMessage(
                messageId,
                message,
                recipient
            )
        {} catch (bytes memory reason) {
            // Mark as failed on error
            _updateTransferStatus(messageId, BridgeTypes.TransferStatus.FAILED);
            emit RelayFailed(messageId, reason);
        }
    }

    /**
     * @dev Handles state read result messages
     * This is called on the source chain when receiving the result
     */
    function _handleStateReadResultMessage(bytes calldata _payload) internal {
        // Decode the state read result payload
        (bytes32 requestId, bytes memory resultData, ) = abi.decode(
            _payload,
            (bytes32, bytes, address)
        );

        // Update status
        _updateTransferStatus(requestId, BridgeTypes.TransferStatus.COMPLETED);

        // Forward the result to the bridge router to deliver to originator
        try
            IBridgeRouter(bridgeRouter).deliverReadResponse(
                requestId,
                resultData
            )
        {
            // Already updated status above
        } catch (bytes memory reason) {
            // Mark as failed if delivery fails
            _updateTransferStatus(requestId, BridgeTypes.TransferStatus.FAILED);
            emit RelayFailed(requestId, reason);
        }
    }

    /*//////////////////////////////////////////////////////////////
                          ADAPTER INTERFACE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISendAdapter
    function transferAsset(
        uint16 destinationChainId,
        address asset,
        address recipient,
        uint256 amount,
        uint256 gasLimit,
        bytes calldata adapterParams
    ) external payable returns (bytes32 transferId) {
        // Verify the caller is the BridgeRouter
        if (msg.sender != bridgeRouter) revert Unauthorized();

        // Convert destinationChainId to LayerZero EID
        uint32 lzDstEid = _getLayerZeroEid(destinationChainId);

        // Generate a unique transfer ID
        transferId = keccak256(
            abi.encodePacked(
                block.chainid,
                destinationChainId,
                asset,
                recipient,
                amount,
                block.timestamp
            )
        );

        // Update transfer status to pending
        _updateTransferStatus(transferId, BridgeTypes.TransferStatus.PENDING);

        // Encode payload for LayerZero
        bytes memory payload = abi.encode(transferId, asset, amount, recipient);

        // Handle token transfers
        if (asset != address(0)) {
            // Transfer ERC20 tokens from bridge router to this adapter
            if (
                !IERC20(asset).transferFrom(bridgeRouter, address(this), amount)
            ) {
                revert TransferFailed();
            }
        }

        // Prepare options with gas limit for lzReceive
        bytes memory options = abi.encodePacked(
            uint16(1), // version
            uint16(gasLimit) // gas limit
        );
        if (adapterParams.length > 0) {
            options = bytes.concat(options, adapterParams);
        }

        // Send message through OApp's _lzSend
        _lzSend(
            lzDstEid,
            payload,
            options,
            MessagingFee(msg.value, 0),
            payable(bridgeRouter) // refund address
        );

        // Emit event for transfer initiation
        emit TransferInitiated(
            transferId,
            destinationChainId,
            asset,
            amount,
            recipient
        );

        return transferId;
    }

    /// @inheritdoc IBridgeAdapter
    function estimateFee(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        uint256 gasLimit,
        bytes calldata adapterParams
    ) external view override returns (uint256 nativeFee, uint256 tokenFee) {
        // Convert destinationChainId to LayerZero EID
        uint32 lzDstEid = _getLayerZeroEid(destinationChainId);

        // Encode payload (same structure as in transferAsset)
        bytes memory payload = abi.encode(
            bytes32(0), // dummy transfer ID for estimation
            asset,
            amount,
            address(0) // dummy recipient address
        );

        // Prepare options with gas limit for lzReceive
        bytes memory options = abi.encodePacked(
            uint16(1), // version
            uint16(gasLimit) // gas limit
        );
        if (adapterParams.length > 0) {
            options = bytes.concat(options, adapterParams);
        }

        // Get the fee required for the LayerZero transaction
        MessagingFee memory fee = _quote(lzDstEid, payload, options, false);
        return (fee.nativeFee, fee.lzTokenFee);
    }

    /// @inheritdoc IBridgeAdapter
    function getTransferStatus(
        bytes32 transferId
    ) external view override returns (BridgeTypes.TransferStatus) {
        return transferStatuses[transferId];
    }

    /// @inheritdoc IBridgeAdapter
    function getSupportedChains()
        external
        view
        override
        returns (uint16[] memory)
    {
        // Count how many supported chains we have
        uint256 count = 0;
        for (uint16 i = 1; i < 65535; i++) {
            if (chainToLzEid[i] != 0) {
                count++;
            }
        }

        // Create an array of the exact size
        uint16[] memory supportedChains = new uint16[](count);

        // Fill the array with supported chains
        uint256 index = 0;
        for (uint16 i = 1; i < 65535; i++) {
            if (chainToLzEid[i] != 0) {
                supportedChains[index] = i;
                index++;
            }
        }

        return supportedChains;
    }

    /// @inheritdoc IBridgeAdapter
    function getSupportedAssets(
        uint16 chainId
    ) external view override returns (address[] memory) {
        // Check if the chain is supported first
        if (chainToLzEid[chainId] == 0) revert UnsupportedChain();

        // For this implementation, we'll assume all ERC20 tokens are supported
        // In a real implementation, you'd maintain a list of supported assets per chain
        address[] memory supportedAssets = new address[](1);
        supportedAssets[0] = address(0); // Native token

        return supportedAssets;
    }

    /// @inheritdoc ISendAdapter
    function readState(
        uint16 sourceChainId,
        address sourceContract,
        bytes4 selector,
        bytes calldata params,
        uint256 gasLimit,
        bytes calldata adapterParams
    ) external payable returns (bytes32) {
        // Only the BridgeRouter should call this function
        if (msg.sender != bridgeRouter) revert Unauthorized();

        // Generate a unique request ID
        bytes32 requestId = keccak256(
            abi.encode(
                sourceChainId,
                sourceContract,
                selector,
                params,
                block.timestamp,
                msg.sender
            )
        );

        // Get the LayerZero EID for source chain
        uint32 lzSrcEid = _getLayerZeroEid(sourceChainId);

        // Encode the read state request payload
        bytes memory payload = abi.encodePacked(
            uint16(2), // STATE_READ message type
            abi.encode(
                requestId,
                sourceContract,
                selector,
                params,
                msg.sender // requestor address
            )
        );

        // Prepare options with gas limit for lzReceive
        bytes memory options = abi.encodePacked(
            uint16(1), // version
            uint64(gasLimit) // gas limit as uint64
        );
        if (adapterParams.length > 0) {
            options = bytes.concat(options, adapterParams);
        }

        // Mark this request as pending
        _updateTransferStatus(requestId, BridgeTypes.TransferStatus.PENDING);

        // Send message through OApp's _lzSend
        _lzSend(
            lzSrcEid,
            payload,
            options,
            MessagingFee(msg.value, 0),
            payable(bridgeRouter) // refund address
        );

        return requestId;
    }

    /// @inheritdoc IBridgeAdapter
    function supportsChain(
        uint16 chainId
    ) external view override returns (bool) {
        return chainToLzEid[chainId] != 0;
    }

    /// @inheritdoc IBridgeAdapter
    function supportsAsset(
        uint16 chainId,
        address
    ) external view override returns (bool) {
        // First check if the chain is supported
        if (!this.supportsChain(chainId)) {
            return false;
        }

        // Currently all assets are supported for supported chains
        // This could be modified to check specific assets if needed
        return true;
    }

    /// @inheritdoc IBridgeAdapter
    function getAdapterType() external pure override returns (uint8) {
        // Return adapter type for LayerZero (e.g., 1 for LayerZero)
        return 1;
    }

    /// @inheritdoc ISendAdapter
    function requestAssetTransfer(
        address asset,
        uint256 amount,
        address sender,
        uint16 sourceChainId,
        bytes32 transferId,
        bytes calldata extraData
    ) external payable override {
        // Only the BridgeRouter should call this function
        if (msg.sender != bridgeRouter) revert Unauthorized();

        // Get the LayerZero EID for source chain
        uint32 lzSrcEid = _getLayerZeroEid(sourceChainId);

        // Create payload for the cross-chain message
        bytes memory payload = abi.encode(transferId, asset, amount, sender);

        // Default options with gas limit for lzReceive - use uint64 for larger gas values
        bytes memory options = abi.encodePacked(
            uint16(1), // version
            uint64(200000) // gas limit as uint64 instead of uint16
        );

        // Apply any custom options from extraData if provided
        if (extraData.length > 0) {
            options = bytes.concat(options, extraData);
        }

        // Send message through OApp's _lzSend
        _lzSend(
            lzSrcEid,
            payload,
            options,
            MessagingFee(msg.value, 0),
            payable(bridgeRouter) // refund address
        );

        // Update transfer status to pending
        _updateTransferStatus(transferId, BridgeTypes.TransferStatus.PENDING);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the status of a transfer
     * @param transferId ID of the transfer to update
     * @param status New status to set
     * @dev This function is internal and updates the transfer status
     */
    function _updateTransferStatus(
        bytes32 transferId,
        BridgeTypes.TransferStatus status
    ) internal {
        transferStatuses[transferId] = status;

        // Notify the BridgeRouter of the status change
        IBridgeRouter(bridgeRouter).updateTransferStatus(transferId, status);
    }

    /**
     * @notice Converts a chain ID to a LayerZero endpoint ID
     * @param chainId Standard chain ID
     * @return lzEid LayerZero endpoint ID
     */
    function _getLayerZeroEid(
        uint16 chainId
    ) internal view returns (uint32 lzEid) {
        // Get the LayerZero EID from our mapping
        lzEid = chainToLzEid[chainId];

        // If not found in the mapping, revert
        if (lzEid == 0) {
            revert UnsupportedChain();
        }

        return lzEid;
    }

    /**
     * @notice Set enforced options for transfers
     * @param _dstEid Destination endpoint ID
     * @param _gasLimit Gas limit for execution
     */
    function setEnforcedTransferOptions(
        uint32 _dstEid,
        uint256 _gasLimit
    ) external {
        // Only the owner can call this function
        if (msg.sender != owner()) revert Unauthorized();

        // Create enforced options array
        EnforcedOptionParam[]
            memory enforcedOptions = new EnforcedOptionParam[](1);

        // Set gas limit for lzReceive
        enforcedOptions[0] = EnforcedOptionParam({
            eid: _dstEid,
            msgType: TRANSFER,
            options: abi.encodePacked(uint16(1), uint16(_gasLimit))
        });

        // Apply enforced options
        _setEnforcedOptions(enforcedOptions);
    }

    /// @inheritdoc IReceiveAdapter
    function receiveAssetTransfer(
        address,
        uint256,
        address,
        uint16,
        bytes32,
        bytes calldata
    ) external pure {
        // For LayerZero, this will typically not be called directly
        // since messages are received via _lzReceive
        // But implementation is provided for interface compliance
        revert UseLayerZeroMessaging();
    }

    /// @inheritdoc IReceiveAdapter
    function receiveMessage(
        bytes calldata,
        address,
        uint16,
        bytes32
    ) external pure {
        // For LayerZero, this will typically not be called directly
        // since messages are received via _lzReceive
        // But implementation is provided for interface compliance
        revert UseLayerZeroMessaging();
    }

    /// @inheritdoc IReceiveAdapter
    function receiveStateRead(
        bytes calldata,
        address,
        uint16,
        bytes32
    ) external pure {
        // For LayerZero, this will typically not be called directly
        // since messages are received via _lzReceive
        // But implementation is provided for interface compliance
        revert UseLayerZeroMessaging();
    }
}
