// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {BaseBridgeAdapter} from "../base/BaseBridgeAdapter.sol";
import {IAssetAdapter} from "../interfaces/IAssetAdapter.sol";
import {IMessageAdapter} from "../interfaces/IMessageAdapter.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";
import {IBaseBridgeAdapterErrors} from "../interfaces/IBaseBridgeAdapterErrors.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISuperchainTokenBridge} from "../interfaces/ISuperchainTokenBridge.sol";

/**
 * @title SuperchainAdapter
 * @notice ERC-7802 adapter using OP Superchain Token Bridge predeploy
 * @dev See: https://docs.optimism.io/interop/superchain-erc20
 *
 * IMPORTANT EXECUTION MODEL:
 * Unlike other adapters (for example, StargateAdapter which uses automated lzCompose execution), this adapter requires
 * manual keeper intervention on the destination chain:
 *
 * 1. Source chain: sendERC20() burns tokens and initiates cross-chain message
 * 2. Destination chain: OP Stack autorelayer delivers message and mints tokens to adapter
 * 3. Destination chain: KEEPER MUST call finalize() to complete delivery to end recipient
 *
 * The OP Stack autorelayer only handles message delivery and token minting - it does NOT
 * call the adapter's finalize() function. This must be done by an authorized keeper.
 */
contract SuperchainAdapter is
    BaseBridgeAdapter,
    IAssetAdapter,
    IMessageAdapter,
    IBridgeAdapter
{
    using SafeERC20 for IERC20;
    ISuperchainTokenBridge public immutable superchainBridge;

    /// @notice Mapping of supported assets
    mapping(address asset => bool supported) public supportedAssets;

    /// @notice Event emitted when asset support is updated
    event AssetSupportUpdated(address indexed asset, bool supported);

    constructor(
        address _crossChainRegistry,
        address _accessManager,
        address _superchainBridge
    ) BaseBridgeAdapter(_crossChainRegistry, _accessManager) {
        if (_superchainBridge == address(0)) revert InvalidParams();
        superchainBridge = ISuperchainTokenBridge(_superchainBridge);
    }

    /*//////////////////////////////////////////////////////////////
                        ASSET ADAPTER IMPLEMENTATION
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
    {
        if (!supportedAssets[params.asset])
            revert IBridgeAdapter.UnsupportedAsset();
        if (params.amount == 0) revert IBaseBridgeAdapterErrors.InvalidAmount();

        // Pull tokens from router
        IERC20(params.asset).safeTransferFrom(
            msg.sender,
            address(this),
            params.amount
        );

        // Get destination adapter peer
        address dstAdapter = _getAdapterPeer(params.destinationChainId);

        // Send via Superchain bridge
        superchainBridge.sendERC20(
            params.asset,
            _externalIdForChain(params.destinationChainId),
            dstAdapter,
            params.amount
        );

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
    ) external view returns (uint256 nativeFee, uint256 tokenFee) {
        if (!supportedAssets[params.asset])
            revert IBridgeAdapter.UnsupportedAsset();
        if (params.amount == 0) revert IBaseBridgeAdapterErrors.InvalidAmount();
        if (!_hasTrustedDestination(params.destinationChainId)) {
            revert IBaseBridgeAdapterErrors.UntrustedDestinationChain(
                params.destinationChainId
            );
        }

        // Superchain bridge transfers are free (just L2 gas)
        return (0, 0);
    }

    /// @inheritdoc IAssetAdapter
    function supportsAssetTransfer(
        uint16 destinationChainId,
        address asset
    ) external view returns (bool) {
        return
            supportedAssets[asset] &&
            _hasTrustedDestination(destinationChainId);
    }

    /// @notice Set asset support (governance function)
    function setAssetSupport(
        address asset,
        bool supported
    ) external onlyGovernor {
        if (asset == address(0)) revert InvalidParams();
        supportedAssets[asset] = supported;
        emit AssetSupportUpdated(asset, supported);
    }

    /// @notice Check if an asset is supported
    function supportedAsset(address asset) external view returns (bool) {
        return supportedAssets[asset];
    }

    /*//////////////////////////////////////////////////////////////
                        MESSAGE ADAPTER IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IMessageAdapter
    function sendMessage(
        bytes32 operationId,
        BridgeTypes.ExecuteSendMessageParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    ) external payable {
        revert IBridgeAdapter.OperationNotSupported();
    }

    /// @inheritdoc IMessageAdapter
    function supportsMessageOperation(
        uint16,
        BridgeTypes.OperationType operationType
    ) external pure returns (bool) {
        return operationType == BridgeTypes.OperationType.TRANSFER_ASSET;
    }

    /*//////////////////////////////////////////////////////////////
                        BRIDGE ADAPTER IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBridgeAdapter
    function supportsOperation(
        BridgeTypes.OperationType operationType
    ) external pure returns (bool) {
        return operationType == BridgeTypes.OperationType.TRANSFER_ASSET;
    }

    /// @inheritdoc IBridgeAdapter
    function estimateSendMessage(
        BridgeTypes.ExecuteSendMessageParams calldata,
        BridgeTypes.BridgeOptions calldata
    ) external pure returns (uint256 nativeFee, uint256 tokenFee) {
        revert IBridgeAdapter.OperationNotSupported();
    }

    /// @notice Finalize a transfer (called by keeper after OP Stack autorelayer delivers)
    /// @dev This function must be called by an authorized keeper after the OP Stack autorelayer
    ///      has delivered the message and minted tokens to this adapter
    function finalize(
        bytes32 operationId,
        BridgeTypes.ExecuteTransferParams calldata params
    ) external onlyAuthorizedExecutor {
        if (!supportedAssets[params.asset])
            revert IBridgeAdapter.UnsupportedAsset();
        if (params.amount == 0) revert IBaseBridgeAdapterErrors.InvalidAmount();

        // Transfer tokens to router
        IERC20(params.asset).safeTransfer(bridgeRouter(), params.amount);

        // Deliver to router
        IBridgeRouter(bridgeRouter()).deliver(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            abi.encode(params)
        );
    }
}
