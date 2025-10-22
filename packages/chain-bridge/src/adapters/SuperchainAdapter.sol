// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {BridgeMessagingHelper} from "../libraries/BridgeMessagingHelper.sol";
import {BaseBridgeAdapter} from "../base/BaseBridgeAdapter.sol";
import {IAssetAdapter} from "../interfaces/IAssetAdapter.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";
import {IBaseBridgeAdapterErrors} from "../interfaces/IBaseBridgeAdapterErrors.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISuperchainTokenBridge} from "../interfaces/ISuperchainTokenBridge.sol";
import {IL2ToL2CrossDomainMessenger} from "../interfaces/IL2ToL2CrossDomainMessenger.sol";

/**
 * @title SuperchainAdapter
 * @notice ERC-7802 adapter using OP Superchain Token Bridge predeploy with L2ToL2CrossDomainMessenger
 * @dev See: https://docs.optimism.io/interop/superchain-erc20
 *
 * EXECUTION MODEL:
 * This adapter uses the OP Stack's recommended concatenated action pattern:
 *
 * 1. Source chain: sendERC20() burns tokens and sendMessage() sends delivery instruction
 * 2. Destination chain: OP Stack autorelayer delivers both token minting and message
 * 3. Destination chain: relayMessage() callback automatically completes delivery
 *
 * This eliminates the need for manual keeper intervention, providing automated delivery
 * similar to StargateAdapter's lzCompose pattern.
 */
contract SuperchainAdapter is BaseBridgeAdapter, IAssetAdapter, IBridgeAdapter {
    using SafeERC20 for IERC20;
    ISuperchainTokenBridge public immutable SUPERCHAIN_BRIDGE;
    IL2ToL2CrossDomainMessenger public immutable L2_TO_L2_MESSENGER;

    /// @notice Mapping of supported assets
    mapping(address asset => bool supported) public supportedAssets;

    /// @notice Event emitted when asset support is updated
    event AssetSupportUpdated(address indexed asset, bool supported);

    /// @notice Initialize the SuperchainAdapter
    /// @param _crossChainRegistry Address of the CrossChainRegistry contract
    /// @param _accessManager Address of the AccessManager contract
    /// @param _superchainBridge Address of the SuperchainTokenBridge predeploy
    /// @param _l2ToL2Messenger Address of the L2ToL2CrossDomainMessenger predeploy
    constructor(
        address _crossChainRegistry,
        address _accessManager,
        address _superchainBridge,
        address _l2ToL2Messenger
    ) BaseBridgeAdapter(_crossChainRegistry, _accessManager) {
        if (_superchainBridge == address(0)) revert InvalidParams();
        if (_l2ToL2Messenger == address(0)) revert InvalidParams();
        SUPERCHAIN_BRIDGE = ISuperchainTokenBridge(_superchainBridge);
        L2_TO_L2_MESSENGER = IL2ToL2CrossDomainMessenger(_l2ToL2Messenger);
    }

    /*//////////////////////////////////////////////////////////////
                        ASSET ADAPTER IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IAssetAdapter
    function transferAsset(
        bytes32 operationId,
        BridgeTypes.ExecuteTransferParams calldata params,
        BridgeTypes.BridgeOptions calldata /*options*/
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
        address dstAdapter = _getAdapterPeerOrRevert(params.destinationChainId);

        // Send via Superchain bridge (mints tokens to destination adapter)
        SUPERCHAIN_BRIDGE.sendERC20(
            params.asset,
            _externalIdForChain(params.destinationChainId),
            dstAdapter,
            params.amount
        );

        // Send message via L2ToL2CrossDomainMessenger to trigger delivery
        bytes memory message = BridgeMessagingHelper
            .encodeRelayedTransferParams(
                BridgeTypes.RelayedTransferParams({
                    operationId: operationId,
                    originator: params.originator,
                    sourceChainId: uint16(block.chainid),
                    recipient: params.target,
                    asset: params.asset,
                    amount: params.amount,
                    message: params.message
                })
            );

        L2_TO_L2_MESSENGER.sendMessage(
            _externalIdForChain(params.destinationChainId),
            dstAdapter,
            message
        );

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
        BridgeTypes.BridgeOptions calldata /*options*/
    ) external view returns (uint256, uint256) {
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
                        BRIDGE ADAPTER IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBridgeAdapter
    function supportsOperation(
        BridgeTypes.OperationType operationType
    ) external pure returns (bool) {
        return operationType == BridgeTypes.OperationType.TRANSFER_ASSET;
    }

    /// @notice Handle relayed message from L2ToL2CrossDomainMessenger
    /// @dev Called by L2ToL2CrossDomainMessenger after message is relayed from source chain
    /// @param _message Encoded RelayedTransferParams from source chain
    function relayMessage(bytes calldata _message) external {
        // Validate caller is L2ToL2CrossDomainMessenger
        if (msg.sender != address(L2_TO_L2_MESSENGER)) revert Unauthorized();

        // Decode the relayed transfer parameters
        BridgeTypes.RelayedTransferParams memory params = BridgeMessagingHelper
            .decodeRelayedTransferParams(_message);

        // Validate source adapter is trusted peer
        if (
            !_validateTrustedSource(
                L2_TO_L2_MESSENGER.crossDomainMessageSender(),
                uint16(L2_TO_L2_MESSENGER.crossDomainMessageSource())
            )
        ) {
            revert UntrustedSourceAdapter(
                L2_TO_L2_MESSENGER.crossDomainMessageSender(),
                uint16(L2_TO_L2_MESSENGER.crossDomainMessageSource())
            );
        }

        // Validate source chain ID matches
        _validateSourceChainId(
            params.sourceChainId,
            uint16(L2_TO_L2_MESSENGER.crossDomainMessageSource())
        );

        // Validate asset is supported
        if (!supportedAssets[params.asset])
            revert IBridgeAdapter.UnsupportedAsset();
        if (params.amount == 0) revert IBaseBridgeAdapterErrors.InvalidAmount();

        // Transfer tokens to router
        IERC20(params.asset).safeTransfer(bridgeRouter(), params.amount);

        // Deliver to router
        IBridgeRouter(bridgeRouter()).deliver(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            _message
        );
    }
}
