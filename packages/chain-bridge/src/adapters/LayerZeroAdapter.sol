// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {LayerZeroOptionsHelper} from "../helpers/LayerZeroOptionsHelper.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IMessageAdapter} from "../interfaces/IMessageAdapter.sol";
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
