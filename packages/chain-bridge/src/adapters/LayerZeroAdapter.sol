// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {LayerZeroOptionsHelper} from "../helpers/LayerZeroOptionsHelper.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IBridgeTokenFeeSupport} from "../interfaces/IBridgeTokenFeeSupport.sol";
import {IMessageAdapter} from "../interfaces/IMessageAdapter.sol";
import {ILayerZeroAdapter} from "../interfaces/ILayerZeroAdapter.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {BaseBridgeAdapter} from "../base/BaseBridgeAdapter.sol";
import {MessagingFee as EndpointFee, MessagingReceipt} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {OApp} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Bytes32AddressLib} from "solmate/src/utils/Bytes32AddressLib.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title LayerZeroAdapter
 * @notice Adapter for the LayerZero bridge protocol
 * @dev Implements IMessageAdapter and IBridgeAdapter interfaces and connects to LayerZero's messaging service using OApp standard
 */
contract LayerZeroAdapter is
    OApp,
    IMessageAdapter,
    IBridgeAdapter,
    ILayerZeroAdapter,
    BaseBridgeAdapter
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Error thrown when the LayerZero endpoint is invalid
    error InvalidEndpoint();

    /// @notice Error thrown when the initial owner is invalid
    error InvalidOwner();

    /// @notice Error thrown when array lengths don't match
    error ArrayLengthMismatch();

    /// @notice Error thrown when an endpoint ID is invalid
    error InvalidEndpointId();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of LayerZero message hashes to operation IDs
    mapping(bytes32 guid => bytes32 operationId) public lzMessageToOperationId;

    /// @notice Binds a read response guid to the originally requested destination chain
    /// @dev Used to enforce registry trust checks for read-channel responses
    mapping(bytes32 guid => uint16 expectedChainId)
        public expectedReadChainByGuid;

    /// @notice Threshold used to distinguish LayerZero lzRead responses by `srcEid`
    /// @dev LayerZero routes read responses through a reserved "read channel" range
    ///      near the top of the uint32 EID space (commonly with READ_CHANNEL_ID at
    ///      4294967295). Any `srcEid` strictly greater than this threshold is treated
    ///      as a read response. This value is set at deploy time to allow
    ///      forward-compatibility and testing across different environments.
    uint32 public immutable readChannelThreshold;

    /// @notice Active read channel ID for sending read requests
    uint32 public readChannelId;

    /// @notice Number of block confirmations required for read operations
    /// @dev Set via configureReadDVNs and used in _createReadStatePayload
    uint16 public readConfirmations;

    /// @notice Governance cap for number of DVNs allowed in read config
    /// @dev Practical deployments typically use a small DVN set (e.g. 1-3).
    ///      This cap avoids overly large configurations and removes magic numbers.
    uint8 public constant MAX_SUPPORTED_DVNS = 8;

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
     * @param _initialOwner Owner for Ownable/OApp
     */
    constructor(
        address _endpoint,
        address _crossChainRegistry,
        address _accessManager,
        uint16[] memory _endpointChains,
        uint32[] memory _endpointIds,
        address _initialOwner
    )
        OApp(_endpoint, _initialOwner)
        Ownable(_initialOwner)
        BaseBridgeAdapter(_crossChainRegistry, _accessManager)
    {
        if (_endpoint == address(0)) revert InvalidEndpoint();
        if (_initialOwner == address(0)) revert InvalidOwner();
        if (_endpointChains.length != _endpointIds.length)
            revert ArrayLengthMismatch();

        // Setup chain ID to LayerZero EID mappings using base functionality
        for (uint256 i = 0; i < _endpointChains.length; i++) {
            if (_endpointIds[i] == 0) revert InvalidEndpointId();
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
        setReadChannel(readChannelId, false);
        readChannelId = _readChannelId;
        setReadChannel(_readChannelId, true);
        emit ReadChannelActivated(_readChannelId);
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
        if (readLib1002Address == address(0)) revert InvalidParams();

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
     * @param executor Address of the executor for read operations
     * @param confirmations Number of block confirmations required for read operations
     * @dev Must be called to enable read operations with proper DVN and executor configuration
     */
    function configureReadDVNs(
        address readLib1002Address,
        address[] memory readDVNs,
        address executor,
        uint16 confirmations
    ) external onlyGovernor {
        if (readChannelId == 0) revert ReadChannelNotConfigured();
        if (readDVNs.length == 0) revert InvalidParams();
        if (readDVNs.length > MAX_SUPPORTED_DVNS) revert InvalidParams();
        if (readLib1002Address == address(0)) revert InvalidParams();
        if (executor == address(0)) revert InvalidParams();

        // Verify DVNs are sorted (required by LayerZero)
        for (uint256 i = 0; i < readDVNs.length; i++) {
            if (readDVNs[i] == address(0)) revert InvalidParams();
            if (i == 0) continue;
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

        // Store confirmations for use in read operations
        readConfirmations = confirmations;

        // Configure read library for read channel
        endpoint.setConfig(address(this), readLib1002Address, params);

        emit ReadDVNsConfigured(readChannelId, readDVNs, confirmations);
    }

    /**
     * @notice Configure read support for specific chains
     * @param chainId The chain ID to configure
     * @param supported Whether read operations are supported on this chain
     * @dev Can only be called by the governor
     */
    function setChainReadSupport(
        uint16 chainId,
        bool supported
    ) external onlyGovernor {
        chainSupportsRead[chainId] = supported;
        emit ChainReadSupportUpdated(chainId, supported);
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
        if (_payload.length >= 2) {
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
     * @dev Handles messages from LayerZero operations
     * @param _origin Source chain information
     * @param _payload Message payload
     */
    function _relayMessage(
        Origin calldata _origin,
        bytes memory _payload
    ) internal {
        BridgeTypes.RelayedMessageParams
            memory relayedMessageParams = _decodeRelayedMessageParams(_payload);
        _validateSourceChainId(
            externalIdToChainId[_origin.srcEid],
            relayedMessageParams.sourceChainId
        );
        // Defense-in-depth: bind the source OApp identity to the registry-declared peer.
        // LayerZero's Origin.sender is the remote OApp address proven by DVNs.
        // Ensure governance has registered that OApp as our peer for the source chain.
        if (
            !_validateTrustedSource(
                Bytes32AddressLib.fromLast20Bytes(_origin.sender),
                relayedMessageParams.sourceChainId
            )
        ) {
            revert UntrustedSourceAdapter(
                Bytes32AddressLib.fromLast20Bytes(_origin.sender),
                relayedMessageParams.sourceChainId
            );
        }
        IBridgeRouter(bridgeRouter()).deliver(
            BridgeTypes.OperationType.MESSAGE,
            _payload
        );
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL INTERFACE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBridgeAdapter
    function estimateTransferAssets(
        BridgeTypes.ExecuteTransferParams calldata /* params */,
        BridgeTypes.BridgeOptions calldata /* options */
    ) external pure returns (uint256, /* nativeFee */ uint256 /* tokenFee */) {
        revert OperationNotSupported();
    }

    /// @inheritdoc IBridgeAdapter
    function estimateSendMessage(
        BridgeTypes.ExecuteSendMessageParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    )
        external
        view
        onlyTrustedDestination(params.destinationChainId)
        withSupportedOperation(BridgeTypes.OperationType.MESSAGE)
        returns (uint256 nativeFee, uint256 tokenFee)
    {
        uint32 lzDstEid = _getLayerZeroEid(params.destinationChainId);
        bytes32 dummyBytes32 = bytes32(uint256(uint160(params.target)));

        // Create realistic payload using actual parameters
        bytes memory payload = _createMessagePayload(
            BridgeTypes.RelayedMessageParams({
                recipient: params.target,
                message: params.message,
                operationId: dummyBytes32,
                originator: params.originator,
                sourceChainId: uint16(block.chainid)
            })
        );

        bytes memory lzOptions = _createLzOptions(options);

        EndpointFee memory fee = _quote(lzDstEid, payload, lzOptions, false);

        return (fee.nativeFee, fee.lzTokenFee);
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
        bytes memory lzOptions = _createLzOptions(options);

        // Send message through OApp's _lzSend
        // Use params.refundAddress which is set to the keeper who initiated the transaction
        MessagingReceipt memory receipt;
        if (options.payInProtocolToken) {
            EndpointFee memory quoted = _quote(
                lzDstEid,
                payload,
                lzOptions,
                true
            );
            if (quoted.nativeFee != 0)
                revert InsufficientMsgValue(0, quoted.nativeFee);
            uint256 tokenFeeRequired = quoted.lzTokenFee;

            _collectProtocolTokenFee(
                operationId,
                params.refundAddress,
                tokenFeeRequired
            );
            _ensureSufficientAllowance(tokenFeeRequired, address(endpoint));

            receipt = _lzSend(
                lzDstEid,
                payload,
                lzOptions,
                EndpointFee(0, tokenFeeRequired),
                payable(params.refundAddress)
            );
            emit ProtocolFeeSpent(
                operationId,
                protocolFeeToken,
                tokenFeeRequired
            );
        } else {
            receipt = _lzSend(
                lzDstEid,
                payload,
                lzOptions,
                EndpointFee(msg.value, 0),
                payable(params.refundAddress)
            );
        }

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
                        PUBLIC INTERFACE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBridgeAdapter
    function supportsOperation(
        BridgeTypes.OperationType operationType
    ) public pure override returns (bool) {
        return _supportsOperation(operationType);
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

        // Only MESSAGE is supported
        return operationType == BridgeTypes.OperationType.MESSAGE;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
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
        return _externalIdForChain(chainId);
    }

    /**
     * @notice Creates LayerZero options with appropriate gas limits
     * @param options User-provided bridge options
     * 
     @return lzOptions The prepared LayerZero options
     */
    function _createLzOptions(
        BridgeTypes.BridgeOptions memory options
    ) internal pure returns (bytes memory) {
        uint128 gasLimit = uint128(_requireGasLimit(options.gasLimit));
        return LayerZeroOptionsHelper.createMessagingOptions(options, gasLimit);
    }

    /**
     * @notice Creates a message payload for LayerZero operations
     * @param params Message parameters
     * @return payload Encoded message payload
     */
    function _createMessagePayload(
        BridgeTypes.RelayedMessageParams memory params
    ) internal pure returns (bytes memory payload) {
        return _encodeRelayedMessageParamsWithType(params);
    }

    /**
     * @notice Override the base class implementation to define LayerZero-specific operation support
     * @param operationType The operation type to check
     * @return true if the operation is supported
     */
    function _supportsOperation(
        BridgeTypes.OperationType operationType
    ) internal pure override returns (bool) {
        // LayerZero adapter now only supports messaging operations
        return operationType == BridgeTypes.OperationType.MESSAGE;
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
