// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {LayerZeroOptionsHelper} from "../helpers/LayerZeroOptionsHelper.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IMessageAdapter} from "../interfaces/IMessageAdapter.sol";
import {IAssetAdapter} from "../interfaces/IAssetAdapter.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {BaseBridgeAdapter} from "../base/BaseBridgeAdapter.sol";
import {MessagingFee as EndpointFee, MessagingReceipt} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {OApp} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Bytes32AddressLib} from "solmate/src/utils/Bytes32AddressLib.sol";
import {AddressCast} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";

import {IOFT} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {MessagingFee, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";

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
    IAssetAdapter,
    ILayerZeroComposer,
    BaseBridgeAdapter
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;
    using AddressCast for address;
    using AddressCast for bytes32;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of LayerZero message hashes to operation IDs
    mapping(bytes32 guid => bytes32 operationId) public lzMessageToOperationId;

    /// @notice OFT contract address per token on THIS chain
    mapping(address token => address oft) public oftForToken;

    event OftSet(address indexed token, address indexed oft);

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
        if (_endpoint == address(0)) revert InvalidParams();
        if (_initialOwner == address(0)) revert InvalidParams();
        if (_endpointChains.length != _endpointIds.length)
            revert InvalidParams();

        // Setup chain ID to LayerZero EID mappings using base functionality
        for (uint256 i = 0; i < _endpointChains.length; i++) {
            if (_endpointIds[i] == 0) revert InvalidParams();
            _mapChainExternalId(_endpointChains[i], _endpointIds[i]);
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
        // Validate that the OFT contract is properly configured for this token
        try IOFT(oft).token() returns (address t) {
            if (t != token) revert InvalidParams();
        } catch {
            revert InvalidParams();
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
        _assertTrustedSource(
            Bytes32AddressLib.fromLast20Bytes(_origin.sender),
            relayedMessageParams.sourceChainId
        );
        IBridgeRouter(bridgeRouter()).deliver(
            BridgeTypes.OperationType.MESSAGE,
            _payload
        );
    }

    /*//////////////////////////////////////////////////////////////
                          ADAPTER INTERFACE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IAssetAdapter
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
        if (!this.supportsOperation(BridgeTypes.OperationType.TRANSFER_ASSET)) {
            revert OperationNotSupported();
        }

        address oft = oftForToken[params.asset];
        if (oft == address(0)) revert UnsupportedAsset();
        if (params.amount == 0) revert InvalidParams();

        // Pull tokens from BridgeRouter to this adapter
        IERC20(params.asset).safeTransferFrom(
            msg.sender,
            address(this),
            params.amount
        );

        // Resolve destination peer adapter via registry
        address dstAdapter = _getAdapterPeer(params.destinationChainId);
        if (dstAdapter == address(0)) revert UnsupportedChain();

        // Approve the OFT contract to spend tokens
        IERC20(params.asset).forceApprove(oft, params.amount);

        // Encode compose message if message is provided
        bytes memory composeMsg = bytes("");
        if (params.message.length > 0) {
            composeMsg = _encodeComposeTransferParams(operationId, params);
        }

        SendParam memory sendParam = SendParam({
            dstEid: _externalIdForChain(params.destinationChainId),
            to: dstAdapter.toBytes32(),
            amountLD: params.amount,
            minAmountLD: params.amount, // Require exact amount (no slippage for stablecoins)
            extraOptions: bytes(""),
            composeMsg: composeMsg,
            oftCmd: bytes("")
        });

        MessagingFee memory fee = IOFT(oft).quoteSend(sendParam, false);
        if (msg.value < fee.nativeFee) {
            revert InsufficientFee(fee.nativeFee, msg.value);
        }

        IOFT(oft).send{value: fee.nativeFee}(
            sendParam,
            fee,
            params.refundAddress
        );

        // Refund any excess native back to the designated refund address
        if (msg.value > fee.nativeFee) {
            (bool ok, ) = params.refundAddress.call{
                value: (msg.value - fee.nativeFee)
            }("");
            if (!ok) revert InsufficientBalance();
        }

        emit TransferInitiated(
            operationId,
            params.destinationChainId,
            params.asset,
            params.amount,
            params.target
        );
    }

    /// @inheritdoc IBridgeAdapter
    function estimateTransferAssets(
        BridgeTypes.ExecuteTransferParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    )
        external
        view
        onlyTrustedDestination(params.destinationChainId)
        returns (uint256 nativeFee, uint256 tokenFee)
    {
        if (!this.supportsOperation(BridgeTypes.OperationType.TRANSFER_ASSET)) {
            revert OperationNotSupported();
        }

        address oft = oftForToken[params.asset];
        if (oft == address(0)) revert UnsupportedAsset();
        if (params.amount == 0) revert InvalidParams();

        // Resolve destination adapter via registry
        address dstAdapter = _getAdapterPeer(params.destinationChainId);
        if (dstAdapter == address(0)) revert UnsupportedChain();

        // Encode compose message if message is provided
        bytes memory composeMsg = bytes("");
        if (params.message.length > 0) {
            composeMsg = _encodeComposeTransferParams(bytes32(0), params);
        }

        SendParam memory sendParam = SendParam({
            dstEid: _externalIdForChain(params.destinationChainId),
            to: dstAdapter.toBytes32(),
            amountLD: params.amount,
            minAmountLD: params.amount, // Require exact amount (no slippage for stablecoins)
            extraOptions: bytes(""),
            composeMsg: composeMsg,
            oftCmd: bytes("")
        });

        MessagingFee memory fee = IOFT(oft).quoteSend(sendParam, false);
        return (fee.nativeFee, fee.lzTokenFee);
    }

    /// @inheritdoc IBridgeAdapter
    function estimateSendMessage(
        BridgeTypes.ExecuteSendMessageParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    )
        external
        view
        onlyTrustedDestination(params.destinationChainId)
        returns (uint256 nativeFee, uint256 tokenFee)
    {
        if (!supportsOperation(BridgeTypes.OperationType.MESSAGE)) {
            revert OperationNotSupported();
        }

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
                             LAYERZERO COMPOSE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Handles composed messages from LayerZero after OFT token delivery
     * @dev Called by LayerZero endpoint after tokens are delivered via OFT
     * @param _from The originating OApp (should be destination OFT contract)
     * @param _message OFT-encoded compose message from OFT
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
        ) = _decodeOFTCompose(_message);

        // Decode transfer parameters from compose message
        BridgeTypes.RelayedTransferParams
            memory params = _decodeRelayedTransferParams(composeMsg);

        // Ensure the LayerZero srcEid maps to the same chain as encoded in the payload
        uint16 chainFromEid = _chainIdFromExternalId(srcEid);

        // Validate the source adapter relationship using the mapped chain ID
        _assertTrustedSource(composeFrom, chainFromEid);

        _validateSourceChainId(params.sourceChainId, chainFromEid);

        // Use the minted amount from OFT compose header as authoritative
        params.amount = amountLD;

        // Ensure the asset is supported
        if (oftForToken[params.asset] == address(0)) revert UnsupportedAsset();

        // Check that we have the expected amount of tokens
        uint256 bal = IERC20(params.asset).balanceOf(address(this));
        if (bal < params.amount) revert InsufficientBalance();

        // Move tokens to router, which will forward to recipient during deliver
        IERC20(params.asset).safeTransfer(bridgeRouter(), params.amount);

        // Deliver through router
        IBridgeRouter(bridgeRouter()).deliver(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            _encodeRelayedTransferParams(params)
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
        return _externalIdForChain(chainId);
    }

    /**
     * @notice Creates LayerZero options with appropriate gas limits
     * @param options User-provided bridge options
     * @return lzOptions The prepared LayerZero options
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

    /// @inheritdoc IBridgeAdapter
    function supportsOperation(
        BridgeTypes.OperationType operationType
    ) public pure override returns (bool) {
        // LayerZero adapter supports both messaging and asset transfer operations
        return
            operationType == BridgeTypes.OperationType.MESSAGE ||
            operationType == BridgeTypes.OperationType.TRANSFER_ASSET;
    }

    /// @inheritdoc IAssetAdapter
    function supportsAssetTransfer(
        uint16 destinationChainId,
        address asset
    ) external view returns (bool) {
        return
            oftForToken[asset] != address(0) &&
            _hasTrustedDestination(destinationChainId);
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

    /*//////////////////////////////////////////////////////////////
                             COMPOSE HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Decode OFT compose message header and payload
     * @param message The OFT-encoded compose message
     * @return srcEid Source endpoint ID
     * @return amountLD Amount in local decimals
     * @return composeFrom Address that sent the compose message
     * @return composeMsg The composed message payload
     */
    function _decodeOFTCompose(
        bytes calldata message
    )
        internal
        pure
        returns (
            uint32 srcEid,
            uint256 amountLD,
            address composeFrom,
            bytes memory composeMsg
        )
    {
        // Sanity-check the OFT compose header is fully present before decoding.
        // Layout (ABI-aligned as produced by OFTComposeMsgCodec):
        //  - 8B nonce | 4B srcEid                                   (total so far: 12 bytes)
        //  - 32B amountLD                                           (total so far: 44 bytes)
        //  - 32B composeFrom (left-padded address, present when composeMsg != empty)
        // Minimum length when composeFrom is present: 12 + 32 + 32 = 76 bytes.
        // A valid message must have additional compose message data beyond the header.
        if (message.length <= 76) revert InvalidMessage();

        // Use official codec for extraction
        srcEid = OFTComposeMsgCodec.srcEid(message);
        amountLD = OFTComposeMsgCodec.amountLD(message);
        composeMsg = OFTComposeMsgCodec.composeMsg(message);
        composeFrom = OFTComposeMsgCodec.composeFrom(message).toAddress();
    }

    /**
     * @dev Encode transfer parameters for OFT compose message
     * @param operationId Router-provided operation ID
     * @param params Transfer parameters
     * @return Encoded compose message payload
     */
    function _encodeComposeTransferParams(
        bytes32 operationId,
        BridgeTypes.ExecuteTransferParams calldata params
    ) internal view returns (bytes memory) {
        BridgeTypes.RelayedTransferParams memory relayedParams = BridgeTypes
            .RelayedTransferParams({
                operationId: operationId,
                originator: params.originator,
                sourceChainId: uint16(block.chainid),
                recipient: params.target,
                asset: params.asset,
                amount: params.amount,
                message: params.message
            });

        return abi.encode(relayedParams);
    }
}
