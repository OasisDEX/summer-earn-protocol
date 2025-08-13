// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {LayerZeroOptionsHelper} from "../helpers/LayerZeroOptionsHelper.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IMessageAdapter} from "../interfaces/IMessageAdapter.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {BaseBridgeAdapter} from "../base/BaseBridgeAdapter.sol";
import {ReadLibConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/readlib/ReadLibBase.sol";
import {MessagingFee as EndpointFee, MessagingReceipt} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {OAppRead} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppRead.sol";
import {EVMCallRequestV1, ReadCodecV1} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/ReadCodecV1.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Bytes32AddressLib} from "solmate/src/utils/Bytes32AddressLib.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title LayerZeroAdapter
 * @notice Adapter for the LayerZero bridge protocol
 * @dev Implements IMessageAdapter and IBridgeAdapter interfaces and connects to LayerZero's messaging service using OAppRead standard
 */
contract LayerZeroAdapter is
    OAppRead,
    IMessageAdapter,
    IBridgeAdapter,
    BaseBridgeAdapter
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of LayerZero message hashes to operation IDs
    mapping(bytes32 guid => bytes32 operationId) public lzMessageToOperationId;

    /// @notice Threshold used to distinguish LayerZero lzRead responses by `srcEid`
    /// @dev LayerZero routes read responses through a reserved "read channel" range
    ///      near the top of the uint32 EID space (commonly with READ_CHANNEL_ID at
    ///      4294967295). Any `srcEid` strictly greater than this threshold is treated
    ///      as a read response. This value is set at deploy time to allow
    ///      forward-compatibility and testing across different environments.
    uint32 public immutable readChannelThreshold;

    /// @notice Active read channel ID for sending read requests
    uint32 public readChannelId;

    /// @notice Minimum gas limit for operations
    uint128 public minGasLimit;

    /// @notice Emitted when read libraries are configured
    event ReadLibrariesConfigured(
        address indexed readLib1002,
        uint32 indexed readChannelId
    );

    /// @notice Emitted when read DVNs are configured
    event ReadDVNsConfigured(
        uint32 indexed readChannelId,
        address[] readDVNs,
        uint64 confirmations
    );

    /// @notice Emitted when read executor is configured
    event ReadExecutorConfigured(
        uint32 indexed readChannelId,
        address indexed executor,
        uint32 maxMessageSize
    );

    /// @notice Mapping of chains that support read operations
    mapping(uint16 chainId => bool supportsRead) public chainSupportsRead;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the LayerZeroAdapter
     * @param _endpoint LayerZero endpoint on THIS chain
     * @param _crossChainRegistry Global CrossChainRegistry address
     * @param _accessManager Summer protocol access manager
     * @param _endpointChains Chain IDs to map at deploy-time
     * @param _endpointIds Corresponding LayerZero endpoint IDs
     *                     (Adds only the *mapping*; talking to a peer
     *                     still requires governance to register it in the registry.)
     * @param _initialOwner Owner for Ownable/OAppRead
     * @param _readChannelThreshold Threshold for determining read-channel responses
     */
    constructor(
        address _endpoint,
        address _crossChainRegistry,
        address _accessManager,
        uint16[] memory _endpointChains,
        uint32[] memory _endpointIds,
        address _initialOwner,
        uint32 _readChannelThreshold
    )
        OAppRead(_endpoint, _initialOwner)
        Ownable(_initialOwner)
        BaseBridgeAdapter(_crossChainRegistry, _accessManager)
    {
        if (_endpointChains.length != _endpointIds.length)
            revert InvalidParams();
        if (_readChannelThreshold == 0) revert InvalidParams();
        readChannelThreshold = _readChannelThreshold;

        // Setup chain ID to LayerZero EID mappings using base functionality
        for (uint256 i = 0; i < _endpointChains.length; i++) {
            _mapChainExternalId(_endpointChains[i], _endpointIds[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                          GOVERNANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Activates a read channel for state reading operations
     * @param _readChannelId The ID of the read channel to activate
     * @dev Requirements:
     *      - `_readChannelId` must be non-zero
     *      - `_readChannelId` must be strictly greater than `readChannelThreshold`
     *      These checks prevent misconfiguration where read responses would not be
     *      properly classified by `_lzReceive`.
     */
    function activateReadChannel(uint32 _readChannelId) external onlyGovernor {
        if (_readChannelId == 0 || _readChannelId <= readChannelThreshold) {
            revert InvalidParams();
        }
        readChannelId = _readChannelId;
        setReadChannel(_readChannelId, true);
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

    /**
     * @notice Configure read support for specific chains
     * @param chainId The chain ID to configure
     * @param supported Whether read operations are supported on this chain
     * @dev Can only be called by the contract owner
     */
    function setChainReadSupport(
        uint16 chainId,
        bool supported
    ) external onlyGovernor {
        chainSupportsRead[chainId] = supported;
    }

    /**
     * @notice Map a new chain-id → endpoint-id pair for LayerZero endpoints.
     * @dev Governance utility. This only updates the local mapping; it does NOT
     *      grant permission to send. That second layer of permission is still
     *      enforced via the CrossChainRegistry.
     *
     * @param chainId     Canonical EVM chain ID.
     * @param endpointId  LayerZero endpoint identifier (EID).
     */
    function mapEndpoint(
        uint16 chainId,
        uint32 endpointId
    ) external onlyGovernor {
        if (endpointId == 0) {
            revert InvalidParams();
        }
        _mapChainExternalId(chainId, endpointId);
    }

    /**
     * @notice Delete the endpoint mapping for a chain.
     * @param chainId Chain ID whose mapping should be removed.
     */
    function unmapEndpoint(uint16 chainId) external onlyGovernor {
        _unmapChainExternalId(chainId);
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
        // Check if this is a response from a read channel
        // srcEid - Read Channel ID for Read operations -
        // https://docs.layerzero.network/v2/developers/evm/lzread/overview#hybrid-messaging--read

        // todo: should the read reponse also contain the operation type and the originator?
        if (_origin.srcEid > readChannelThreshold) {
            _relayReadResponse(_origin, _guid, _payload);
        } else if (_payload.length >= 2) {
            // Decode the payload to extract operation type and data
            (
                BridgeTypes.OperationType operationType,
                bytes memory data
            ) = _decodePayload(_payload);
            if (operationType == BridgeTypes.OperationType.MESSAGE) {
                _relayMessage(_origin, data);
            } else {
                revert UnsupportedMessageType();
            }
        } else {
            revert UnsupportedMessageType();
        }
    }

    /**
     * @dev Handles messages from lzRead operations
     * @param _origin Source chain information
     * @param _payload Message payload
     */
    function _relayMessage(
        Origin calldata _origin,
        bytes memory _payload
    ) internal {
        BridgeTypes.RelayedMessageParams
            memory relayedMessageParams = _decodeRelayedMessageParams(_payload);
        _assertSourceChainId(
            externalIdToChainId[_origin.srcEid],
            relayedMessageParams.sourceChainId
        );
        // Defense-in-depth: bind the source OApp identity to the registry-declared peer.
        // LayerZero's Origin.sender is the remote OApp address proven by DVNs.
        // Ensure governance has registered that OApp as our peer for the source chain.
        _assertTrustedSource(
            Bytes32AddressLib.fromLast20Bytes(_origin.sender),
            relayedMessageParams.sourceChainId
        );
        IBridgeRouter(bridgeRouter()).deliver(
            BridgeTypes.OperationType.MESSAGE,
            _payload
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

        bytes memory operationPayload = _encodeRelayedReadResponse(
            BridgeTypes.RelayedReadResponse({
                readResponseData: _payload,
                operationId: operationId,
                sourceChainId: externalIdToChainId[_origin.srcEid]
            })
        );

        // Optional binding for read responses: the response comes back from the same OApp
        // that issued the read on the remote chain. Enforce registry peer mapping here too.
        _assertTrustedSource(
            Bytes32AddressLib.fromLast20Bytes(_origin.sender),
            externalIdToChainId[_origin.srcEid]
        );

        IBridgeRouter(bridgeRouter()).deliver(
            BridgeTypes.OperationType.READ_STATE,
            operationPayload
        );

        // Clean up mapping after successful delivery to prevent storage bloat
        delete lzMessageToOperationId[_guid];
    }

    /*//////////////////////////////////////////////////////////////
                          ADAPTER INTERFACE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBridgeAdapter
    function estimateFee(
        uint16 destinationChainId,
        address,
        uint256,
        BridgeTypes.BridgeOptions calldata options,
        BridgeTypes.OperationType operationType
    )
        external
        view
        onlyTrustedDestination(destinationChainId)
        returns (uint256 nativeFee, uint256 tokenFee)
    {
        if (!supportsOperation(operationType)) revert OperationNotSupported();

        // Use operation-specific builders
        uint32 lzDstEid = _getLayerZeroEid(destinationChainId);
        bytes memory payload;

        if (operationType == BridgeTypes.OperationType.READ_STATE) {
            payload = _createReadStatePayload(
                lzDstEid,
                address(0x1),
                new bytes(0)
            );
        } else {
            payload = _createMessagePayload(_createDummyMessageParams());
        }

        bytes memory lzOptions = _createLzOptions(options, operationType);
        EndpointFee memory fee = _quoteOperationFee(
            lzDstEid,
            payload,
            lzOptions,
            operationType
        );
        return (fee.nativeFee, fee.lzTokenFee);
    }

    /// @inheritdoc IMessageAdapter
    function readState(
        bytes32 operationId,
        BridgeTypes.ExecuteReadStateParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    )
        external
        payable
        onlyTrustedDestination(params.destinationChainId)
        onlyRouter
        nonReentrant
    {
        // Ensure a read channel has been configured
        if (readChannelId == 0) revert ReadChannelNotConfigured();

        // Get the LayerZero EID for destination chain
        uint32 lzDstEid = _getLayerZeroEid(params.destinationChainId);

        // Check if enough value was sent if specified in adapter options
        if (options.msgValue > 0 && msg.value < options.msgValue) {
            revert InsufficientMsgValue(options.msgValue, msg.value);
        }

        bytes32 guid;
        {
            // Clean, focused payload creation for read operations
            bytes memory cmd = _createReadStatePayload(
                lzDstEid,
                params.target,
                abi.encodePacked(params.selector, params.readParams)
            );
            bytes memory lzOptions = _createLzOptions(
                options,
                BridgeTypes.OperationType.READ_STATE
            );

            MessagingReceipt memory receipt = _lzSend(
                readChannelId,
                cmd,
                lzOptions,
                EndpointFee(msg.value, 0),
                payable(params.refundAddress)
            );
            guid = receipt.guid;
        }

        // Map LayerZero's guid to router's operation ID
        lzMessageToOperationId[guid] = operationId;

        emit ReadRequestInitiated(
            operationId,
            uint16(block.chainid),
            params.destinationChainId,
            params.target,
            params.selector
        );
    }

    /// @inheritdoc IMessageAdapter
    function sendMessage(
        bytes32 operationId, // Accept from router
        BridgeTypes.ExecuteSendMessageParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    )
        external
        payable
        onlyTrustedDestination(params.destinationChainId)
        onlyRouter
        nonReentrant
    {
        // Get the LayerZero EID for destination chain
        uint32 lzDstEid = _getLayerZeroEid(params.destinationChainId);

        // If msgValue is specified in adapter options, ensure enough value was sent
        if (options.msgValue > 0 && msg.value < options.msgValue) {
            revert InsufficientMsgValue(options.msgValue, msg.value);
        }

        // Clean, focused payload creation for message operations
        bytes memory payload = _createMessagePayload(
            BridgeTypes.RelayedMessageParams({
                recipient: params.target,
                message: params.message,
                operationId: operationId,
                originator: params.originator,
                sourceChainId: uint16(block.chainid)
            })
        );
        bytes memory lzOptions = _createLzOptions(
            options,
            BridgeTypes.OperationType.MESSAGE
        );

        // Send message through OApp's _lzSend
        // Use tx.origin as refund address since that's the keeper who initiated the transaction
        MessagingReceipt memory receipt = _lzSend(
            lzDstEid,
            payload,
            lzOptions,
            EndpointFee(msg.value, 0),
            payable(params.refundAddress)
        );

        // Map LayerZero's guid to router's operation ID
        lzMessageToOperationId[receipt.guid] = operationId;

        // Emit event for message initiation
        emit MessageInitiated(
            operationId,
            params.destinationChainId,
            params.target,
            params.message
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
        // Get the LayerZero EID from our endpoint mapping
        lzEid = chainToExternalId[chainId];

        // If not found in the mapping, revert
        if (lzEid == 0) {
            revert UnsupportedChain();
        }

        return lzEid;
    }

    /**
     * @notice Creates LayerZero options with appropriate gas limits
     * @param options User-provided bridge options
     * @param operationType The operation type being sent
     * @return lzOptions The prepared LayerZero options
     */
    function _createLzOptions(
        BridgeTypes.BridgeOptions memory options,
        BridgeTypes.OperationType operationType
    ) internal view returns (bytes memory) {
        uint128 gasLimit = uint128(_normalizeGas(options.gasLimit));

        if (operationType == BridgeTypes.OperationType.READ_STATE) {
            return
                LayerZeroOptionsHelper.createLzReadOptions(options, gasLimit);
        } else {
            return
                LayerZeroOptionsHelper.createMessagingOptions(
                    options,
                    gasLimit
                );
        }
    }

    /**
     * @notice Creates a read state payload for LayerZero operations
     * @param lzDstEid LayerZero destination endpoint ID
     * @param target Target contract address (use address(0x1) for estimation)
     * @param callData Call data (use empty bytes for estimation)
     * @return payload Encoded read state payload
     */
    function _createReadStatePayload(
        uint32 lzDstEid,
        address target,
        bytes memory callData
    ) internal view returns (bytes memory payload) {
        EVMCallRequestV1[] memory readRequests = new EVMCallRequestV1[](1);
        readRequests[0] = EVMCallRequestV1({
            appRequestLabel: 1,
            targetEid: lzDstEid,
            isBlockNum: false,
            blockNumOrTimestamp: uint64(block.timestamp),
            confirmations: 15,
            to: target,
            callData: callData
        });

        return ReadCodecV1.encode(0, readRequests);
    }

    /**
     * @notice Creates a message payload for LayerZero operations
     * @param params Message parameters (use dummy values for estimation)
     * @return payload Encoded message payload
     */
    function _createMessagePayload(
        BridgeTypes.RelayedMessageParams memory params
    ) internal pure returns (bytes memory payload) {
        return _encodeRelayedMessageParamsWithType(params);
    }

    /**
     * @notice Quotes fee for a specific operation type
     * @param lzDstEid LayerZero destination endpoint ID
     * @param payload Operation payload
     * @param lzOptions LayerZero options
     * @param operationType Type of operation
     * @return fee Quoted fee structure
     */
    function _quoteOperationFee(
        uint32 lzDstEid,
        bytes memory payload,
        bytes memory lzOptions,
        BridgeTypes.OperationType operationType
    ) internal view returns (EndpointFee memory fee) {
        if (operationType == BridgeTypes.OperationType.READ_STATE) {
            if (readChannelId == 0) revert ReadChannelNotConfigured();
            return _quote(readChannelId, payload, lzOptions, false);
        } else {
            return _quote(lzDstEid, payload, lzOptions, false);
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
            BridgeTypes.BridgeOptions memory params = BridgeTypes
                .BridgeOptions({
                    specifiedAdapter: address(this),
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
        EndpointFee memory quoteFee = _quoteOperationFee(
            _dstEid,
            _payload,
            options,
            operationType
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
        // Get the chain ID from our endpoint mapping
        chainId = externalIdToChainId[_lzEid];

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

    /// @inheritdoc IMessageAdapter
    function supportsMessageOperation(
        uint16 destinationChainId,
        BridgeTypes.OperationType operationType
    ) external view returns (bool) {
        // First check if the destination chain is supported
        if (chainToExternalId[destinationChainId] == 0) {
            return false;
        }

        // Check if the adapter supports this operation type in general
        if (!supportsOperation(operationType)) {
            return false;
        }

        // For READ_STATE operations, check both global config and chain-specific support
        if (operationType == BridgeTypes.OperationType.READ_STATE) {
            return readChannelId != 0 && chainSupportsRead[destinationChainId];
        }

        // For MESSAGE operations, no additional requirements beyond chain support
        return true;
    }

    /**
     * @notice Creates dummy message parameters for fee estimation
     * @return params Dummy RelayedMessageParams for estimation
     */
    function _createDummyMessageParams()
        internal
        pure
        returns (BridgeTypes.RelayedMessageParams memory)
    {
        return
            BridgeTypes.RelayedMessageParams({
                recipient: address(0),
                message: abi.encode("dummy message for fee estimation"),
                operationId: bytes32(0),
                originator: address(0),
                sourceChainId: uint16(0)
            });
    }
}
