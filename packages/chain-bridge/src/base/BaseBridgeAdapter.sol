// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CrossChainConfigManaged} from "../contracts/CrossChainConfigManaged.sol";
import {ICrossChainRegistry} from "../interfaces/ICrossChainRegistry.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";

abstract contract BaseBridgeAdapter is
    CrossChainConfigManaged,
    ReentrancyGuard,
    ProtocolAccessManaged
{
    /// @notice Error thrown when destination chain is not supported
    error UnsupportedDestinationChain(uint16 chainId);

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

    uint16 public immutable THIS_CHAIN;

    /// @notice Mapping of supported chains to their external bridge protocol IDs
    mapping(uint16 chainId => uint32 externalId) public chainToExternalId;

    /// @notice Reverse mapping of external bridge protocol IDs to chain IDs
    mapping(uint32 externalId => uint16 chainId) public externalIdToChain;

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

    modifier onlySupportedDestination(uint16 dstChain) {
        if (
            ICrossChainRegistry(CROSS_CHAIN_REGISTRY).getAdapterPeer(
                address(this),
                dstChain
            ) == address(0)
        ) {
            revert UnsupportedDestinationChain(dstChain);
        }
        _;
    }

    modifier onlyTrustedSource(address srcAdapter, uint16 srcChain) {
        _assertTrustedSource(srcAdapter, srcChain);
        _;
    }

    /**
     * @notice Get the list of supported chains
     */
    function getSupportedChains()
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
     * @notice Adds a chain mapping
     * @param chainId Chain ID to add
     * @param externalId External bridge protocol ID for the chain
     */
    function _addChain(uint16 chainId, uint32 externalId) internal {
        chainToExternalId[chainId] = externalId;
        externalIdToChain[externalId] = chainId;
    }

    /**
     * @notice Removes a chain mapping
     * @param chainId Chain ID to remove
     */
    function _removeChain(uint16 chainId) internal {
        uint32 externalId = chainToExternalId[chainId];
        delete chainToExternalId[chainId];
        delete externalIdToChain[externalId];
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

    /**
     * @notice Generic function to encode operation with type
     * @param op Operation type
     * @param abiBytes ABI-encoded bytes of the operation parameters
     * @return Encoded bytes with operation type prefix
     */
    function _encodeWithType(
        BridgeTypes.OperationType op,
        bytes memory abiBytes
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(uint16(op), abiBytes);
    }

    // Legacy functions maintained for backward compatibility
    function _encodeRelayedMessageParamsWithType(
        BridgeTypes.RelayedMessageParams memory _params
    ) internal pure returns (bytes memory) {
        return
            _encodeWithType(
                BridgeTypes.OperationType.MESSAGE,
                _encodeRelayedMessageParams(_params)
            );
    }

    function _encodeRelayedTransferParamsWithType(
        BridgeTypes.RelayedTransferParams memory _params
    ) internal pure returns (bytes memory) {
        return
            _encodeWithType(
                BridgeTypes.OperationType.TRANSFER_ASSET,
                _encodeRelayedTransferParams(_params)
            );
    }

    function _encodeRelayedReadResponseWithType(
        BridgeTypes.RelayedReadResponse memory _params
    ) internal pure returns (bytes memory) {
        return
            _encodeWithType(
                BridgeTypes.OperationType.READ_STATE,
                _encodeRelayedReadResponse(_params)
            );
    }
}
