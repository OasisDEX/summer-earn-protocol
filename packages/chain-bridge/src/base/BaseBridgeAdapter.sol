// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CrossChainConfigManaged} from "../contracts/CrossChainConfigManaged.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IBaseBridgeAdapter} from "../interfaces/IBaseBridgeAdapter.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {TokenRecovery} from "./TokenRecovery.sol";
import {ProtocolFeeTokenHandler} from "./ProtocolFeeTokenHandler.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

/**
 * @title BaseBridgeAdapter
 * @notice Abstract base contract for implementing cross-chain bridge adapters
 * @dev This contract provides the foundational functionality for bridge adapters that enable
 *      cross-chain communication and asset transfers. It handles chain ID mapping, peer validation,
 *      and provides common utilities for derived bridge implementations.
 *
 * ## Interface Architecture
 *
 * The bridge adapter system follows a three-tier interface hierarchy:
 *
 * ### 1. Base Layer (`IBaseBridgeAdapter`)
 * - **Purpose**: Consolidates error and event definitions for base functionality
 * - **Contains**: `IBaseBridgeAdapterErrors` + `IBaseBridgeAdapterEvents`
 * - **Used by**: All bridge adapters for common error handling and event emission
 *
 * ### 2. Core Layer (`IBridgeAdapter`)
 * - **Purpose**: Defines core bridge functionality (estimation, operation support)
 * - **Contains**: Core methods like `estimateTransferAssets()`, `supportsOperation()`
 * - **Used by**: All bridge adapters + BridgeRouter for adapter registration
 * - **ERC165**: Required for `BridgeRouter.registerAdapter()` security checks
 *
 * ### 3. Capability Layer (`IAssetAdapter`, `IMessageAdapter`)
 * - **Purpose**: Defines specific capabilities (asset transfers vs messaging)
 * - **IAssetAdapter**: For adapters that can transfer assets (e.g., StargateAdapter)
 * - **IMessageAdapter**: For adapters that can send messages (e.g., LayerZeroAdapter)
 * - **Used by**: BridgeRouter to determine which adapter to use for specific operations
 *
 * ## Security Model
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
 * - **ERC165 Support**: Reports `IBridgeAdapter` and `IERC165` interfaces for runtime validation
 *
 * @dev This contract is abstract and must be extended by concrete bridge implementations
 */
abstract contract BaseBridgeAdapter is
    CrossChainConfigManaged,
    ProtocolAccessManaged,
    TokenRecovery,
    ProtocolFeeTokenHandler,
    IERC165,
    IBaseBridgeAdapter
{
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

    /**
     * @notice Authorization check for fee-related operations
     * @dev Implementation of ProtocolFeeTokenHandler authorization - only governance can configure fees
     * @custom:throws Unauthorized if caller is not governance
     */
    function _requireFeeAuthorization() internal view override {
        // Check if caller has governor role
        if (!_isGovernor(msg.sender)) {
            revert Unauthorized();
        }
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IERC165
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual returns (bool) {
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
     * @notice Modifier to check if an operation is supported by the adapter
     * @param operationType The operation type to validate
     */
    modifier withSupportedOperation(BridgeTypes.OperationType operationType) {
        if (!_supportsOperation(operationType)) {
            revert IBridgeAdapter.OperationNotSupported();
        }
        _;
    }

    /**
     * @notice Modifier to check if a destination chain has an external ID mapping
     * @param destinationChainId The chain ID to validate
     */
    modifier withSupportedDestinationChain(uint16 destinationChainId) {
        if (chainToExternalId[destinationChainId] == 0) {
            revert IBridgeAdapter.UnsupportedChain();
        }
        _;
    }

    /**
     * @notice Internal virtual function to check if an operation is supported
     * @dev Must be overridden by concrete adapters to implement their specific operation support logic
     * @param // operationType The operation type to check
     * @return true if the operation is supported
     */
    function _supportsOperation(
        BridgeTypes.OperationType /* operationType */
    ) internal view virtual returns (bool) {
        // Default implementation - should be overridden by concrete adapters
        return false;
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

    /**
     * @notice Validates that the source chain ID matches the expected chain ID
     * @param sourceChainId The source chain ID to validate
     * @param expectedChainId The expected chain ID
     * @custom:throws InvalidSourceChainId if the chain IDs don't match
     */
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
}
