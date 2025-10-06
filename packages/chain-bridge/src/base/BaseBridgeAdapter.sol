// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CrossChainConfigManaged} from "../contracts/CrossChainConfigManaged.sol";
import {ICrossChainRegistry} from "../interfaces/ICrossChainRegistry.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {BridgeCodec} from "../libraries/BridgeCodec.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";

abstract contract BaseBridgeAdapter is
    CrossChainConfigManaged,
    ReentrancyGuard,
    ProtocolAccessManaged,
    IERC165
{
    using SafeERC20 for IERC20;
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

    /// @notice Thrown when the contract has insufficient balance
    error InsufficientBalance();

    /// @notice Thrown when a native token transfer fails
    error TransferFailed();

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

    /// @notice Emitted when stuck tokens are recovered via sweep
    event TokensRecovered(
        address indexed asset,
        uint256 amount,
        address indexed recipient
    );

    /**
     * @param _registry Address of the CrossChainRegistry contract
     * @param _accessManager Address of the AccessManager contract
     */
    constructor(
        address _registry,
        address _accessManager
    ) CrossChainConfigManaged(_registry) ProtocolAccessManaged(_accessManager) {
        if (_accessManager == address(0)) {
            revert InvalidParams();
        }
        if (block.chainid > type(uint16).max) {
            revert ChainIdTooLarge(block.chainid);
        }
        THIS_CHAIN = uint16(block.chainid);
    }

    /*//////////////////////////////////////////////////////////////
                            GOVERNANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Map a canonical chain ID to an adapter-specific external ID
     * @dev Governance utility. Centralizes mapping logic and events.
     * @param chainId Canonical EVM chain ID
     * @param externalId Adapter/bridge external identifier (e.g., LayerZero EID)
     */
    function mapExternalId(
        uint16 chainId,
        uint32 externalId
    ) external onlyGovernor {
        if (externalId == 0) {
            revert InvalidParams();
        }
        _mapChainExternalId(chainId, externalId);
    }

    /**
     * @notice Remove the external ID mapping for a canonical chain ID
     * @param chainId Canonical EVM chain ID to unmap
     */
    function unmapExternalId(uint16 chainId) external onlyGovernor {
        _unmapChainExternalId(chainId);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return (interfaceId == type(IBridgeAdapter).interfaceId ||
            interfaceId == type(IERC165).interfaceId);
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
        if (!isTrustedDestination(dstChain)) {
            revert UntrustedDestinationChain(dstChain);
        }
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
            .getAllTargetsForSource(
                address(this),
                CROSS_CHAIN_REGISTRY.PEER_RELATIONSHIP()
            );
        return targetChainIds;
    }

    function _peerAdapter(uint16 dstChain) internal view returns (address) {
        return CROSS_CHAIN_REGISTRY.getAdapterPeer(address(this), dstChain);
    }

    /**
     * @notice Returns true if governance has registered a peer adapter for `dstChain`
     */
    function isTrustedDestination(uint16 dstChain) public view returns (bool) {
        // Revert if the relationship does not exist; used by modifiers and explicit checks
        return _peerAdapter(dstChain) != address(0);
    }

    /**
     * @notice Safe boolean probe for trusted destination without surfacing registry errors
     * @dev Returns false if the registry lookup reverts due to missing relationship
     */
    function _hasTrustedDestination(
        uint16 dstChain
    ) internal view returns (bool) {
        try
            CROSS_CHAIN_REGISTRY.getAdapterPeer(address(this), dstChain)
        returns (address peer) {
            return peer != address(0);
        } catch {
            return false;
        }
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
     * @notice Resolve external adapter-specific ID from canonical chainId
     * @dev Reverts with UnsupportedChain when no mapping exists
     * @param chainId Canonical EVM chain ID
     * @return externalId Adapter/bridge external identifier (e.g., LayerZero EID)
     */
    function _externalIdForChain(
        uint16 chainId
    ) internal view returns (uint32 externalId) {
        externalId = chainToExternalId[chainId];
        if (externalId == 0) {
            revert IBridgeAdapter.UnsupportedChain();
        }
        return externalId;
    }

    /**
     * @notice Resolve canonical chainId from an adapter-specific externalId
     * @dev Reverts with UnsupportedChain when no mapping exists
     * @param externalId Adapter/bridge external identifier (e.g., LayerZero EID)
     * @return chainId Canonical EVM chain ID
     */
    function _chainIdFromExternalId(
        uint32 externalId
    ) internal view returns (uint16 chainId) {
        chainId = externalIdToChainId[externalId];
        if (chainId == 0) {
            revert IBridgeAdapter.UnsupportedChain();
        }
        return chainId;
    }

    /**
     * @notice Requires a non-zero gas limit and returns it
     * @param userGas User-provided gas limit
     * @return gasLimit The validated gas limit
     */
    function _requireGasLimit(uint64 userGas) internal pure returns (uint64) {
        if (userGas == 0) revert InvalidParams();
        return userGas;
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

    /**
     * @notice Governance-only sweep to recover tokens held by this adapter
     * @param asset Token to recover (address(0) for native ETH)
     * @param to Recipient of the recovered tokens
     * @param amount Amount to sweep
     */
    function sweep(
        address asset,
        address to,
        uint256 amount
    ) external onlyGovernor nonReentrant {
        if (to == address(0)) revert InvalidParams();

        if (asset == address(0)) {
            // Handle native ETH
            if (address(this).balance < amount) revert InsufficientBalance();
            (bool success, ) = to.call{value: amount}("");
            if (!success) revert TransferFailed();
        } else {
            // Handle ERC20 tokens
            uint256 balance = IERC20(asset).balanceOf(address(this));
            if (balance < amount) revert InsufficientBalance();
            IERC20(asset).safeTransfer(to, amount);
        }

        emit TokensRecovered(asset, amount, to);
    }
}
