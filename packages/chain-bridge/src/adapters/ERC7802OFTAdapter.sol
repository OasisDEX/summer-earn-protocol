// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AddressCast} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";

import {IOFT} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {MessagingFee, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";

import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {BaseERC7802Adapter} from "./BaseERC7802Adapter.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";

/**
 * @title ERC7802OFTAdapter
 * @notice ERC-7802 adapter using direct LayerZero OFT protocol
 * @dev For tokens like USDT0 that implement LayerZero OFT natively
 */
contract ERC7802OFTAdapter is BaseERC7802Adapter, ILayerZeroComposer {
    using SafeERC20 for IERC20;
    using AddressCast for address;
    using AddressCast for bytes32;

    /// @notice LayerZero endpoint for compose functionality
    address public immutable LZ_ENDPOINT;

    /// @notice OFT contract address per token on THIS chain
    mapping(address token => address oft) public oftForToken;

    event OftSet(address indexed token, address indexed oft);

    constructor(
        address _crossChainRegistry,
        address _accessManager,
        address _lzEndpoint
    ) BaseERC7802Adapter(_crossChainRegistry, _accessManager) {
        if (_lzEndpoint == address(0)) revert InvalidParams();
        LZ_ENDPOINT = _lzEndpoint;
    }

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

    /**
     * @dev Direct LayerZero OFT transfer implementation with optional compose support
     */
    function _sendTransport(
        bytes32 operationId,
        address token,
        uint16 dstChainId,
        address dstAdapter,
        uint256 amount,
        BridgeTypes.BridgeOptions calldata,
        BridgeTypes.ExecuteTransferParams calldata params,
        address refundAddress
    ) internal override returns (uint256 feeUsed) {
        address oft = oftForToken[token];
        if (oft == address(0)) revert UnsupportedAsset();

        // Approve the OFT contract to spend tokens
        IERC20(token).forceApprove(oft, amount);

        // Encode compose message if message is provided
        bytes memory composeMsg = bytes("");
        if (params.message.length > 0) {
            composeMsg = _encodeComposeTransferParams(operationId, params);
        }

        SendParam memory sendParam = SendParam({
            dstEid: _externalIdForChain(dstChainId),
            to: dstAdapter.toBytes32(),
            amountLD: amount,
            minAmountLD: amount, // Require exact amount (no slippage for stablecoins)
            extraOptions: bytes(""),
            composeMsg: composeMsg,
            oftCmd: bytes("")
        });

        MessagingFee memory fee = IOFT(oft).quoteSend(sendParam, false);
        if (msg.value < fee.nativeFee) {
            revert InsufficientFee(fee.nativeFee, msg.value);
        }

        IOFT(oft).send{value: fee.nativeFee}(sendParam, fee, refundAddress);
        return fee.nativeFee;
    }

    /**
     * @dev Estimate LayerZero OFT fees with compose message support
     */
    function _estimateTransport(
        bytes32 operationId,
        address token,
        uint16 dstChainId,
        address dstAdapter,
        uint256 amount,
        BridgeTypes.BridgeOptions calldata,
        BridgeTypes.ExecuteTransferParams calldata params
    ) internal view override returns (uint256 nativeFee, uint256 tokenFee) {
        address oft = oftForToken[token];
        if (oft == address(0)) revert UnsupportedAsset();

        // Encode compose message if message is provided
        bytes memory composeMsg = bytes("");
        if (params.message.length > 0) {
            composeMsg = _encodeComposeTransferParams(operationId, params);
        }

        SendParam memory sendParam = SendParam({
            dstEid: _externalIdForChain(dstChainId),
            to: dstAdapter.toBytes32(),
            amountLD: amount,
            minAmountLD: amount, // Require exact amount (no slippage for stablecoins)
            extraOptions: bytes(""),
            composeMsg: composeMsg,
            oftCmd: bytes("")
        });

        MessagingFee memory fee = IOFT(oft).quoteSend(sendParam, false);
        return (fee.nativeFee, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        MESSAGE ADAPTER IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Read state from a contract on a source chain (not supported by OFT adapter)
    function readState(
        bytes32,
        BridgeTypes.ExecuteReadStateParams calldata,
        BridgeTypes.BridgeOptions calldata
    ) external payable {
        revert OperationNotSupported();
    }

    /// @notice Send a message to a destination chain (not supported by OFT adapter)
    function sendMessage(
        bytes32,
        BridgeTypes.ExecuteSendMessageParams calldata,
        BridgeTypes.BridgeOptions calldata
    ) external payable {
        revert OperationNotSupported();
    }

    /// @notice Check if the adapter supports a specific message operation type
    function supportsMessageOperation(
        uint16,
        BridgeTypes.OperationType operationType
    ) external pure returns (bool) {
        return operationType == BridgeTypes.OperationType.TRANSFER_ASSET;
    }

    /*//////////////////////////////////////////////////////////////
                             LAYERZERO COMPOSE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Handles composed messages from LayerZero after OFT token delivery
     * @dev Called by LayerZero endpoint after tokens are delivered via OFT
     * @param _message OFT-encoded compose message from OFT
     */
    function lzCompose(
        address /* _from */,
        bytes32 /* _guid */,
        bytes calldata _message,
        address /* _caller */,
        bytes calldata /* _extraData */
    ) external payable override nonReentrant {
        // Verify caller is LayerZero endpoint
        if (msg.sender != LZ_ENDPOINT) revert Unauthorized();

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
        if (!supportedAsset[params.asset]) revert UnsupportedAsset();

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
