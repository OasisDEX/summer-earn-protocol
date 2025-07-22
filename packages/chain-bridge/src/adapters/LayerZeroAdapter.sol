// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {LayerZeroOptionsHelper} from "../helpers/LayerZeroOptionsHelper.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";

import {ISendAdapter} from "../interfaces/ISendAdapter.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {BaseBridgeAdapter} from "./BaseBridgeAdapter.sol";
import {ReadLibConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/readlib/ReadLibBase.sol";
import {MessagingFee as EndpointFee, MessagingReceipt} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {OAppRead} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppRead.sol";
import {EVMCallRequestV1, ReadCodecV1} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/ReadCodecV1.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title LayerZeroAdapter
 * @notice Adapter for the LayerZero bridge protocol
 * @dev Implements IBridgeAdapter interface and connects to LayerZero's messaging service using OAppRead standard
 */
contract LayerZeroAdapter is OAppRead, IBridgeAdapter, BaseBridgeAdapter {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of LayerZero message hashes to operation IDs
    mapping(bytes32 guid => bytes32 operationId) public lzMessageToOperationId;

    /// @notice Mapping of supported chains to their LayerZero chain IDs
    mapping(uint16 chainId => uint32 lzEid) public chainToLzEid;

    /// @notice Inverse mapping of LayerZero chain IDs to our chain IDs
    mapping(uint32 lzEid => uint16 chainId) public lzEidToChain;

    /// @notice Read channel identifier for lzRead operations
    uint32 public constant READ_CHANNEL_THRESHOLD = 4294965694; // Used to identify responses

    /// @notice Active read channel ID for sending read requests
    uint32 public readChannelId;

    /// @notice Minimum gas limit for operations
    uint128 public minGasLimit;

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

    /// @notice Use EnumerableSet for storage
    EnumerableSet.UintSet private _supportedChainIds;

    // Note: Errors are inherited from IBridgeAdapter interface

    /// @notice Emitted when read libraries are configured
    event ReadLibrariesConfigured(
        address indexed readLib1002,
        uint32 indexed readChannelId
    );

    /// @notice Emitted when read DVNs are configured
    /// forge-lint: disable-start(mixed-case-variable, mixed-case-function)
    event ReadDVNsConfigured(
        uint32 indexed readChannelId,
        address[] readDVNs,
        uint64 confirmations
    );
    /// forge-lint: disable-end(mixed-case-variable, mixed-case-function)

    /// @notice Emitted when read executor is configured
    event ReadExecutorConfigured(
        uint32 indexed readChannelId,
        address indexed executor,
        uint32 maxMessageSize
    );

    // Note: Other events are inherited from IBridgeAdapter and ISendAdapter interfaces

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the LayerZeroAdapter
     * @param _endpoint Address of the LayerZero endpoint
     * @param _crossChainRegistry Address of the CrossChainRegistry contract
     * @param _accessManager Address of the AccessManager contract
     * @param _supportedChains Array of chain IDs supported by this adapter
     * @param _lzEids Array of corresponding LayerZero endpoint IDs
     * @param _initialOwner Address of the contract owner
     */
    constructor(
        address _endpoint,
        address _crossChainRegistry,
        address _accessManager,
        uint16[] memory _supportedChains,
        uint32[] memory _lzEids,
        address _initialOwner
    )
        OAppRead(_endpoint, _initialOwner)
        Ownable(_initialOwner)
        BaseBridgeAdapter(_crossChainRegistry, _accessManager)
    {
        if (_supportedChains.length != _lzEids.length) revert InvalidParams();

        // Setup chain ID mappings
        for (uint256 i = 0; i < _supportedChains.length; i++) {
            chainToLzEid[_supportedChains[i]] = _lzEids[i];
            lzEidToChain[_lzEids[i]] = _supportedChains[i];
            _supportedChainIds.add(_supportedChains[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                          GOVERNANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Activates a read channel for state reading operations
     * @param _readChannelId The ID of the read channel to activate
     * @dev Can only be called by the contract owner
     */
    function activateReadChannel(uint32 _readChannelId) external onlyGovernor {
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
    ) external onlyGovernor {
        chainToLzEid[chainId] = lzEid;
        lzEidToChain[lzEid] = chainId;
        _supportedChainIds.add(chainId);
    }

    /**
     * @notice Removes a supported chain
     * @param chainId Chain ID to remove
     * @dev Can only be called by the contract owner
     */
    function removeSupportedChain(uint16 chainId) external onlyGovernor {
        uint32 lzEid = chainToLzEid[chainId];
        delete chainToLzEid[chainId];
        delete lzEidToChain[lzEid];
        _supportedChainIds.remove(chainId);
    }

    /**
     * @notice Configures ReadLib1002 for read operations
     * @param readLib1002Address Address of the ReadLib1002 contract
     * @dev Must be called to enable read operations
     */
    function configureReadLibraries(
        address readLib1002Address
    ) external onlyGovernor {
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
     * @notice Configures DVN settings for read operations
     * @param readLib1002Address Address of the ReadLib1002 contract
     * @param readDVNs Array of DVN addresses for read operations (must be sorted alphabetically)
     * @param confirmations Number of block confirmations required
     * @param executor Address of the executor for read operations
     * @dev Must be called to enable read operations with proper DVN and executor configuration
     */
    /// forge-lint: disable-start(mixed-case-variable, mixed-case-function)
    function configureReadDVNs(
        address readLib1002Address,
        address[] memory readDVNs,
        uint64 confirmations,
        address executor
    ) external onlyGovernor {
        if (readChannelId == 0) revert ReadChannelNotConfigured();
        if (readDVNs.length == 0) revert InvalidParams();
        if (readLib1002Address == address(0)) revert InvalidParams();
        if (executor == address(0)) revert InvalidParams();

        // Verify DVNs are sorted (required by LayerZero)
        for (uint256 i = 1; i < readDVNs.length; i++) {
            if (readDVNs[i] <= readDVNs[i - 1]) revert InvalidParams(); // Must be sorted
        }

        // Create ReadLibConfig for read operations (this includes BOTH DVNs AND executor)
        ReadLibConfig memory readLibConfig = ReadLibConfig({
            executor: executor,
            requiredDVNCount: uint8(readDVNs.length),
            optionalDVNCount: 0,
            optionalDVNThreshold: 0,
            requiredDVNs: readDVNs,
            optionalDVNs: new address[](0)
        });

        // Encode the ReadLibConfig
        bytes memory encodedConfig = abi.encode(readLibConfig);

        // Create SetConfigParam array for the read channel
        SetConfigParam[] memory params = new SetConfigParam[](1);
        params[0] = SetConfigParam({
            eid: readChannelId,
            configType: 1, // CONFIG_TYPE_READ_LID_CONFIG
            config: encodedConfig
        });

        // Configure read library for read channel
        endpoint.setConfig(address(this), readLib1002Address, params);

        emit ReadDVNsConfigured(readChannelId, readDVNs, confirmations);
    }

    /// forge-lint: disable-end(mixed-case-variable, mixed-case-function)

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
        // Check if this is a response from a read channel
        // srcEid - Read Channel ID for Read operations -
        // https://docs.layerzero.network/v2/developers/evm/lzread/overview#hybrid-messaging--read

        // todo: should the read reponse also contain the operation type and the originator?
        if (_origin.srcEid > READ_CHANNEL_THRESHOLD) {
            _relayReadResponse(
                _origin,
                _guid,
                abi.encode(BridgeTypes.ReadResponse({data: _payload}))
            );
            return;
        } else if (_payload.length >= 2) {
            // If the payload starts with a uint16 message type marker
            BridgeTypes.OperationType operationType = BridgeTypes.OperationType(
                uint8(uint16(bytes2(_payload)))
            ); // Takes first 2 bytes
            bytes memory actualPayload = _payload[2:]; // Creates slice starting at index 2
            if (operationType == BridgeTypes.OperationType.MESSAGE) {
                // Get the source chain ID from the origin
                uint16 srcChainId = lzEidToChain[_origin.srcEid];
                // IMPORTANT: Use actualPayload here instead of _payload
                // This ensures we decode only the message data without the message type prefix
                (
                    bytes memory message,
                    address recipient,
                    bytes32 messageId
                ) = abi.decode(actualPayload, (bytes, address, bytes32));

                _relayGeneralMessage(message, recipient, messageId, srcChainId);
            } else {
                revert UnsupportedMessageType();
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
    function _relayGeneralMessage(
        bytes memory message,
        address recipient,
        bytes32 messageId,
        uint16 srcChainId
    ) internal {
        IBridgeRouter(bridgeRouter()).deliver(
            messageId,
            srcChainId,
            address(0), // no asset
            0, // no amount
            recipient,
            message
        );
    }

    /**
     * @dev Handles responses from lzRead operations
     * @param _origin Source chain information
     * @param _guid Global unique identifier for tracking the packet
     * @param _payload Response payload
     */
    function _relayReadResponse(
        Origin calldata _origin,
        bytes32 _guid,
        bytes memory _payload
    ) internal {
        // Extract requestId from the guid mapping
        bytes32 operationId = lzMessageToOperationId[_guid];
        if (operationId == bytes32(0)) {
            // Silently fail so it doesn't get locked with DVN
            emit ReadOperationNotFound(_guid, "No operationId found");
            return;
        }

        IBridgeRouter(bridgeRouter()).deliverReadResponse(
            operationId,
            lzEidToChain[_origin.srcEid],
            _payload
        );
    }

    /*//////////////////////////////////////////////////////////////
                          ADAPTER INTERFACE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISendAdapter
    function transferAsset(
        bytes32, // operationId - not used by LayerZero adapter
        uint16 destinationChainId,
        address,
        address,
        uint256,
        address,
        address, // keeper - not used by LayerZero adapter
        BridgeTypes.AdapterParams calldata
    ) external payable onlySupportedDestination(destinationChainId) {
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
    )
        external
        view
        onlySupportedDestination(destinationChainId)
        returns (uint256 nativeFee, uint256 tokenFee)
    {
        // Convert destinationChainId to LayerZero EID
        uint32 lzDstEid = _getLayerZeroEid(destinationChainId);

        if (!supportsOperation(operationType)) revert OperationNotSupported();

        // Create appropriate payload based on message type
        bytes memory payload;
        bytes memory options;

        if (operationType == BridgeTypes.OperationType.READ_STATE) {
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
            // For BridgeTypes.OperationType.MESSAGE, use same encoding format as sendMessage
            bytes memory dummyMessage = abi.encode(
                "dummy message for fee estimation"
            );
            payload = abi.encodePacked(
                uint16(BridgeTypes.OperationType.MESSAGE),
                abi.encode(dummyMessage, address(0), bytes32(0))
            );
        }

        options = _prepareOptions(adapterParams, operationType);

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
        return IBridgeRouter(bridgeRouter()).getOperationStatus(operationId);
    }

    /// @inheritdoc ISendAdapter
    function readState(
        bytes32 operationId,
        uint16 srcChainId,
        uint16 destinationChainId,
        address destinationContract,
        bytes4 selector,
        bytes calldata readParams,
        address keeper,
        BridgeTypes.AdapterParams calldata adapterParams
    )
        external
        payable
        onlySupportedDestination(destinationChainId)
        onlyRouter
        nonReentrant
    {
        // Ensure a read channel has been configured
        if (readChannelId == 0) revert ReadChannelNotConfigured();

        // Get the LayerZero EID for destination chain
        uint32 lzDstEid = _getLayerZeroEid(destinationChainId);

        // Check if enough value was sent if specified in adapter options
        if (adapterParams.msgValue > 0 && msg.value < adapterParams.msgValue) {
            revert InsufficientMsgValue(adapterParams.msgValue, msg.value);
        }

        bytes32 guid;
        {
            // Create EVMCallRequestV1 for the read request (scope to avoid stack too deep)
            EVMCallRequestV1[] memory readRequests = new EVMCallRequestV1[](1);
            readRequests[0] = EVMCallRequestV1({
                appRequestLabel: 1,
                targetEid: lzDstEid,
                isBlockNum: false,
                blockNumOrTimestamp: uint64(block.timestamp),
                confirmations: 15,
                to: destinationContract,
                callData: abi.encodePacked(selector, readParams)
            });

            // Encode and send
            bytes memory cmd = ReadCodecV1.encode(0, readRequests);
            bytes memory options = _prepareOptions(
                adapterParams,
                BridgeTypes.OperationType.READ_STATE
            );

            MessagingReceipt memory receipt = _lzSend(
                readChannelId,
                cmd,
                options,
                EndpointFee(msg.value, 0),
                payable(keeper)
            );
            guid = receipt.guid;
        }

        // Map LayerZero's guid to router's operation ID
        lzMessageToOperationId[guid] = operationId;

        emit ReadRequestInitiated(
            operationId,
            srcChainId,
            destinationChainId,
            destinationContract,
            selector
        );
    }

    /// @inheritdoc ISendAdapter
    function sendMessage(
        bytes32 operationId, // Accept from router
        uint16 destinationChainId,
        address recipient,
        bytes calldata message,
        address keeper,
        BridgeTypes.AdapterParams calldata adapterParams
    )
        external
        payable
        onlySupportedDestination(destinationChainId)
        onlyRouter
        nonReentrant
    {
        // Get the LayerZero EID for destination chain
        uint32 lzDstEid = _getLayerZeroEid(destinationChainId);

        // If msgValue is specified in adapter options, ensure enough value was sent
        if (adapterParams.msgValue > 0 && msg.value < adapterParams.msgValue) {
            revert InsufficientMsgValue(adapterParams.msgValue, msg.value);
        }

        // Encode payload for LayerZero with BridgeTypes.OperationType.MESSAGE message type
        bytes memory payload = abi.encodePacked(
            uint16(BridgeTypes.OperationType.MESSAGE), // BridgeTypes.OperationType.MESSAGE message type
            abi.encode(message, recipient, operationId)
        );

        // Create options with appropriate gas limit
        bytes memory options = _prepareOptions(
            adapterParams,
            BridgeTypes.OperationType.MESSAGE
        );

        // Send message through OApp's _lzSend
        // Use tx.origin as refund address since that's the keeper who initiated the transaction
        MessagingReceipt memory receipt = _lzSend(
            lzDstEid,
            payload,
            options,
            EndpointFee(msg.value, 0),
            payable(keeper)
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
     * @param operationType The operation type being sent
     * @return options The prepared options with appropriate minimum gas limits
     */
    function _prepareOptions(
        BridgeTypes.AdapterParams memory adapterParams,
        BridgeTypes.OperationType operationType
    ) internal view returns (bytes memory) {
        uint128 gasLimit = adapterParams.gasLimit > 0
            ? uint128(adapterParams.gasLimit)
            : uint128(defaultGasLimit());

        // Use the helper to create messaging options with minimum gas limit enforcement
        if (operationType == BridgeTypes.OperationType.READ_STATE) {
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
     * @param operationType Operation type
     * @param _payload Message payload
     * @return requiredFee Minimum fee required for operation
     */
    function getRequiredFee(
        uint32 _dstEid,
        BridgeTypes.OperationType operationType,
        bytes memory _payload
    ) public view returns (uint256 requiredFee) {
        // Create default options with minimum - use scoping to avoid stack too deep
        bytes memory options;
        {
            // Create params in limited scope
            BridgeTypes.AdapterParams memory params = BridgeTypes
                .AdapterParams({
                    gasLimit: uint64(defaultGasLimit()),
                    msgValue: 0,
                    calldataSize: 0,
                    options: bytes("")
                });

            if (operationType == BridgeTypes.OperationType.READ_STATE) {
                // For state read, create read options with minimum gas
                options = LayerZeroOptionsHelper.createLzReadOptions(
                    params,
                    uint128(defaultGasLimit())
                );
            } else {
                // For standard messaging, create messaging options with minimum gas
                options = LayerZeroOptionsHelper.createMessagingOptions(
                    params,
                    uint128(defaultGasLimit())
                );
            }
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
    ) public pure override returns (bool) {
        // LayerZero supports messaging and state reading operations, but not asset transfer
        return
            operationType == BridgeTypes.OperationType.MESSAGE ||
            operationType == BridgeTypes.OperationType.READ_STATE;
    }
}
