// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {LayerZeroOptionsHelper} from "../helpers/LayerZeroOptionsHelper.sol";
import {LayerZeroMessagingHelper} from "../helpers/LayerZeroMessagingHelper.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
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

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of LayerZero message hashes to operation IDs
    mapping(bytes32 guid => bytes32 operationId) public lzMessageToOperationId;

    /// @notice Governance cap for number of DVNs allowed in read config
    /// @dev Practical deployments typically use a small DVN set (e.g. 1-3).
    ///      This cap avoids overly large configurations and removes magic numbers.
    uint8 public constant MAX_SUPPORTED_DVNS = 8;

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
        for (uint256 i = 0; i < _endpointChains.length; ) {
            if (_endpointIds[i] == 0) revert InvalidEndpointId();
            _mapChainExternalId(_endpointChains[i], _endpointIds[i]);
            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            OAPP RECEIVER
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Receives messages from LayerZero
     * @param _origin Source chain information
     * @param //_guid Global unique identifier for tracking the packet
     * @param _payload Message payload
     * @param // _executor Address of the executor
     * @param // _extraData Additional data provided by the executor
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 /* _guid */,
        bytes calldata _payload,
        address,
        bytes calldata
    ) internal override {
        // Payload must contain at least 2 bytes for operation type prefix
        if (_payload.length < 2) {
            revert UnsupportedMessageType();
        }

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
    }

    /**
     * @notice Handles incoming messages from LayerZero operations
     * @dev Implements a two-layer security model for message validation:
     *      1. Chain ID validation: Ensures the external endpoint ID maps to the expected source chain
     *      2. Peer validation: Ensures the source adapter address is registered as a trusted peer in the CrossChainRegistry
     *      This defense-in-depth approach protects against misconfigured endpoints and unauthorized adapters.
     *      LayerZero's Origin.sender is the remote OApp address cryptographically proven by DVNs.
     * @param _origin Source chain information from LayerZero (includes srcEid and sender address)
     * @param _payload Decoded message payload containing RelayedMessageParams
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
        address srcAdapter = Bytes32AddressLib.fromLast20Bytes(_origin.sender);
        if (
            !_validateTrustedSource(
                srcAdapter,
                relayedMessageParams.sourceChainId
            )
        ) {
            revert UntrustedSourceAdapter(
                srcAdapter,
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
        // Cache LayerZero EID to avoid redundant storage reads
        uint32 lzDstEid = _getLayerZeroEid(params.destinationChainId);
        bytes32 dummyBytes32 = bytes32(uint256(uint160(params.target)));

        // Create realistic payload using LayerZeroMessagingHelper
        bytes memory payload = _createMessagePayload(
            LayerZeroMessagingHelper.createRelayedMessageParams(
                params,
                dummyBytes32
            )
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
        // Cache LayerZero EID to avoid redundant storage reads
        uint32 lzDstEid = _getLayerZeroEid(params.destinationChainId);

        // Validate fee requirements using helper
        LayerZeroMessagingHelper.validateFeeRequirements(options, msg.value);

        // Create payload using LayerZeroMessagingHelper
        bytes memory payload = _createMessagePayload(
            LayerZeroMessagingHelper.createRelayedMessageParams(
                params,
                operationId
            )
        );
        bytes memory lzOptions = _createLzOptions(options);

        // Handle payment based on fee type
        MessagingReceipt memory receipt;
        if (options.payInProtocolToken) {
            receipt = _handleProtocolTokenPayment(
                operationId,
                params,
                lzDstEid,
                payload,
                lzOptions
            );
        } else {
            receipt = _handleNativePayment(
                lzDstEid,
                payload,
                lzOptions,
                params.refundAddress
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
        // Cache storage read and combine checks for gas efficiency
        uint32 externalId = chainToExternalId[destinationChainId];
        return
            externalId != 0 &&
            operationType == BridgeTypes.OperationType.MESSAGE;
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
     * @notice Handles protocol token fee payment flow
     * @dev This function manages the complete protocol token payment process including:
     *      - Fee quotation from LayerZero
     *      - Token collection from the fee payer
     *      - Allowance management for the LayerZero endpoint
     *      - Message sending with token fees
     * @param operationId The operation ID for this transaction
     * @param params ExecuteSendMessageParams from the bridge operation
     * @param lzDstEid LayerZero destination endpoint ID
     * @param payload The encoded message payload
     * @param lzOptions LayerZero options for the message
     * @return receipt MessagingReceipt from LayerZero
     */
    function _handleProtocolTokenPayment(
        bytes32 operationId,
        BridgeTypes.ExecuteSendMessageParams calldata params,
        uint32 lzDstEid,
        bytes memory payload,
        bytes memory lzOptions
    ) internal returns (MessagingReceipt memory) {
        EndpointFee memory quoted = _quote(lzDstEid, payload, lzOptions, true);
        if (quoted.nativeFee != 0)
            revert InsufficientMsgValue(0, quoted.nativeFee);
        uint256 tokenFeeRequired = quoted.lzTokenFee;

        _collectProtocolTokenFee(
            operationId,
            params.refundAddress,
            tokenFeeRequired
        );
        _ensureSufficientAllowance(tokenFeeRequired, address(endpoint));

        MessagingReceipt memory receipt = _lzSend(
            lzDstEid,
            payload,
            lzOptions,
            EndpointFee(0, tokenFeeRequired),
            payable(params.refundAddress)
        );

        emit ProtocolFeeSpent(operationId, protocolFeeToken, tokenFeeRequired);

        return receipt;
    }

    /**
     * @notice Handles native fee payment flow
     * @dev This function manages the native token payment process for LayerZero messaging
     * @param lzDstEid LayerZero destination endpoint ID
     * @param payload The encoded message payload
     * @param lzOptions LayerZero options for the message
     * @param refundAddress Address to receive any refunds
     * @return receipt MessagingReceipt from LayerZero
     */
    function _handleNativePayment(
        uint32 lzDstEid,
        bytes memory payload,
        bytes memory lzOptions,
        address refundAddress
    ) internal returns (MessagingReceipt memory) {
        return
            _lzSend(
                lzDstEid,
                payload,
                lzOptions,
                EndpointFee(msg.value, 0),
                payable(refundAddress)
            );
    }
}
