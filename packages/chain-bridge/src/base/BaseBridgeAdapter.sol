// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CrossChainConfigManaged} from "../contracts/CrossChainConfigManaged.sol";
import {ICrossChainRegistry} from "../interfaces/ICrossChainRegistry.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IBaseBridgeAdapterErrors} from "../interfaces/IBaseBridgeAdapterErrors.sol";
import {IBaseBridgeAdapterEvents} from "../interfaces/IBaseBridgeAdapterEvents.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {BridgeCodec} from "../libraries/BridgeCodec.sol";
import {BridgeMessagingHelper} from "../libraries/BridgeMessagingHelper.sol";
import {TokenRecovery} from "./TokenRecovery.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

/**
 * @title BaseBridgeAdapter
 * @notice Abstract base contract for implementing cross-chain bridge adapters
 * @dev This contract provides the foundational functionality for bridge adapters that enable
 *      cross-chain communication and asset transfers. It handles chain ID mapping, peer validation,
 *      and provides common utilities for derived bridge implementations.
 *
 * ## Architecture Overview
 *
 * The BaseBridgeAdapter implements a two-layer security model:
 * 1. **Registry Check**: Validates that governance has authorized communication with peer adapters
 * 2. **External ID Mapping**: Ensures the adapter knows how to translate chain IDs to bridge-specific external IDs
 *
 * ## Key Features
 *
 * - **Chain ID Management**: Maps canonical EVM chain IDs to bridge-specific external identifiers
 * - **Peer Validation**: Ensures only trusted peer adapters can send cross-chain messages
 * - **Token Recovery**: Governance-controlled token recovery functionality for stuck assets
 * - **Message Encoding/Decoding**: Utilities for encoding and decoding cross-chain messages
 *
 * @dev This contract is abstract and must be extended by concrete bridge implementations
 */
