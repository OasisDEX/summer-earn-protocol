// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {LayerZeroOptionsHelper} from "../helpers/LayerZeroOptionsHelper.sol";
import {LayerZeroComposeHelper} from "../helpers/LayerZeroComposeHelper.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IMessageAdapter} from "../interfaces/IMessageAdapter.sol";
import {IAssetAdapter} from "../interfaces/IAssetAdapter.sol";
import {ILayerZeroAdapter} from "../interfaces/ILayerZeroAdapter.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {BridgeMessagingHelper} from "../libraries/BridgeMessagingHelper.sol";
import {BaseBridgeAdapter} from "../base/BaseBridgeAdapter.sol";
import {MessagingFee as EndpointFee, MessagingReceipt} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {OApp} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Bytes32AddressLib} from "solmate/src/utils/Bytes32AddressLib.sol";
import {AddressCast} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";

import {IOFT} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {MessagingFee, SendParam, MessagingReceipt as OFTMessagingReceipt, OFTReceipt} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

/**
 * @title LayerZeroAdapter
 * @notice Adapter for the LayerZero bridge protocol
 * @dev Implements IMessageAdapter and IBridgeAdapter interfaces and connects to LayerZero's messaging service using OApp standard
 */
contract LayerZeroAdapter is
    OApp,
    IMessageAdapter,
    IBridgeAdapter,
    IAssetAdapter,
    ILayerZeroComposer,
    ILayerZeroAdapter,
    BaseBridgeAdapter
{
    using SafeERC20 for IERC20;
    using AddressCast for address;
    using OptionsBuilder for bytes;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of LayerZero message hashes to operation IDs
    mapping(bytes32 guid => bytes32 operationId) public lzMessageToOperationId;

    /// @notice OFT contract address per token on THIS chain
    mapping(address token => address oft) public oftForToken;

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
                             GOVERNANCE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set the OFT contract address for a token
     * @param token The ERC20 token address
     * @param oft The LayerZero OFT contract address for this token
     */
    function setOftForToken(address token, address oft) external onlyGovernor {
        if (token == address(0) || oft == address(0)) revert InvalidParams();

        // Validate OFT configuration - supports both adapter and direct patterns
        // Adapter pattern: IOFT(oft).token() returns the underlying ERC20
        // Direct pattern: IOFT(oft).token() returns oft itself, or may not exist
        try IOFT(oft).token() returns (address t) {
            // For adapter pattern: token must match the underlying asset
            // For direct pattern: token must equal oft
            if (t != token && t != oft) revert InvalidParams();
        } catch {
            // Direct OFT may not have token() function
            // Verify it's a direct implementation by checking if token == oft
            if (token != oft) revert InvalidParams();
        }

        oftForToken[token] = oft;
        emit OftSet(token, oft);
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
        ) = BridgeMessagingHelper.decodePayload(_payload);

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
            memory relayedMessageParams = BridgeMessagingHelper
                .decodeRelayedMessageParams(_payload);
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

    /// @inheritdoc IAssetAdapter
    /**
     * @dev Transfers assets cross-chain using LayerZero OFT protocol.
     *      Supports both OFT patterns:
     *      - Adapter pattern: pull tokens → approve OFT → send via OFT
     *      - Direct pattern: pull tokens → send via OFT (no approval needed)
     *      If message is provided, encodes as OFT compose for post-delivery execution.
     * @param operationId Unique identifier for this transfer operation
     * @param params Transfer parameters (asset, amount, destination, optional message)
     */
    function transferAsset(
        bytes32 operationId,
        BridgeTypes.ExecuteTransferParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    )
        external
        payable
        onlyTrustedDestination(params.destinationChainId)
        onlyRouter
        nonReentrant
    {
        // 1. Prepare OFT transfer parameters
        (address oft, SendParam memory sendParam) = _prepareOFTTransfer(
            params,
            operationId,
            options
        );

        // 2. Pull tokens
        IERC20(params.asset).safeTransferFrom(
            msg.sender,
            address(this),
            params.amount
        );

        // 3. Approve OFT (only needed for adapter pattern where asset != oft)
        if (params.asset != oft) {
            IERC20(params.asset).forceApprove(oft, params.amount);
        }

        // 4. Validate payment mode consistency
        // Only reject if protocol token payment is requested AND protocol token is set AND native value is provided
        if (
            options.payInProtocolToken &&
            protocolFeeToken != address(0) &&
            options.msgValue != 0
        ) {
            revert InvalidParams();
        }

        // 5. Handle payment based on fee type
        if (options.payInProtocolToken && protocolFeeToken != address(0)) {
            _handleOFTProtocolTokenPayment(
                operationId,
                params,
                oft,
                sendParam,
                options
            );
        } else {
            _handleOFTNativePayment(params, oft, sendParam);
        }

        // 5. Emit event
        emit TransferInitiated(
            operationId,
            params.destinationChainId,
            params.asset,
            params.amount,
            params.target
        );
    }

    /// @inheritdoc IAssetAdapter
    function estimateTransferAssets(
        BridgeTypes.ExecuteTransferParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    )
        external
        view
        onlyTrustedDestination(params.destinationChainId)
        returns (uint256 nativeFee, uint256 tokenFee)
    {
        (address oft, SendParam memory sendParam) = _prepareOFTTransfer(
            params,
            bytes32(0),
            options
        );
        MessagingFee memory fee = IOFT(oft).quoteSend(
            sendParam,
            options.payInProtocolToken
        );

        return (fee.nativeFee, fee.lzTokenFee);
    }

    /// @inheritdoc IMessageAdapter
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

        // Create realistic payload using BridgeMessagingHelper
        bytes memory payload = _createMessagePayload(
            BridgeMessagingHelper.createRelayedMessageParams(
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

        // Validate fee requirements
        if (options.msgValue > 0 && msg.value < options.msgValue) {
            revert InsufficientMsgValue(options.msgValue, msg.value);
        }

        // Create payload using BridgeMessagingHelper
        bytes memory payload = _createMessagePayload(
            BridgeMessagingHelper.createRelayedMessageParams(
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
                lzOptions,
                options
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
                             LAYERZERO COMPOSE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Handles composed messages after OFT token delivery
     * @dev Called by LayerZero endpoint after OFT tokens arrive on destination.
     *      Security model:
     *      1. Endpoint auth: Only LayerZero endpoint can call
     *      2. OApp validation: _from must be the expected OFT contract for the asset
     *      3. Peer validation: composeFrom must be trusted adapter
     *      4. Chain validation: srcEid must map to expected source chain
     *      OFT delivers tokens first, then triggers this with transfer metadata.
     * @param _from The OApp address that sent the compose message (should be OFT contract)
     * @param _message OFT-encoded compose (srcEid, amount, composeFrom, transferParams)
     */
    function lzCompose(
        address _from,
        bytes32 /* _guid */,
        bytes calldata _message,
        address /* _caller */,
        bytes calldata /* _extraData */
    ) external payable override nonReentrant {
        // Verify caller is LayerZero endpoint
        if (msg.sender != address(endpoint)) revert Unauthorized();

        // Decode OFT compose payload
        (
            uint32 srcEid,
            uint256 amountLD,
            address composeFrom,
            bytes memory composeMsg
        ) = LayerZeroComposeHelper.decodeOFTCompose(_message);

        // Decode transfer parameters from compose message
        BridgeTypes.RelayedTransferParams memory params = BridgeMessagingHelper
            .decodeRelayedTransferParams(composeMsg);

        // Validate OApp address matches expected OFT for this asset
        address expectedOFT = oftForToken[params.asset];
        if (expectedOFT == address(0)) revert UnsupportedAsset();
        if (_from != expectedOFT) revert UntrustedOApp(_from, expectedOFT);

        // Ensure the LayerZero srcEid maps to the same chain as encoded in the payload
        uint16 chainFromEid = _chainIdFromExternalId(srcEid);

        // Validate that the srcEid maps to the same chain as encoded in the payload
        _validateSourceChainId(chainFromEid, params.sourceChainId);

        // Validate the source adapter relationship using the mapped chain ID
        if (!_validateTrustedSource(composeFrom, chainFromEid)) {
            revert UntrustedSourceAdapter(composeFrom, chainFromEid);
        }

        // Use the minted amount from OFT compose header as authoritative
        params.amount = amountLD;

        // Ensure the asset is supported
        address oft = oftForToken[params.asset];
        if (oft == address(0)) revert UnsupportedAsset();

        // Check that we have the expected amount of tokens
        uint256 bal = IERC20(params.asset).balanceOf(address(this));
        if (bal < params.amount) revert InsufficientBalance();

        // Move tokens to router, which will forward to recipient during deliver
        IERC20(params.asset).safeTransfer(bridgeRouter(), params.amount);

        // Deliver through router
        IBridgeRouter(bridgeRouter()).deliver(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            BridgeMessagingHelper.encodeRelayedTransferParams(params)
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

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validates asset and amount, returns OFT contract
     * @param asset The ERC20 token address
     * @param amount The amount to transfer
     * @return oft The OFT contract address for this asset
     */
    function _resolveOFTForAsset(
        address asset,
        uint256 amount
    ) internal view returns (address oft) {
        oft = oftForToken[asset];
        if (oft == address(0)) revert UnsupportedAsset();
        if (amount == 0) revert InvalidParams();
    }

    /**
     * @notice Internal helper to prepare OFT transfer parameters
     * @param params Transfer parameters
     * @param operationId Operation ID (use bytes32(0) for estimation)
     * @param options Bridge options containing gas limit and other parameters
     * @return oft OFT contract address
     * @return sendParam Prepared send parameters
     */
    function _prepareOFTTransfer(
        BridgeTypes.ExecuteTransferParams calldata params,
        bytes32 operationId,
        BridgeTypes.BridgeOptions calldata options
    ) internal view returns (address oft, SendParam memory sendParam) {
        oft = _resolveOFTForAsset(params.asset, params.amount);
        uint32 dstEid = _externalIdForChain(params.destinationChainId);
        address dstAdapter = _resolveAdapterPeer(params.destinationChainId);

        bytes memory composeMsg = BridgeMessagingHelper
            .encodeRelayedTransferParams(
                BridgeMessagingHelper.createRelayedTransferParams(
                    params,
                    operationId
                )
            );

        sendParam = _createOFTSendParam(
            dstEid,
            dstAdapter,
            params.amount,
            composeMsg,
            options
        );
    }

    /**
     * @notice Creates OFT SendParam struct
     * @param dstEid Destination endpoint ID (pre-computed)
     * @param dstAdapter Destination adapter address
     * @param amount Amount to send in local decimals
     * @param composeMsg Optional compose message
     * @param options Bridge options containing gas limit and other parameters
     * @return sendParam Configured SendParam struct
     */
    function _createOFTSendParam(
        uint32 dstEid,
        address dstAdapter,
        uint256 amount,
        bytes memory composeMsg,
        BridgeTypes.BridgeOptions memory options
    ) internal pure returns (SendParam memory) {
        uint128 gasLimit = uint128(_requireGasLimit(options.gasLimit));

        // Always include both lzReceive and lzCompose options
        // Use full gas limit for both - LayerZero only charges for actual usage
        bytes memory extraOptions = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(gasLimit, options.msgValue)
            .addExecutorLzComposeOption(0, gasLimit, 0);

        return
            SendParam({
                dstEid: dstEid,
                to: dstAdapter.toBytes32(),
                amountLD: amount,
                minAmountLD: amount, // Exact amount, no slippage
                extraOptions: extraOptions,
                composeMsg: composeMsg,
                oftCmd: bytes("")
            });
    }

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
        return BridgeMessagingHelper.encodeRelayedMessageParamsWithType(params);
    }

    /**
     * @notice Override the base class implementation to define LayerZero-specific operation support
     * @param operationType The operation type to check
     * @return true if the operation is supported
     */
    function _supportsOperation(
        BridgeTypes.OperationType operationType
    ) internal pure override returns (bool) {
        // LayerZero adapter supports both messaging and asset transfer operations
        return
            operationType == BridgeTypes.OperationType.MESSAGE ||
            operationType == BridgeTypes.OperationType.TRANSFER_ASSET;
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
        bytes memory lzOptions,
        BridgeTypes.BridgeOptions calldata options
    ) internal returns (MessagingReceipt memory) {
        EndpointFee memory quoted = _quote(lzDstEid, payload, lzOptions, true);
        if (quoted.nativeFee != 0)
            revert InsufficientMsgValue(0, quoted.nativeFee);
        uint256 tokenFeeRequired = quoted.lzTokenFee;

        // Validate that user-provided fee amount matches quoted fee
        if (options.feeTokenAmount != tokenFeeRequired) {
            revert InsufficientFee(tokenFeeRequired, options.feeTokenAmount);
        }

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

    /**
     * @notice Handles protocol token fee payment flow for OFT transfers
     * @dev This function manages the complete protocol token payment process for OFT transfers including:
     *      - Fee quotation from OFT with token payment
     *      - Token collection from the fee payer
     *      - Allowance management for the OFT contract
     *      - OFT sending with token fees
     * @param operationId The operation ID for this transfer
     * @param params ExecuteTransferParams from the bridge operation
     * @param oft The OFT contract address
     * @param sendParam Prepared send parameters for OFT
     */
    function _handleOFTProtocolTokenPayment(
        bytes32 operationId,
        BridgeTypes.ExecuteTransferParams calldata params,
        address oft,
        SendParam memory sendParam,
        BridgeTypes.BridgeOptions calldata options
    ) internal {
        // Quote with token payment enabled
        MessagingFee memory fee = IOFT(oft).quoteSend(sendParam, true);

        // Validate that native fee is zero when paying in token
        if (fee.nativeFee != 0) {
            revert InsufficientFee(0, fee.nativeFee);
        }

        uint256 tokenFeeRequired = fee.lzTokenFee;

        // Validate that user-provided fee amount matches quoted fee
        if (options.feeTokenAmount != tokenFeeRequired) {
            revert InsufficientFee(tokenFeeRequired, options.feeTokenAmount);
        }

        // Collect protocol token fee from the caller
        _collectProtocolTokenFee(
            operationId,
            params.refundAddress,
            tokenFeeRequired
        );

        // Ensure sufficient allowance for the OFT contract
        _ensureSufficientAllowance(tokenFeeRequired, oft);

        // Send with token payment (no native value required)
        IOFT(oft).send{value: 0}(
            sendParam,
            MessagingFee(0, tokenFeeRequired),
            params.refundAddress
        );

        // Refund any provided native value fully (since nativeFee == 0)
        _refundNative(params.refundAddress, msg.value);

        // Emit protocol fee spent event
        emit ProtocolFeeSpent(operationId, protocolFeeToken, tokenFeeRequired);
    }

    /**
     * @notice Handles native fee payment flow for OFT transfers
     * @dev This function manages the native token payment process for OFT transfers
     * @param params ExecuteTransferParams from the bridge operation
     * @param oft The OFT contract address
     * @param sendParam Prepared send parameters for OFT
     */
    function _handleOFTNativePayment(
        BridgeTypes.ExecuteTransferParams calldata params,
        address oft,
        SendParam memory sendParam
    ) internal {
        // Quote with native payment
        MessagingFee memory fee = IOFT(oft).quoteSend(sendParam, false);

        // Validate sufficient native fee
        if (msg.value < fee.nativeFee) {
            revert InsufficientFee(fee.nativeFee, msg.value);
        }

        // Send with native payment
        IOFT(oft).send{value: fee.nativeFee}(
            sendParam,
            fee,
            params.refundAddress
        );

        // Refund excess native value
        if (msg.value > fee.nativeFee) {
            uint256 excess = msg.value - fee.nativeFee;
            _refundNative(params.refundAddress, excess);
        }
    }
}
