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
    BaseBridgeAdapter
{
    using SafeERC20 for IERC20;

    /// @notice Tracks which assets are supported by this adapter on THIS chain
    mapping(address asset => bool supported) public supportedAsset;

    /// @notice Emitted when support is toggled for an asset
    event AssetSupportUpdated(address indexed asset, bool supported);

    constructor(
        address _crossChainRegistry,
        address _accessManager
    ) BaseBridgeAdapter(_crossChainRegistry, _accessManager) {}

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
        address dstAdapter = _getAdapterPeer(params.destinationChainId);
        if (dstAdapter == address(0)) revert UnsupportedChain();

        // Execute transport-specific burn/mint initiation
        // Note: msg.value is automatically available to internal payable functions
        uint256 used = _sendTransport(
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
        address dstAdapter = _getAdapterPeer(params.destinationChainId);
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
            supportedAsset[asset] && isAllowedDestination(destinationChainId);
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
    ) internal virtual returns (uint256 feeUsed);

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
}