abstract contract BaseBridgeAdapter is
    CrossChainConfigManaged,
    ProtocolAccessManaged,
    TokenRecovery,
    IERC165,
    IBaseBridgeAdapterErrors,
    IBaseBridgeAdapterEvents
{
    using SafeERC20 for IERC20;

    uint16 public immutable THIS_CHAIN;

    /// @notice Mapping of supported chains to their external bridge protocol IDs
    mapping(uint16 chainId => uint32 externalId) public chainToExternalId;

    /// @notice Reverse mapping of external bridge protocol IDs to chain IDs
    mapping(uint32 externalId => uint16 chainId) public externalIdToChainId;

    /**
     * @notice Initializes the BaseBridgeAdapter with required dependencies
     * @dev Sets up the cross-chain registry and access management systems
     * @param _registry Address of the CrossChainRegistry contract for peer management
     * @param _accessManager Address of the AccessManager contract for role-based access control
     * @custom:throws InvalidParams if access manager address is zero
     * @custom:throws ChainIdTooLarge if current chain ID exceeds uint16 maximum value
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
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Map a canonical chain ID to an adapter-specific external ID
     * @dev Governance utility that enables the adapter to communicate with specific chains.
     *      This mapping is essential for cross-chain operations as it translates between
     *      canonical EVM chain IDs and bridge-specific external identifiers.
     * @param chainId Canonical EVM chain ID (e.g., 1 for Ethereum mainnet)
     * @param externalId Adapter/bridge external identifier (e.g., LayerZero EID: 101 for Ethereum)
     * @custom:throws InvalidParams if chainId or externalId is zero
     * @custom:emits ExternalIdMapped when mapping is successfully created
     * @custom:access Only callable by governance role
     */
    function mapExternalId(
        uint16 chainId,
        uint32 externalId
    ) external onlyGovernor {
        if (chainId == 0) {
            revert InvalidParams();
        }
        if (externalId == 0) {
            revert InvalidParams();
        }
        _mapChainExternalId(chainId, externalId);
    }

    /**
     * @notice Remove the external ID mapping for a canonical chain ID
     * @dev Governance utility to disable communication with a specific chain by removing
     *      the external ID mapping. This effectively prevents cross-chain operations
     *      to/from the specified chain.
     * @param chainId Canonical EVM chain ID to unmap
     * @custom:throws InvalidParams if chainId is zero
     * @custom:emits ExternalIdUnmapped when mapping is successfully removed
     * @custom:access Only callable by governance role
     */
    function unmapExternalId(uint16 chainId) external onlyGovernor {
        if (chainId == 0) {
            revert InvalidParams();
        }
        _unmapChainExternalId(chainId);
    }

    /**
     * @notice Check if the caller is authorized to perform token recovery
     * @dev Implementation of TokenRecovery authorization - only governance can recover tokens
     * @custom:throws Unauthorized if caller is not governance
     */
    function _requireRecoveryAuthorization() internal view override {
        // Check if caller has governor role
        if (!_isGovernor(msg.sender)) {
            revert Unauthorized();
        }
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
        if (!isAllowedDestination(dstChain)) {
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
            .getTargetsForSource(
                address(this),
                CROSS_CHAIN_REGISTRY.PEER_RELATIONSHIP()
            );
        return targetChainIds;
    }

    /**
     * @notice Returns true if governance has registered a peer adapter for `dstChain`
     */
    function isAllowedDestination(uint16 dstChain) public view returns (bool) {
        // Revert if the relationship does not exist; used by modifiers and explicit checks
        return _getAdapterPeer(dstChain) != address(0);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the peer adapter address for a destination chain
     * @dev This function is kept separate for potential future extensibility.
     *      Derived contracts may override this to add custom peer resolution logic.
     * @param dstChain Destination chain ID
     * @return Peer adapter address for the destination chain
     */
    function _getAdapterPeer(uint16 dstChain) internal view returns (address) {
        return CROSS_CHAIN_REGISTRY.getAdapterPeer(address(this), dstChain);
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

    /// @dev Returns true if `srcAdapter` is the registry-declared peer for `srcChain`.
    function _validateTrustedSource(
        address srcAdapter,
        uint16 srcChain
    ) internal view returns (bool) {
        return
            CROSS_CHAIN_REGISTRY.isValidAdapterPeer(
                srcAdapter,
                address(this), // <-- this adapter (dst)
                srcChain,
                THIS_CHAIN
            );
    }

    function _validateSourceChainId(
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
     * @dev This function is used by derived bridge adapters to validate gas limits
     *      before passing them to bridge protocols. It ensures that a valid gas limit
     *      is provided for cross-chain operations.
     * @param userGas User-provided gas limit
     * @return gasLimit The validated gas limit
     * @custom:throws InvalidParams if userGas is zero
     */
    function _requireGasLimit(uint64 userGas) internal pure returns (uint64) {
        if (userGas == 0) revert InvalidParams();
        return userGas;
    }

    /**
     * @notice Decode relayed message parameters from bytes
     * @param _message Encoded message parameters
     * @return Decoded RelayedMessageParams struct
     */
    function _decodeRelayedMessageParams(
        bytes memory _message
    ) internal pure returns (BridgeTypes.RelayedMessageParams memory) {
        return BridgeMessagingHelper.decodeRelayedMessageParams(_message);
    }

    /**
     * @notice Decode relayed transfer parameters from bytes
     * @param _message Encoded transfer parameters
     * @return Decoded RelayedTransferParams struct
     */
    function _decodeRelayedTransferParams(
        bytes memory _message
    ) internal pure returns (BridgeTypes.RelayedTransferParams memory) {
        return BridgeMessagingHelper.decodeRelayedTransferParams(_message);
    }

    /**
     * @notice Encode relayed message parameters to bytes
     * @param _params RelayedMessageParams struct to encode
     * @return Encoded message parameters
     */
    function _encodeRelayedMessageParams(
        BridgeTypes.RelayedMessageParams memory _params
    ) internal pure returns (bytes memory) {
        return BridgeMessagingHelper.encodeRelayedMessageParams(_params);
    }

    /**
     * @notice Encode relayed transfer parameters to bytes
     * @param _params RelayedTransferParams struct to encode
     * @return Encoded transfer parameters
     */
    function _encodeRelayedTransferParams(
        BridgeTypes.RelayedTransferParams memory _params
    ) internal pure returns (bytes memory) {
        return BridgeMessagingHelper.encodeRelayedTransferParams(_params);
    }

    /**
     * @notice Encode relayed message parameters with operation type prefix
     * @param _params RelayedMessageParams struct to encode
     * @return Encoded message parameters with operation type
     */
    function _encodeRelayedMessageParamsWithType(
        BridgeTypes.RelayedMessageParams memory _params
    ) internal pure returns (bytes memory) {
        return
            BridgeMessagingHelper.encodeRelayedMessageParamsWithType(_params);
    }

    /**
     * @notice Encode relayed transfer parameters with operation type prefix
     * @param _params RelayedTransferParams struct to encode
     * @return Encoded transfer parameters with operation type
     */
    function _encodeRelayedTransferParamsWithType(
        BridgeTypes.RelayedTransferParams memory _params
    ) internal pure returns (bytes memory) {
        return
            BridgeMessagingHelper.encodeRelayedTransferParamsWithType(_params);
    }

    /**
     * @notice Decode a payload to extract OperationType and data
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
        return BridgeMessagingHelper.decodePayload(payload);
    }
}
