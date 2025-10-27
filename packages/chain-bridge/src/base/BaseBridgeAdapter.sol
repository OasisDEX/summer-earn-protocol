// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CrossChainConfigManaged} from "../contracts/CrossChainConfigManaged.sol";
import {ICrossChainRegistry} from "../interfaces/ICrossChainRegistry.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {BridgeCodec} from "../libraries/BridgeCodec.sol";

abstract contract BaseBridgeAdapter is
    CrossChainConfigManaged,
    ReentrancyGuard,
    ProtocolAccessManaged
{
    /// @notice Error thrown when destination chain peer is not trusted by governance
    error UntrustedDestinationChain(uint16 chainId);

    /// @notice Error thrown when source adapter is not trusted
    error UntrustedSourceAdapter(address srcAdapter, uint16 srcChain);

    /// @notice Error thrown when the amount is invalid
    error InvalidAmount();

    /// @notice Error thrown when the source chain ID is invalid
    error InvalidSourceChainId();

    /// @notice Error thrown when chain ID exceeds uint16 max value
    error ChainIdTooLarge(uint256 chainId);

    /// @notice Thrown when a call is made by an unauthorized address
    error Unauthorized();

    /// @notice Error thrown when the message is invalid
    error InvalidMessage();

    /// @notice Error thrown when invalid parameters are provided
    error InvalidParams();

    uint16 public immutable THIS_CHAIN;

    /// @notice Mapping of supported chains to their external bridge protocol IDs
    mapping(uint16 chainId => uint32 externalId) public chainToExternalId;

    /// @notice Reverse mapping of external bridge protocol IDs to chain IDs
    mapping(uint32 externalId => uint16 chainId) public externalIdToChainId;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a chain external ID mapping is added
    event ExternalIdMapped(uint16 indexed chainId, uint32 indexed externalId);

    /// @notice Emitted when a chain external ID mapping is removed
    event ExternalIdUnmapped(uint16 indexed chainId, uint32 indexed externalId);

    /**
     * @param _registry Address of the CrossChainRegistry contract
     * @param _accessManager Address of the AccessManager contract
     */
    constructor(
        address _registry,
        address _accessManager
    ) CrossChainConfigManaged(_registry) ProtocolAccessManaged(_accessManager) {
        if (block.chainid > type(uint16).max) {
            revert ChainIdTooLarge(block.chainid);
        }
        THIS_CHAIN = uint16(block.chainid);
    }

    /**
     * @notice Ensures that governance has registered a trusted peer adapter for `dstChain` in the CrossChainRegistry.
     * @dev This check validates that the destination chain has been authorized by governance through the registry.
     * It does NOT check whether this adapter knows how to translate chain IDs to bridge-specific external IDs—that
     * validation is handled by the internal external ID mapping (chainToExternalId).
     *
     * This creates a two-layer security model:
     * 1. Registry check: "Am I allowed to talk to that peer?" (governance authorization)
     * 2. External ID mapping: "Do I know how to talk to the bridge on that chain?" (technical capability)
     */
    modifier onlyTrustedDestination(uint16 dstChain) {
        if (
            ICrossChainRegistry(CROSS_CHAIN_REGISTRY).getAdapterPeer(
                address(this),
                dstChain
            ) == address(0)
        ) {
            revert UntrustedDestinationChain(dstChain);
        }
        _;
    }

    modifier onlyTrustedSource(address srcAdapter, uint16 srcChain) {
        _assertTrustedSource(srcAdapter, srcChain);
        _;
    }

    /**
     * @notice Get the list of chain IDs that governance has registered as having trusted peer adapters
     * @dev This queries the CrossChainRegistry for chains we are authorized to talk to
     * @return chains Array of chain IDs with registered peer adapters
     */
    function getPeeredChainIds()
        external
        view
        returns (uint16[] memory chains)
    {
        (, uint16[] memory targetChainIds) = CROSS_CHAIN_REGISTRY
            .getTargetsForSource(
                address(this),
                CROSS_CHAIN_REGISTRY.PEER_RELATIONSHIP()
            );
        return targetChainIds;
    }

    function _peerAdapter(uint16 dstChain) internal view returns (address) {
        return CROSS_CHAIN_REGISTRY.getAdapterPeer(address(this), dstChain);
    }

    /// @dev Reverts if `srcAdapter` is **not** the registry-declared peer for `srcChain`.
    function _assertTrustedSource(
        address srcAdapter,
        uint16 srcChain
    ) internal view {
        if (
            !CROSS_CHAIN_REGISTRY.isValidAdapterPeer(
                srcAdapter,
                address(this), // <-- this adapter (dst)
                srcChain,
                THIS_CHAIN
            )
        ) {
            revert UntrustedSourceAdapter(srcAdapter, srcChain);
        }
    }

    function _assertReceivedAmount(
        uint256 amountSD,
        uint256 amount
    ) internal pure {
        if (amountSD != amount) revert InvalidAmount();
    }

    function _assertSourceChainId(
        uint16 sourceChainId,
        uint16 expectedChainId
    ) internal pure {
        if (sourceChainId != expectedChainId) revert InvalidSourceChainId();
    }

    /**
     * @notice Maps a chain ID to its bridge-specific external ID
     * @param chainId Chain ID to map
     * @param externalId Bridge-specific external ID for the chain (e.g., LayerZero EID)
     */
    function _mapChainExternalId(uint16 chainId, uint32 externalId) internal {
        chainToExternalId[chainId] = externalId;
        externalIdToChainId[externalId] = chainId;
        emit ExternalIdMapped(chainId, externalId);
    }

    /**
     * @notice Removes a chain external ID mapping
     * @param chainId Chain ID to unmap
     */
    function _unmapChainExternalId(uint16 chainId) internal {
        uint32 externalId = chainToExternalId[chainId];
        delete chainToExternalId[chainId];
        delete externalIdToChainId[externalId];
        emit ExternalIdUnmapped(chainId, externalId);
    }

    /**
     * @notice Normalizes gas limit using user input or default
     * @param userGas User-provided gas limit
     * @return Normalized gas limit
     */
    function _normalizeGas(uint64 userGas) internal view returns (uint64) {
        return userGas > 0 ? userGas : uint64(defaultGasLimit());
    }

    function _decodeRelayedMessageParams(
        bytes memory _message
    ) internal pure returns (BridgeTypes.RelayedMessageParams memory) {
        return abi.decode(_message, (BridgeTypes.RelayedMessageParams));
    }

    function _decodeRelayedTransferParams(
        bytes memory _message
    ) internal pure returns (BridgeTypes.RelayedTransferParams memory) {
        return abi.decode(_message, (BridgeTypes.RelayedTransferParams));
    }

    function _decodeRelayedReadResponse(
        bytes memory _message
    ) internal pure returns (BridgeTypes.RelayedReadResponse memory) {
        return abi.decode(_message, (BridgeTypes.RelayedReadResponse));
    }

    function _encodeRelayedMessageParams(
        BridgeTypes.RelayedMessageParams memory _params
    ) internal pure returns (bytes memory) {
        return abi.encode(_params);
    }

    function _encodeRelayedTransferParams(
        BridgeTypes.RelayedTransferParams memory _params
    ) internal pure returns (bytes memory) {
        return abi.encode(_params);
    }

    function _encodeRelayedReadResponse(
        BridgeTypes.RelayedReadResponse memory _params
    ) internal pure returns (bytes memory) {
        return abi.encode(_params);
    }

    function _encodeRelayedMessageParamsWithType(
        BridgeTypes.RelayedMessageParams memory _params
    ) internal pure returns (bytes memory) {
        return
            BridgeCodec.encodePayload(
                BridgeTypes.OperationType.MESSAGE,
                _encodeRelayedMessageParams(_params)
            );
    }

    function _encodeRelayedTransferParamsWithType(
        BridgeTypes.RelayedTransferParams memory _params
    ) internal pure returns (bytes memory) {
        return
            BridgeCodec.encodePayload(
                BridgeTypes.OperationType.TRANSFER_ASSET,
                _encodeRelayedTransferParams(_params)
            );
    }

    function _encodeRelayedReadResponseWithType(
        BridgeTypes.RelayedReadResponse memory _params
    ) internal pure returns (bytes memory) {
        return
            BridgeCodec.encodePayload(
                BridgeTypes.OperationType.READ_STATE,
                _encodeRelayedReadResponse(_params)
            );
    }

    /**
     * @notice Decodes a payload to extract OperationType and data
     * @param payload The encoded payload with OperationType prefix
     * @return operationType The extracted operation type
     * @return data The remaining payload data after removing the prefix
     */
    function _decodePayload(
        bytes calldata payload
    )
        internal
        pure
        returns (BridgeTypes.OperationType operationType, bytes memory data)
    {
        return BridgeCodec.decodePayload(payload);
    }
}
