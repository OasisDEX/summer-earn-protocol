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
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OAppRead} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppRead.sol";
import {ReadCodecV1, EVMCallRequestV1, EVMCallComputeV1} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/ReadCodecV1.sol";
import {MessagingParams, MessagingFee as EndpointFee, MessagingReceipt, SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {ICrossChainMessageReceiver} from "../interfaces/ICrossChainMessageReceiver.sol";
import {ICrossChainStateReadReceiver} from "../interfaces/ICrossChainStateReadReceiver.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {ExecutorConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";

/**
 * @title LayerZeroAdapter
 * @notice Adapter for the LayerZero bridge protocol
 * @dev Implements IBridgeAdapter interface and connects to LayerZero's messaging service using OAppRead standard
 */
contract LayerZeroAdapter is Ownable, OAppRead, IBridgeAdapter {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The BridgeRouter that manages this adapter
    address public bridgeRouter;

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

    /// @notice Use EnumerableSet for storage
    EnumerableSet.UintSet private _supportedChainIds;

    /// @notice Thrown when read channel is not configured
    error ReadChannelNotConfigured();

    /// @notice Thrown when invalid bridge router address is provided
    error InvalidBridgeRouter();

    /// @notice Thrown when invalid parameters are provided
    error InvalidParams();

    /// @notice Thrown when operation is not supported
    error OperationNotSupported();

    /// @notice Thrown when unauthorized access is attempted
    error Unauthorized();

    /// @notice Thrown when unsupported chain is accessed
    error UnsupportedChain();

    /// @notice Thrown when insufficient message value is provided
    error InsufficientMsgValue(uint256 required, uint256 provided);

    /// @notice Emitted when read libraries are configured
    event ReadLibrariesConfigured(
        address indexed readLib1002,
        uint32 indexed readChannelId
    );

    /// @notice Emitted when read DVNs are configured
    event ReadDVNsConfigured(
        address[] dvnAddresses,
        uint64 confirmations,
        address executor
    );

    /// @notice Emitted when bridge router is updated
    event BridgeRouterUpdated(
        address indexed oldRouter,
        address indexed newRouter
    );

    /// @notice Emitted when a relay operation fails
    event RelayFailed(bytes32 indexed operationId, bytes reason);

    /// @notice Emitted when a message is delivered
    event MessageDelivered(
        bytes32 indexed messageId,
        address indexed recipient,
        bool delivered
    );

    /// @notice Emitted when a read operation is not found
    event ReadOperationNotFound(bytes32 indexed guid, string reason);

    /// @notice Emitted when a read response is delivered
    event ReadResponseDelivered(bytes32 indexed operationId, bytes payload);

    /// @notice Emitted when a read request is initiated
    event ReadRequestInitiated(
        bytes32 indexed operationId,
        uint16 indexed srcChainId,
        uint16 indexed dstChainId,
        address dstContract,
        bytes4 selector
    );

    /// @notice Emitted when a message is initiated
    event MessageInitiated(
        bytes32 indexed operationId,
        uint16 indexed destinationChainId,
        address indexed recipient,
        bytes message
    );

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
            _supportedChainIds.add(_supportedChains[i]);
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

    /**
     * @notice Adds a supported chain
     * @param chainId Chain ID to add
     * @param lzEid LayerZero endpoint ID for the chain
     * @dev Can only be called by the contract owner
     */
    function addSupportedChain(
        uint16 chainId,
        uint32 lzEid
    ) external onlyOwner {
        chainToLzEid[chainId] = lzEid;
        lzEidToChain[lzEid] = chainId;
        _supportedChainIds.add(chainId);
    }

    /**
     * @notice Removes a supported chain
     * @param chainId Chain ID to remove
     * @dev Can only be called by the contract owner
     */
    function removeSupportedChain(uint16 chainId) external onlyOwner {
        uint32 lzEid = chainToLzEid[chainId];
        delete chainToLzEid[chainId];
        delete lzEidToChain[lzEid];
        _supportedChainIds.remove(chainId);
    }

    /**
     * @notice Updates the bridge router address (governance only)
     * @param newBridgeRouter Address of the new bridge router
     * @dev Can only be called by contract owner/governance
     */
    function setBridgeRouter(address newBridgeRouter) external onlyOwner {
        if (newBridgeRouter == address(0)) revert InvalidBridgeRouter();

        address oldRouter = bridgeRouter;
        bridgeRouter = newBridgeRouter;

        emit BridgeRouterUpdated(oldRouter, newBridgeRouter);
    }

    /**
     * @notice Configures ReadLib1002 for read operations
     * @param readLib1002Address Address of the ReadLib1002 contract
     * @dev Must be called to enable read operations
     */
    function configureReadLibraries(
        address readLib1002Address
    ) external onlyOwner {
        if (readChannelId == 0) revert ReadChannelNotConfigured();

        // Set send library for read channel
        endpoint.setSendLibrary(
            address(this),
            readChannelId,
            readLib1002Address
        );

        // Set receive library for read channel
        endpoint.setReceiveLibrary(
            address(this),
            readChannelId,
            readLib1002Address,
            0
        );

        emit ReadLibrariesConfigured(readLib1002Address, readChannelId);
    }

    /**
     * @notice Configures DVNs for read operations
     * @param readLib1002Address Address of the ReadLib1002 contract
     * @param dvnAddresses Array of DVN addresses (must be sorted)
     * @param confirmations Number of block confirmations required
     * @param executorAddress Address of the executor
     * @param maxMessageSize Maximum message size for executor
     */
    function configureReadDVNs(
        address readLib1002Address,
        address[] calldata dvnAddresses,
        uint64 confirmations,
        address executorAddress,
        uint32 maxMessageSize
    ) external onlyOwner {
        if (readChannelId == 0) revert ReadChannelNotConfigured();

        // Configure ULN (DVN) settings
        UlnConfig memory ulnConfig = UlnConfig({
            confirmations: confirmations,
            requiredDVNCount: uint8(dvnAddresses.length),
            optionalDVNCount: 0,
            optionalDVNThreshold: 0,
            requiredDVNs: dvnAddresses,
            optionalDVNs: new address[](0)
        });

        // Configure Executor settings
        ExecutorConfig memory executorConfig = ExecutorConfig({
            maxMessageSize: maxMessageSize,
            executor: executorAddress
        });

        // Prepare config parameters
        SetConfigParam[] memory params = new SetConfigParam[](2);
        params[0] = SetConfigParam({
            eid: readChannelId,
            configType: 1, // EXECUTOR_CONFIG_TYPE
            config: abi.encode(executorConfig)
        });
        params[1] = SetConfigParam({
            eid: readChannelId,
            configType: 2, // ULN_CONFIG_TYPE
            config: abi.encode(ulnConfig)
        });

        // Set configuration on endpoint
        endpoint.setConfig(address(this), readLib1002Address, params);

        emit ReadDVNsConfigured(dvnAddresses, confirmations, executorAddress);
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
        bytes memory actualPayload = _payload;

        // If the payload starts with a uint16 message type marker
        if (_payload.length >= 2) {
            messageType = uint16(bytes2(_payload)); // Takes first 2 bytes
            actualPayload = _payload[2:]; // Creates slice starting at index 2
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

            _handleGeneralMessage(message, recipient, messageId, srcChainId);
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
        bool delivered = false;
        bytes4 interfaceId = type(ICrossChainMessageReceiver).interfaceId;
        try
            ICrossChainMessageReceiver(recipient).supportsInterface(interfaceId)
        returns (bool supported) {
            if (supported) {
                try
                    ICrossChainMessageReceiver(recipient).receiveMessage(
                        srcChainId,
                        message
                    )
                {
                    delivered = true;
                } catch (bytes memory reason) {
                    emit RelayFailed(messageId, reason);
                }
            } else {
                (bool success, ) = recipient.call(
                    abi.encodeWithSelector(
                        ICrossChainMessageReceiver.receiveMessage.selector,
                        srcChainId,
                        message
                    )
                );
                if (success) {
                    delivered = true;
                } else {
                    emit RelayFailed(messageId, "Call failed");
                }
            }
        } catch (bytes memory reason) {
            emit RelayFailed(messageId, reason);
        }

        // Only call notifyMessageReceived if the delivery was successful
        if (delivered) {
            IBridgeRouter(bridgeRouter).notifyMessageReceived(
                messageId,
                address(0), // No asset for general message
                0, // No amount for general message
                recipient,
                srcChainId
            );
            // Emit event for message delivery
            emit MessageDelivered(messageId, recipient, delivered);
        } else {
            // Update status to FAILED if delivery failed
            _updateReceiveStatus(
                messageId,
                recipient,
                BridgeTypes.OperationStatus.FAILED
            );
        }
    }

    /**
     * @dev Handles responses from lzRead operations
     * @param _origin Source chain information
     * @param _guid Global unique identifier for tracking the packet
     * @param _payload Response payload
     */
    function _handleReadResponse(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _payload
    ) internal {
        // Extract requestId from the guid mapping
        bytes32 operationId = lzMessageToOperationId[_guid];
        if (operationId == bytes32(0)) {
            // Silently fail so it doesn't get locked with DVN
            emit ReadOperationNotFound(_guid, "No operationId found");
            return;
        }

        // Get the source chain ID from the origin
        uint16 srcChainId = lzEidToChain[_origin.srcEid];

        // Forward the result to the bridge router
        try
            IBridgeRouter(bridgeRouter).deliverReadResponse(
                operationId,
                srcChainId,
                _payload
            )
        {
            emit ReadResponseDelivered(operationId, _payload);
        } catch (bytes memory reason) {
            // Mark as failed if delivery fails
            _updateOperationStatus(
                operationId,
                BridgeTypes.OperationStatus.FAILED
            );
            emit RelayFailed(operationId, reason);
        }
    }

    /*//////////////////////////////////////////////////////////////
                          ADAPTER INTERFACE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISendAdapter
    function transferAsset(
        bytes32, // operationId - not used by LayerZero adapter
        uint16,
        address,
        address,
        uint256,
        address,
        address, // keeper - not used by LayerZero adapter
        BridgeTypes.AdapterParams calldata
    ) external payable {
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
            if (readChannelId == 0) revert ReadChannelNotConfigured();

            EndpointFee memory fee = _quote(
                readChannelId,
                payload,
                options,
                false
            );
            return (fee.nativeFee, fee.lzTokenFee);
        } else {
            EndpointFee memory fee = _quote(dstEid, payload, options, false);
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
        uint256 length = _supportedChainIds.length();
        uint16[] memory chains = new uint16[](length);

        for (uint256 i = 0; i < length; i++) {
            // Need to cast from uint256 to uint16
            chains[i] = uint16(_supportedChainIds.at(i));
        }

        return chains;
    }

    /// @inheritdoc ISendAdapter
    function readState(
        bytes32 operationId, // Accept from router
        uint16 srcChainId,
        uint16 dstChainId,
        address dstContract,
        bytes4 selector,
        bytes calldata readParams,
        address originator,
        BridgeTypes.AdapterParams calldata adapterParams
    ) external payable {
        // Only BridgeRouter should call this
        if (msg.sender != bridgeRouter) revert Unauthorized();

        // Ensure a read channel has been configured
        if (readChannelId == 0) revert ReadChannelNotConfigured();

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
            EndpointFee(msg.value, 0),
            payable(originator)
        );

        // Map LayerZero's guid to router's operation ID
        lzMessageToOperationId[receipt.guid] = operationId;

        // Emit event for read request initiation
        emit ReadRequestInitiated(
            operationId,
            srcChainId,
            dstChainId,
            dstContract,
            selector
        );

        // Set initial status as SENT
        IBridgeRouter(bridgeRouter).updateOperationStatus(
            operationId,
            BridgeTypes.OperationStatus.SENT
        );
    }

    /// @inheritdoc IBridgeAdapter
    function supportsChain(
        uint16 chainId
    ) external view override returns (bool) {
        return chainToLzEid[chainId] != 0;
    }

    /// @inheritdoc ISendAdapter
    function sendMessage(
        bytes32 operationId, // Accept from router
        uint16 destinationChainId,
        address recipient,
        bytes calldata message,
        address originator,
        BridgeTypes.AdapterParams calldata adapterParams
    ) external payable {
        // Only the BridgeRouter should call this function
        if (msg.sender != bridgeRouter) revert Unauthorized();

        // Get the LayerZero EID for destination chain
        uint32 lzDstEid = _getLayerZeroEid(destinationChainId);

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
            EndpointFee(msg.value, 0),
            payable(originator)
        );

        // Map LayerZero's guid to router's operation ID
        lzMessageToOperationId[receipt.guid] = operationId;

        // Emit event for message initiation
        emit MessageInitiated(
            operationId,
            destinationChainId,
            recipient,
            message
        );
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

        // Create default options with minimum gas
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
        EndpointFee memory quoteFee = _quote(_dstEid, _payload, options, false);
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
    function supportsOperation(
        BridgeTypes.OperationType operationType
    ) external pure override returns (bool) {
        // LayerZero supports messaging and state reading operations, but not asset transfer
        return
            operationType == BridgeTypes.OperationType.MESSAGE ||
            operationType == BridgeTypes.OperationType.READ_STATE;
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
