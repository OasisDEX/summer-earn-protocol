// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IAssetAdapter} from "../interfaces/IAssetAdapter.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IMessageAdapter} from "../interfaces/IMessageAdapter.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {BaseBridgeAdapter} from "../base/BaseBridgeAdapter.sol";

import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";
import {AddressCast} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";

/**
 * @title BaseERC7802Adapter
 * @notice Base adapter implementing common flow for ERC-7802 mint/burn transports with OFT compose support
 * @dev Children must implement transport-specific _send7802 and _estimate7802 hooks
 * @dev Supports atomic asset transfers with optional compose messages via OFT compose functionality
 */
abstract contract BaseERC7802Adapter is
    IAssetAdapter,
    IBridgeAdapter,
    IMessageAdapter,
    ILayerZeroComposer,
    BaseBridgeAdapter
{
    using SafeERC20 for IERC20;
    using AddressCast for address;
    using AddressCast for bytes32;

    /// @notice Tracks which assets are supported by this adapter on THIS chain
    mapping(address asset => bool supported) public supportedAsset;

    /// @notice LayerZero endpoint for compose functionality
    address public immutable LZ_ENDPOINT;

    /// @notice Emitted when support is toggled for an asset
    event AssetSupportUpdated(address indexed asset, bool supported);

    constructor(
        address _crossChainRegistry,
        address _accessManager,
        address _lzEndpoint
    ) BaseBridgeAdapter(_crossChainRegistry, _accessManager) {
        if (_lzEndpoint == address(0)) revert InvalidParams();
        LZ_ENDPOINT = _lzEndpoint;
    }

    /*//////////////////////////////////////////////////////////////
                             GOVERNANCE
    //////////////////////////////////////////////////////////////*/

    /// @notice Set support for an ERC-7802 asset
    function setAssetSupport(
        address asset,
        bool isSupported
    ) external onlyGovernor {
        if (asset == address(0)) revert InvalidParams();
        supportedAsset[asset] = isSupported;
        emit AssetSupportUpdated(asset, isSupported);
    }

    /*//////////////////////////////////////////////////////////////
                               CORE FLOW
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
        if (!supportedAsset[params.asset]) revert UnsupportedAsset();
        if (params.amount == 0) revert InvalidParams();

        // Pull tokens from BridgeRouter to this adapter
        IERC20(params.asset).safeTransferFrom(
            msg.sender,
            address(this),
            params.amount
        );

        // Resolve destination peer adapter via registry
        address dstAdapter = _peerAdapter(params.destinationChainId);
        if (dstAdapter == address(0)) revert UnsupportedChain();

        // Execute transport-specific burn/mint initiation
        uint256 used = _sendTransport{value: msg.value}(
            operationId,
            params.asset,
            params.destinationChainId,
            dstAdapter,
            params.amount,
            options,
            params,
            params.refundAddress
        );

        // Refund any excess native back to the designated refund address
        if (msg.value > used) {
            (bool ok, ) = params.refundAddress.call{value: (msg.value - used)}(
                ""
            );
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

    /// @notice Finalize on destination after tokens are minted to this adapter
    function finalize(
        bytes32 operationId,
        BridgeTypes.ExecuteTransferParams calldata params
    ) external onlyAuthorizedExecutor nonReentrant {
        if (!this.supportsOperation(BridgeTypes.OperationType.TRANSFER_ASSET)) {
            revert OperationNotSupported();
        }
        if (!supportedAsset[params.asset]) revert UnsupportedAsset();
        if (params.amount == 0) revert InvalidParams();
        if (params.destinationChainId != THIS_CHAIN) revert InvalidParams();

        uint256 bal = IERC20(params.asset).balanceOf(address(this));
        if (bal < params.amount) revert InsufficientBalance();

        // Move tokens to router, which will forward to recipient during deliver
        IERC20(params.asset).safeTransfer(bridgeRouter(), params.amount);

        bytes memory payload = _encodeRelayedTransferParams(
            BridgeTypes.RelayedTransferParams({
                operationId: operationId,
                originator: params.originator,
                // Executor can pass true source if tracked; placeholder uses this chain id contextually
                sourceChainId: uint16(block.chainid),
                recipient: params.target,
                asset: params.asset,
                amount: params.amount,
                message: params.message
            })
        );

        IBridgeRouter(bridgeRouter()).deliver(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            payload
        );
    }

    /*//////////////////////////////////////////////////////////////
                         ESTIMATES & CAPABILITIES
    //////////////////////////////////////////////////////////////*/

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
        if (!supportedAsset[params.asset]) revert UnsupportedAsset();
        if (params.amount == 0) revert InvalidParams();
        address dstAdapter = _peerAdapter(params.destinationChainId);
        if (dstAdapter == address(0)) revert UnsupportedChain();
        return
            _estimateTransport(
                bytes32(0), // operationId not available in estimate context
                params.asset,
                params.destinationChainId,
                dstAdapter,
                params.amount,
                options,
                params
            );
    }

    /// @inheritdoc IBridgeAdapter
    function estimateReadState(
        BridgeTypes.ExecuteReadStateParams calldata,
        BridgeTypes.BridgeOptions calldata
    ) external pure returns (uint256, uint256) {
        revert OperationNotSupported();
    }

    /// @inheritdoc IBridgeAdapter
    function estimateSendMessage(
        BridgeTypes.ExecuteSendMessageParams calldata,
        BridgeTypes.BridgeOptions calldata
    ) external pure returns (uint256, uint256) {
        revert OperationNotSupported();
    }

    /// @inheritdoc IBridgeAdapter
    function supportsOperation(
        BridgeTypes.OperationType operationType
    ) external pure override returns (bool) {
        return operationType == BridgeTypes.OperationType.TRANSFER_ASSET;
    }

    /// @inheritdoc IAssetAdapter
    function supportsAssetTransfer(
        uint16 destinationChainId,
        address asset
    ) external view returns (bool) {
        return
            supportedAsset[asset] && isTrustedDestination(destinationChainId);
    }

    /*//////////////////////////////////////////////////////////////
                              CHILD HOOKS
    //////////////////////////////////////////////////////////////*/

    function _sendTransport(
        bytes32 operationId,
        address token,
        uint16 dstChainId,
        address dstAdapter,
        uint256 amount,
        BridgeTypes.BridgeOptions calldata options,
        BridgeTypes.ExecuteTransferParams calldata params,
        address refundAddress
    ) internal payable virtual returns (uint256 feeUsed);

    function _estimateTransport(
        bytes32 operationId,
        address token,
        uint16 dstChainId,
        address dstAdapter,
        uint256 amount,
        BridgeTypes.BridgeOptions calldata options,
        BridgeTypes.ExecuteTransferParams calldata params
    ) internal view virtual returns (uint256 nativeFee, uint256 tokenFee);

    /// @notice Prefer mapped external ID, else canonical chainId
    function _externalOrCanonical(
        uint16 chainId
    ) internal view returns (uint256) {
        uint32 ext = chainToExternalId[chainId];
        return ext == 0 ? uint256(chainId) : uint256(ext);
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
        if (message.length < 76) revert InvalidMessage();

        // Use official codec for extraction
        srcEid = OFTComposeMsgCodec.srcEid(message);
        amountLD = OFTComposeMsgCodec.amountLD(message);
        composeMsg = OFTComposeMsgCodec.composeMsg(message);
        composeFrom = OFTComposeMsgCodec.composeFrom(message);
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
    ) internal pure returns (bytes memory) {
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

    /*//////////////////////////////////////////////////////////////
                             LAYERZERO COMPOSE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Handles composed messages from LayerZero after OFT token delivery
     * @dev Called by LayerZero endpoint after tokens are delivered via OFT
     * @param _from The originating OApp (should be destination OFT contract)
     * @param _guid LayerZero message GUID
     * @param _message OFT-encoded compose message from OFT
     * @param _caller The caller of the compose function
     * @param _extraData Additional data from LayerZero
     */
    function lzCompose(
        address _from,
        bytes32 _guid,
        bytes calldata _message,
        address _caller,
        bytes calldata _extraData
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

        // Validate the source adapter relationship
        _assertTrustedSource(composeFrom, uint16(srcEid));

        // Ensure the LayerZero srcEid maps to the same chain as encoded in the payload
        uint16 chainFromEid = externalIdToChainId[srcEid];
        _assertSourceChainId(params.sourceChainId, chainFromEid);

        // Use the minted amount from OFT compose header as authoritative
        params.amount = amountLD;

        // Ensure the asset is supported
        if (!supportedAsset[params.asset]) revert UnsupportedAsset();

        // Note: destinationChainId is implicitly THIS_CHAIN for compose messages

        // Check that we have the expected amount of tokens
        uint256 bal = IERC20(params.asset).balanceOf(address(this));
        if (bal < params.amount) revert InsufficientBalance();

        // Move tokens to router, which will forward to recipient during deliver
        IERC20(params.asset).safeTransfer(bridgeRouter(), params.amount);

        // Create the finalize params for the router
        BridgeTypes.ExecuteTransferParams memory finalizeParams = BridgeTypes
            .ExecuteTransferParams({
                originator: params.originator,
                destinationChainId: THIS_CHAIN,
                target: params.recipient,
                asset: params.asset,
                amount: params.amount,
                message: params.message,
                refundAddress: address(this) // Adapter receives any refunds
            });

        // Finalize through router
        IBridgeRouter(bridgeRouter()).deliver(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            _encodeRelayedTransferParams(params)
        );
    }
}
