// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";
import {ISendAdapter} from "../interfaces/ISendAdapter.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {OApp, Origin, MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {LayerZeroOptionsHelper} from "../helpers/LayerZeroOptionsHelper.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {console} from "forge-std/console.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ICrossChainReceiver} from "../interfaces/ICrossChainReceiver.sol";
import {OAppRead} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppRead.sol";
import {ReadCodecV1, EVMCallRequestV1, EVMCallComputeV1} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/ReadCodecV1.sol";
import {MessagingParams, MessagingFee, MessagingReceipt} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

/**
 * @title LayerZeroAdapter
 * @notice Adapter for the LayerZero bridge protocol
 * @dev Implements IBridgeAdapter interface and connects to LayerZero's messaging service using OAppRead standard
 */
contract LayerZeroAdapter is Ownable, OAppRead, IBridgeAdapter {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The BridgeRouter that manages this adapter
    address public immutable bridgeRouter;

    /// @notice Mapping of LayerZero message hashes to operation IDs
    mapping(bytes32 guid => bytes32 operationId) public lzMessageToOperationId;

    /// @notice Mapping of supported chains to their LayerZero chain IDs
    mapping(uint16 chainId => uint32 lzEid) public chainToLzEid;

    /// @notice Inverse mapping of LayerZero chain IDs to our chain IDs
    mapping(uint32 lzEid => uint16 chainId) public lzEidToChain;

    /// @notice Message type for state read
    uint16 public constant STATE_READ = 2;

    /// @notice Message type for general message
    uint16 public constant GENERAL_MESSAGE = 3;

    /// @notice Mapping of message types to their minimum gas limits
    mapping(uint16 msgType => uint128 minGasLimit) public minGasLimits;

    /// @notice Read channel identifier for lzRead operations
    uint32 public constant READ_CHANNEL_THRESHOLD = 4294965694; // Used to identify responses

    /// @notice Active read channel ID for sending read requests
    uint32 public readChannelId;

    /// @notice Thrown when insufficient fee is provided for a layerzero operation
    error InsufficientFeeForOptions(uint256 required, uint256 provided);

    /// @notice Thrown when invalid options are provided
    error InvalidOptions(bytes options);

    /// @notice Thrown when an unsupported message type is received
    error UnsupportedMessageType();

    /// @notice Thrown when the LayerZero endpoint is invalid
    error InvalidEndpoint();

    /// @notice Thrown when a message receiver rejects the call
    error ReceiverRejectedCall();

    /// @notice Mapping of operation types to message types
    mapping(BridgeTypes.OperationType => uint16) private operationToMessageType;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the LayerZeroAdapter
     * @param _endpoint Address of the LayerZero endpoint
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
    ) OAppRead(_endpoint, _owner) Ownable(_owner) {
        if (_bridgeRouter == address(0)) revert InvalidParams();
        if (_supportedChains.length != _lzEids.length) revert InvalidParams();

        bridgeRouter = _bridgeRouter;

        // Setup chain ID mappings
        for (uint i = 0; i < _supportedChains.length; i++) {
            chainToLzEid[_supportedChains[i]] = _lzEids[i];
            lzEidToChain[_lzEids[i]] = _supportedChains[i];
        }

        // Initialize default minimum gas limits
        minGasLimits[STATE_READ] = 300000;
        minGasLimits[GENERAL_MESSAGE] = 300000;

        // Initialize operation type to message type mapping
        operationToMessageType[
            BridgeTypes.OperationType.MESSAGE
        ] = GENERAL_MESSAGE;
        operationToMessageType[
            BridgeTypes.OperationType.READ_STATE
        ] = STATE_READ;
    }

    /*//////////////////////////////////////////////////////////////
                          GOVERNANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the minimum gas limit for a specific message type
     * @param msgType Message type to set minimum gas for
     * @param gasLimit New minimum gas limit value
     * @dev Can only be called by the contract owner
     */
    function setMinGasLimit(
        uint16 msgType,
        uint128 gasLimit
    ) external onlyOwner {
        minGasLimits[msgType] = gasLimit;
    }

    /**
     * @notice Activates a read channel for state reading operations
     * @param _readChannelId The ID of the read channel to activate
     * @dev Can only be called by the contract owner
     */
    function activateReadChannel(uint32 _readChannelId) external onlyOwner {
        readChannelId = _readChannelId;
        setReadChannel(_readChannelId, true);
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
        // Extract message type from the first 2 bytes if available
        uint16 messageType = GENERAL_MESSAGE; // Default to GENERAL_MESSAGE
        bytes calldata actualPayload = _payload;

        // If the payload starts with a uint16 message type marker
        if (_payload.length >= 2) {
            messageType = uint16(bytes2(_payload[:2]));
            actualPayload = _payload[2:];
        }

        // Check if this is a response from a read channel
        if (_origin.srcEid > READ_CHANNEL_THRESHOLD) {
            _handleReadResponse(_origin, _guid, _payload);
            return;
        }

        // Get the source chain ID from the origin
        uint16 srcChainId = lzEidToChain[_origin.srcEid];

        // Process based on message type
        if (messageType == GENERAL_MESSAGE) {
            // IMPORTANT: Use actualPayload here instead of _payload
            // This ensures we decode only the message data without the message type prefix
            (bytes memory message, address recipient, bytes32 messageId) = abi
                .decode(actualPayload, (bytes, address, bytes32));

            // Check if this is a confirmation message to the BridgeRouter
            if (_isConfirmationMessage(recipient, message)) {
                (bytes32 operationId, BridgeTypes.OperationStatus status) = abi
                    .decode(message, (bytes32, BridgeTypes.OperationStatus));
                _handleConfirmationMessage(operationId, status);
            } else {
                _handleGeneralMessage(
                    message,
                    recipient,
                    messageId,
                    srcChainId
                );
            }
        } else {
            revert UnsupportedMessageType();
        }
    }

    /**
     * @dev Handles general messages
     * @param message The message payload
     * @param recipient The recipient address of the message
     * @param messageId The message ID
     * @param srcChainId The source chain ID
     */
    function _handleGeneralMessage(
        bytes memory message,
        address recipient,
        bytes32 messageId,
        uint16 srcChainId
    ) internal {
        // Notify router about the received message, but don't call deliverMessage
        IBridgeRouter(bridgeRouter).notifyMessageReceived(
            messageId,
            address(0), // No asset for general message
            0, // No amount for general message
            recipient,
            srcChainId
        );

        bool delivered = false;
        // Deliver the message directly here
        bytes4 interfaceId = type(ICrossChainReceiver).interfaceId;
        try
            ICrossChainReceiver(recipient).supportsInterface(interfaceId)
        returns (bool supported) {
            if (supported) {
                ICrossChainReceiver(recipient).receiveMessage(
                    message,
                    recipient,
                    srcChainId,
                    messageId
                );
                delivered = true;
            } else {
                // Fallback for contracts that don't implement supportsInterface
                (bool success, ) = recipient.call(
                    abi.encodeWithSelector(
                        ICrossChainReceiver.receiveMessage.selector,
                        message,
                        recipient,
                        srcChainId,
                        messageId
                    )
                );
                if (!success) {
                    _updateReceiveStatus(
                        messageId,
                        recipient,
                        BridgeTypes.OperationStatus.FAILED
                    );
                    revert ReceiverRejectedCall();
                } else {
                    delivered = true;
                }
            }
        } catch Error(string memory reason) {
            _updateReceiveStatus(
                messageId,
                recipient,
                BridgeTypes.OperationStatus.FAILED
            );
            emit RelayFailed(messageId, abi.encodePacked(reason));
        } catch (bytes memory reason) {
            _updateReceiveStatus(
                messageId,
                recipient,
                BridgeTypes.OperationStatus.FAILED
            );
            emit RelayFailed(messageId, reason);
        }

        // Update the final status based on delivery result
        if (delivered) {
            _updateReceiveStatus(
                messageId,
                recipient,
                BridgeTypes.OperationStatus.DELIVERED
            );
        }

        // Emit event for message delivery
        emit MessageDelivered(messageId, recipient, delivered);
    }

    /**
     * @dev Checks if the message is a confirmation message to the BridgeRouter
     * @param recipient The recipient address of the message
     * @param message The message payload
     * @return true if the message is a confirmation message, false otherwise
     */
    function _isConfirmationMessage(
        address recipient,
        bytes memory message
    ) internal view returns (bool) {
        // Check if recipient is the bridge router
        if (recipient != bridgeRouter) return false;

        // Check if message length matches our expected format
        if (message.length != 64) return false; // 32 bytes for bytes32 + 32 bytes for enum

        // Extract the potential status value from the last 32 bytes
        uint256 statusValue;
        assembly {
            // message has a 32-byte length field, then data starts
            // transferId is bytes 0-31, status is bytes 32-63
            statusValue := mload(add(add(message, 32), 32))
        }

        // Check specifically for COMPLETED status (2)
        // This is the only status we currently expect in confirmation messages
        return statusValue == uint256(BridgeTypes.OperationStatus.COMPLETED);
    }

    /**
     * @dev Handles confirmation messages
     * @param operationId The ID of the operation being confirmed
     * @param status The status to update to
     */
    function _handleConfirmationMessage(
        bytes32 operationId,
        BridgeTypes.OperationStatus status
    ) internal {
        // Call receiveConfirmation on the BridgeRouter
        IBridgeRouter(bridgeRouter).receiveConfirmation(operationId, status);
    }

    /**
     * @dev Handles responses from lzRead operations
     * @param // _origin Source chain information
     * @param _guid Global unique identifier for tracking the packet
     * @param _payload Response payload
     */
    function _handleReadResponse(
        Origin calldata,
        bytes32 _guid,
        bytes calldata _payload
    ) internal {
        // Extract requestId from the guid mapping
        bytes32 operationId = lzMessageToOperationId[_guid];
        if (operationId == bytes32(0)) {
            // Siliently fail so it doesn't get locked with DVN
            emit ReadOperationNotFound(_guid, "No operationId found");
            return;
        }

        // For read responses, we don't need to call notifyTransferReceived
        // since this is a response to our own request, not an incoming transfer

        // Forward the result to the bridge router
        bool delivered = false;
        try
            IBridgeRouter(bridgeRouter).deliverReadResponse(
                operationId,
                _payload
            )
        {
            delivered = true;
        } catch (bytes memory reason) {
            // Mark as failed if delivery fails
            _updateOperationStatus(
                operationId,
                BridgeTypes.OperationStatus.FAILED
            );
            emit RelayFailed(operationId, reason);
        }

        // Emit event for read response delivery
        if (delivered) {
            emit ReadResponseDelivered(operationId, _payload, delivered);
        }
    }

    /*//////////////////////////////////////////////////////////////
                          ADAPTER INTERFACE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISendAdapter
    function transferAsset(
        uint16,
        address,
        address,
        uint256,
        address,
        BridgeTypes.AdapterParams calldata
    ) external payable returns (bytes32) {
        // This adapter doesn't support asset transfers directly
        // It should never be called for this purpose due to capability flags
        revert OperationNotSupported();
    }

    /// @inheritdoc IBridgeAdapter
    function estimateFee(
        uint16 destinationChainId,
        address,
        uint256,
        BridgeTypes.AdapterParams calldata adapterParams,
        BridgeTypes.OperationType operationType
    ) external view returns (uint256 nativeFee, uint256 tokenFee) {
        // Convert destinationChainId to LayerZero EID
        uint32 lzDstEid = _getLayerZeroEid(destinationChainId);

        // Look up the message type from the mapping
        uint16 messageType = operationToMessageType[operationType];

        if (messageType == 0) revert OperationNotSupported();

        // Create appropriate payload based on message type
        bytes memory payload;
        bytes memory options;

        if (messageType == STATE_READ) {
            // Construct a READ payload identical to readState implementation
            EVMCallRequestV1[] memory readRequests = new EVMCallRequestV1[](1);
            readRequests[0] = EVMCallRequestV1({
                appRequestLabel: 1,
                targetEid: lzDstEid,
                isBlockNum: false,
                blockNumOrTimestamp: uint64(block.timestamp),
                confirmations: 15,
                to: address(0x1), // Use a dummy address
                callData: new bytes(0)
            });

            payload = ReadCodecV1.encode(0, readRequests);
        } else {
            // For GENERAL_MESSAGE, use same encoding format as sendMessage
            bytes memory dummyMessage = abi.encode(
                "dummy message for fee estimation"
            );
            payload = abi.encodePacked(
                uint16(GENERAL_MESSAGE),
                abi.encode(dummyMessage, address(0), bytes32(0))
            );
        }

        options = _prepareOptions(adapterParams, messageType);

        // Quote should use the same destination target as real message
        uint32 dstEid = lzDstEid;

        // Get the fee required
        if (operationType == BridgeTypes.OperationType.READ_STATE) {
            MessagingFee memory fee = _quote(
                readChannelId,
                payload,
                options,
                false
            );
            return (fee.nativeFee, fee.lzTokenFee);
        } else {
            MessagingFee memory fee = _quote(dstEid, payload, options, false);
            return (fee.nativeFee, fee.lzTokenFee);
        }
    }

    /// @inheritdoc IBridgeAdapter
    function getOperationStatus(
        bytes32 operationId
    ) external view override returns (BridgeTypes.OperationStatus) {
        return IBridgeRouter(bridgeRouter).getOperationStatus(operationId);
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
        uint16 srcChainId,
        uint16 dstChainId,
        address dstContract,
        bytes4 selector,
        bytes calldata readParams,
        address originator,
        BridgeTypes.AdapterParams calldata adapterParams
    ) external payable returns (bytes32 operationId) {
        // Only BridgeRouter should call this
        if (msg.sender != bridgeRouter) revert Unauthorized();

        // Ensure a read channel has been configured
        if (readChannelId == 0) revert ReadChannelNotConfigured();

        // Generate operationId
        operationId = keccak256(
            abi.encode(
                block.chainid,
                dstChainId,
                dstContract,
                selector,
                readParams,
                block.timestamp
            )
        );

        // Get the LayerZero EID for destination chain
        uint32 lzDstEid = _getLayerZeroEid(dstChainId);

        // Check if enough value was sent if specified in adapter options
        if (adapterParams.msgValue > 0 && msg.value < adapterParams.msgValue) {
            revert InsufficientMsgValue(adapterParams.msgValue, msg.value);
        }

        // Create EVMCallRequestV1 for the read request
        EVMCallRequestV1[] memory readRequests = new EVMCallRequestV1[](1);
        readRequests[0] = EVMCallRequestV1({
            appRequestLabel: 1, // You can use a custom label
            targetEid: lzDstEid,
            isBlockNum: false, // Using timestamp
            blockNumOrTimestamp: uint64(block.timestamp),
            confirmations: 15, // Adjust based on chain requirements
            to: dstContract,
            callData: abi.encodePacked(selector, readParams)
        });

        // Encode the read command properly using ReadCodecV1
        bytes memory cmd = ReadCodecV1.encode(0, readRequests);

        bytes memory options = _prepareOptions(adapterParams, STATE_READ);

        // Send message through OApp's _lzSend to the configured read channel
        MessagingReceipt memory receipt = _lzSend(
            readChannelId, // Use the stored read channel ID, not the threshold
            cmd,
            options,
            MessagingFee(msg.value, 0),
            payable(originator)
        );

        lzMessageToOperationId[receipt.guid] = operationId;

        // Emit event for read request initiation
        emit ReadRequestInitiated(
            operationId,
            srcChainId,
            dstChainId,
            dstContract,
            selector
        );

        return operationId;
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

    /// @inheritdoc ISendAdapter
    function sendMessage(
        uint16 destinationChainId,
        address recipient,
        bytes calldata message,
        address originator,
        BridgeTypes.AdapterParams calldata adapterParams
    ) external payable returns (bytes32 operationId) {
        // Only the BridgeRouter should call this function
        if (msg.sender != bridgeRouter) revert Unauthorized();

        // Get the LayerZero EID for destination chain
        uint32 lzDstEid = _getLayerZeroEid(destinationChainId);

        // Generate a unique message ID
        operationId = keccak256(
            abi.encode(
                block.chainid,
                destinationChainId,
                recipient,
                message,
                block.timestamp
            )
        );

        // If msgValue is specified in adapter options, ensure enough value was sent
        if (adapterParams.msgValue > 0 && msg.value < adapterParams.msgValue) {
            revert InsufficientMsgValue(adapterParams.msgValue, msg.value);
        }

        // Encode payload for LayerZero with GENERAL_MESSAGE message type
        bytes memory payload = abi.encodePacked(
            uint16(GENERAL_MESSAGE), // GENERAL_MESSAGE message type
            abi.encode(message, recipient, operationId)
        );

        // Create options with appropriate gas limit
        bytes memory options = _prepareOptions(adapterParams, GENERAL_MESSAGE);

        // Send message through OApp's _lzSend
        MessagingReceipt memory receipt = _lzSend(
            lzDstEid,
            payload,
            options,
            MessagingFee(msg.value, 0),
            payable(originator)
        );

        lzMessageToOperationId[receipt.guid] = operationId;

        // Emit event for message initiation
        emit MessageInitiated(
            operationId,
            destinationChainId,
            recipient,
            message
        );

        return operationId;
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
     * @notice Creates options with gas limit at least as high as the configured minimum
     * @param adapterParams User-provided adapter parameters
     * @param msgType The message type being sent
     * @return options The prepared options with appropriate minimum gas limits
     */
    function _prepareOptions(
        BridgeTypes.AdapterParams memory adapterParams,
        uint16 msgType
    ) internal view returns (bytes memory) {
        // Get minimum gas limit for this message type
        uint128 minimumGas = minGasLimits[msgType];

        // Ensure gas limit meets minimum requirements
        uint128 gasLimit = adapterParams.gasLimit < minimumGas
            ? minimumGas
            : uint128(adapterParams.gasLimit);

        // Use the helper to create messaging options with minimum gas limit enforcement
        if (msgType == STATE_READ) {
            return
                LayerZeroOptionsHelper.createLzReadOptions(
                    adapterParams,
                    gasLimit
                );
        } else {
            return
                LayerZeroOptionsHelper.createMessagingOptions(
                    adapterParams,
                    gasLimit
                );
        }
    }

    /**
     * @notice Calculate required fees based on minimum gas limits
     * @param _dstEid Destination endpoint ID
     * @param _msgType Message type
     * @param _payload Message payload
     * @return requiredFee Minimum fee required for operation
     */
    function getRequiredFee(
        uint32 _dstEid,
        uint16 _msgType,
        bytes memory _payload
    ) public view returns (uint256 requiredFee) {
        // Get minimum gas limit for this message type
        uint128 minimumGas = minGasLimits[_msgType];

        // Create default options with minimum gas limit
        bytes memory options;

        if (_msgType == STATE_READ) {
            // For state read, create read options with minimum gas
            BridgeTypes.AdapterParams memory params = BridgeTypes
                .AdapterParams({
                    gasLimit: uint64(minimumGas),
                    msgValue: 0,
                    calldataSize: 0,
                    options: bytes("")
                });
            options = LayerZeroOptionsHelper.createLzReadOptions(
                params,
                minimumGas
            );
        } else {
            // For standard messaging, create messaging options with minimum gas
            BridgeTypes.AdapterParams memory params = BridgeTypes
                .AdapterParams({
                    gasLimit: uint64(minimumGas),
                    msgValue: 0,
                    calldataSize: 0,
                    options: bytes("")
                });
            options = LayerZeroOptionsHelper.createMessagingOptions(
                params,
                minimumGas
            );
        }

        // Quote the fee with our generated options
        MessagingFee memory quoteFee = _quote(
            _dstEid,
            _payload,
            options,
            false
        );
        return quoteFee.nativeFee;
    }

    /**
     * @notice Converts a LayerZero endpoint ID to our chain ID format
     * @param _lzEid LayerZero endpoint ID
     * @return chainId Standard chain ID used by our system
     */
    function _getLzChainId(
        uint32 _lzEid
    ) internal view returns (uint16 chainId) {
        // Get the chain ID from our mapping
        chainId = lzEidToChain[_lzEid];

        // If not found in the mapping, revert
        if (chainId == 0) {
            revert UnsupportedChain();
        }

        return chainId;
    }

    /// @inheritdoc IBridgeAdapter
    function supportsAssetTransfer() external pure returns (bool) {
        // This adapter doesn't support native asset transfers
        // as it has no liquidity management
        return false;
    }

    /// @inheritdoc IBridgeAdapter
    function supportsMessaging() external pure returns (bool) {
        // This adapter supports general cross-chain messaging
        return true;
    }

    /// @inheritdoc IBridgeAdapter
    function supportsStateRead() external pure returns (bool) {
        // This adapter supports state reading
        return true;
    }

    /**
     * @notice Updates the status of a transfer on sending chain
     * @param operationId ID of the operation to update
     * @param status New status to set
     */
    function _updateOperationStatus(
        bytes32 operationId,
        BridgeTypes.OperationStatus status
    ) internal {
        IBridgeRouter(bridgeRouter).updateOperationStatus(operationId, status);
    }

    /**
     * @notice Updates the status of a received transfer on receiving chain
     * @param requestId ID of the received request/transfer
     * @param recipient Address of the message recipient (only needed for COMPLETED status)
     * @param status New status to set
     */
    function _updateReceiveStatus(
        bytes32 requestId,
        address recipient,
        BridgeTypes.OperationStatus status
    ) internal {
        IBridgeRouter(bridgeRouter).updateReceiveStatus(
            requestId,
            recipient,
            status
        );
    }
}
