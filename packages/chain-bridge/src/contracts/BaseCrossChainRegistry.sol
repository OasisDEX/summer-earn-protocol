// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICrossChainRegistry} from "../interfaces/ICrossChainRegistry.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";

/**
 * @title BaseCrossChainRegistry
 * @notice Abstract base contract for managing cross-chain relationships between different contract types
 * @dev Provides core functionality for cross-chain relationship management with internal methods
 *      that can be extended by specialized registry contracts.
 *
 *      RELATIONSHIP CARDINALITY:
 *      - Source contracts can have multiple target contracts across different chains (1 to N)
 *      - Each source-target relationship is unique per chain and relationship type (1 to 1 per chain)
 *      - Relationship types define the nature of the connection (PEER_RELATIONSHIP, EXECUTOR_RELATIONSHIP)
 *
 *      KEY STRUCTURES:
 *      - crossChainRelations: Maps relationship keys to full relationship data
 *      - registeredSourceContracts: Tracks which contracts are registered as sources per relationship type
 *      - sourceToTargetChains: Maps source contracts to their target chain IDs for efficient enumeration
 *
 * This contract tries to be a generic base for cross-chain registries, so it can be extended for specific use-cases.
 * In particular it defines 2 types of relationships that are current to our use case, and then provides a function
 * `addSupportedRelationshipType` to add more relationship types as needed.
 */
abstract contract BaseCrossChainRegistry is
    ICrossChainRegistry,
    ProtocolAccessManaged
{
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The chain ID of the current deployment
    uint16 private immutable CURRENT_CHAIN_ID;

    /// @notice Mapping from relationship key to relationship information
    /// @dev Key: keccak256(abi.encode(sourceContract, relationshipType, targetChainId))
    ///      Value: Complete relationship data including source, target, chain IDs, and relationship type
    mapping(bytes32 relationshipKey => CrossChainRelation relationshipData)
        internal crossChainRelations;

    /// @notice Mapping from target key to source contract address for reverse lookups
    /// @dev Key: keccak256(abi.encode(sourceChainId, targetChainId, targetContract, relationshipType))
    ///      Value: Source contract address that has a relationship with the target
    mapping(bytes32 targetKey => address sourceContract) private targetToSource;

    /// @notice EnumerableSet of all registered source contracts per relationship type
    /// @dev Key: relationshipType (bytes32)
    ///      Value: Set of source contract addresses registered for this relationship type
    mapping(bytes32 relationshipType => EnumerableSet.AddressSet sourceContracts)
        private registeredSourceContracts;

    /// @notice Mapping to track all target chain IDs for each source contract and relationship type
    /// @dev Key: keccak256(abi.encode(sourceContract, relationshipType))
    ///      Value: Array of target chain IDs where the source contract has relationships
    mapping(bytes32 sourceTrackingKey => uint16[] targetChainIds)
        internal sourceToTargetChains;

    /// @notice Array of supported relationship types
    bytes32[] private supportedRelationshipTypes;

    /// @notice Mapping to track if a relationship type is supported
    mapping(bytes32 => bool) private relationshipTypeSupported;

    /// @notice The bridge router contract address
    address public bridgeRouter;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the BaseCrossChainRegistry
     * @param _accessManager Address of the access manager
     */
    constructor(address _accessManager) ProtocolAccessManaged(_accessManager) {
        CURRENT_CHAIN_ID = uint16(block.chainid);

        emit RegistryInitialized(uint16(block.chainid));
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL REGISTRATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to register a relationship
     * @param sourceContract The address of the source contract
     * @param targetContract The address of the target contract
     * @param sourceChainId The chain ID where the source contract is deployed
     * @param targetChainId The chain ID where the target contract is deployed
     * @param relationshipType The type of relationship
     */
    function _registerRelationship(
        address sourceContract,
        address targetContract,
        uint16 sourceChainId,
        uint16 targetChainId,
        bytes32 relationshipType
    ) internal {
        // Validate chain IDs
        if (sourceChainId == 0) revert InvalidChainId(sourceChainId);
        if (targetChainId == 0) revert InvalidChainId(targetChainId);
        if (
            sourceChainId != CURRENT_CHAIN_ID &&
            targetChainId != CURRENT_CHAIN_ID
        ) {
            revert InvalidChainRelationship(
                sourceChainId,
                targetChainId,
                CURRENT_CHAIN_ID
            );
        }

        // Validate addresses and relationship type
        if (sourceContract == address(0))
            revert InvalidSourceContract(sourceContract);
        if (targetContract == address(0))
            revert InvalidTargetContract(targetContract);
        if (relationshipType == bytes32(0))
            revert InvalidRelationshipType(relationshipType);

        // Enforce that relationship type must be supported
        if (!relationshipTypeSupported[relationshipType]) {
            revert UnsupportedRelationshipType(relationshipType);
        }

        bytes32 relationshipKey = _getRelationshipKey(
            sourceContract,
            relationshipType,
            targetChainId
        );

        // Check if relationship already exists to prevent duplicates
        if (crossChainRelations[relationshipKey].sourceContract != address(0)) {
            revert RelationshipAlreadyExists(
                sourceContract,
                relationshipType,
                targetChainId
            );
        }

        bool sameChain = _isSameChain(sourceChainId, targetChainId);

        // For cross-chain relationships, ensure target contract isn't already registered to prevent conflicts
        if (!sameChain) {
            // Generate target key for reverse lookup
            bytes32 targetKey = _getTargetKey(
                sourceChainId,
                targetChainId,
                targetContract,
                relationshipType
            );

            // If relationship is already registered, revert with an error
            if (targetToSource[targetKey] != address(0)) {
                revert TargetContractAlreadyRegistered(
                    targetContract,
                    sourceChainId,
                    targetChainId,
                    relationshipType,
                    targetToSource[targetKey]
                );
            }
            // Otherwise register the new relationship
            targetToSource[targetKey] = sourceContract;
        }

        // Store the cross-chain relationship in the main mapping
        crossChainRelations[relationshipKey] = CrossChainRelation({
            sourceContract: sourceContract,
            targetContract: targetContract,
            sourceChainId: sourceChainId,
            targetChainId: targetChainId,
            relationshipType: relationshipType
        });

        // Update tracking structures for efficient lookups
        registeredSourceContracts[relationshipType].add(sourceContract);

        // Update source to target chains mapping
        bytes32 sourceTrackingKey = _getSourceTrackingKey(
            sourceContract,
            relationshipType
        );
        sourceToTargetChains[sourceTrackingKey].push(targetChainId);

        emit CrossChainRelationshipRegistered(
            sourceContract,
            targetContract,
            sourceChainId,
            targetChainId,
            relationshipType
        );
    }

    /**
     * @notice Internal function to unregister a relationship
     * @param sourceContract The address of the source contract
     * @param relationshipType The type of relationship
     * @param targetChainId The target chain ID to identify the specific relationship
     */
    function _unregisterRelationship(
        address sourceContract,
        bytes32 relationshipType,
        uint16 targetChainId
    ) internal {
        // Generate the relationship key
        bytes32 relationshipKey = _getRelationshipKey(
            sourceContract,
            relationshipType,
            targetChainId
        );

        // Retrieve the relationship
        CrossChainRelation memory relation = crossChainRelations[
            relationshipKey
        ];

        // Verify the relationship exists before attempting to unregister
        if (relation.sourceContract == address(0)) {
            revert RelationshipDoesNotExist(
                sourceContract,
                relationshipType,
                targetChainId
            );
        }

        // Remove reverse mapping only when it was stored (inter-chain)
        bool sameChain = _isSameChain(
            relation.sourceChainId,
            relation.targetChainId
        );

        // Generate target key for reverse lookup
        bytes32 targetKey = _getTargetKey(
            relation.sourceChainId,
            relation.targetChainId,
            relation.targetContract,
            relationshipType
        );

        // If it is a cross-chain relationship, and the relationship exists, remove the reverse mapping
        if (!sameChain && targetToSource[targetKey] == sourceContract) {
            delete targetToSource[targetKey];
        }

        // Generate source tracking key
        bytes32 sourceTrackingKey = _getSourceTrackingKey(
            sourceContract,
            relationshipType
        );

        // Search for the target chain and remove it from the list
        uint16[] storage targetChains = sourceToTargetChains[sourceTrackingKey];
        for (uint256 i = 0; i < targetChains.length; i++) {
            if (targetChains[i] == targetChainId) {
                targetChains[i] = targetChains[targetChains.length - 1];
                targetChains.pop();
                break;
            }
        }

        // Remove from registered source contracts if no more relationships exist
        if (targetChains.length == 0) {
            registeredSourceContracts[relationshipType].remove(sourceContract);
        }

        // Clean up mappings
        delete crossChainRelations[relationshipKey];

        emit CrossChainRelationshipUnregistered(
            sourceContract,
            relation.targetContract,
            relation.sourceChainId,
            relation.targetChainId,
            relationshipType
        );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL QUERY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to get source for target
     * @param sourceChainId The chain ID of the source chain
     * @param targetChainId The chain ID of the target chain
     * @param targetContract The address of the target contract
     * @param relationshipType The type of relationship
     * @return sourceContract The address of the source contract, or address(0) if not found
     */
    function _getSourceForTarget(
        uint16 sourceChainId,
        uint16 targetChainId,
        address targetContract,
        bytes32 relationshipType
    ) internal view returns (address sourceContract) {
        bytes32 targetKey = _getTargetKey(
            sourceChainId,
            targetChainId,
            targetContract,
            relationshipType
        );
        sourceContract = targetToSource[targetKey];
    }

    /**
     * @notice Internal function to check if a cross-chain pair is valid
     * @param sourceContract The address of the source contract
     * @param targetContract The address of the target contract
     * @param sourceChainId The chain ID where the source contract is deployed
     * @param targetChainId The chain ID where the target contract is deployed
     * @param relationshipType The type of relationship
     * @return isValid True if the relationship exists
     */
    function _isValidCrossChainPair(
        address sourceContract,
        address targetContract,
        uint16 sourceChainId,
        uint16 targetChainId,
        bytes32 relationshipType
    ) internal view returns (bool isValid) {
        // Generate the relationship key
        bytes32 relationshipKey = _getRelationshipKey(
            sourceContract,
            relationshipType,
            targetChainId
        );

        // Retrieve the relationship
        CrossChainRelation memory relation = crossChainRelations[
            relationshipKey
        ];

        // Check if relationship exists and matches the provided parameters
        return (relation.sourceContract != address(0) &&
            relation.targetContract == targetContract &&
            relation.sourceChainId == sourceChainId &&
            relation.targetChainId == targetChainId);
    }

    /**
     * @notice Internal function to get relationship by target
     * @param sourceContract The address of the source contract
     * @param relationshipType The type of relationship
     * @param targetChainId The target chain ID
     * @return relation The complete relationship details, with zero values if not found
     */
    function _getRelationshipByTarget(
        address sourceContract,
        bytes32 relationshipType,
        uint16 targetChainId
    ) internal view returns (CrossChainRelation memory relation) {
        bytes32 relationshipKey = _getRelationshipKey(
            sourceContract,
            relationshipType,
            targetChainId
        );

        relation = crossChainRelations[relationshipKey];
    }

    /**
     * @notice Internal function to get all relationships for a source contract
     * @param sourceContract The address of the source contract
     * @param relationshipType The type of relationship
     * @return relationships Array of all relationships for the source contract
     */
    function _getRelationships(
        address sourceContract,
        bytes32 relationshipType
    ) internal view returns (CrossChainRelation[] memory relationships) {
        // Get target chain IDs for the source contract and relationship type
        uint16[] memory targetChains = _getTargetChains(
            sourceContract,
            relationshipType
        );

        // Initialize the relationships array
        relationships = new CrossChainRelation[](targetChains.length);

        // Populate the relationships array
        for (uint256 i = 0; i < targetChains.length; i++) {
            bytes32 relationshipKey = _getRelationshipKey(
                sourceContract,
                relationshipType,
                targetChains[i]
            );
            relationships[i] = crossChainRelations[relationshipKey];
        }
    }

    /**
     * @notice Internal function to get targets for source
     * @param sourceContract The address of the source contract
     * @param relationshipType The type of relationship
     * @return targetContracts Array of target contract addresses
     * @return targetChainIds Array of target chain IDs
     */
    function _getTargetsForSource(
        address sourceContract,
        bytes32 relationshipType
    )
        internal
        view
        returns (
            address[] memory targetContracts,
            uint16[] memory targetChainIds
        )
    {
        // Retrieve all relationships for the source contract
        CrossChainRelation[] memory relationships = _getRelationships(
            sourceContract,
            relationshipType
        );

        // Initialize output arrays
        targetContracts = new address[](relationships.length);
        targetChainIds = new uint16[](relationships.length);

        // Populate output arrays
        for (uint256 i = 0; i < relationships.length; i++) {
            targetContracts[i] = relationships[i].targetContract;
            targetChainIds[i] = relationships[i].targetChainId;
        }
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL ENUMERATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to get registered source contracts
     * @param relationshipType The type of relationship
     * @return sourceContracts Array of registered source contract addresses
     */
    function _getRegisteredSourceContracts(
        bytes32 relationshipType
    ) internal view returns (address[] memory sourceContracts) {
        return registeredSourceContracts[relationshipType].values();
    }

    /**
     * @notice Internal function to check if source contract is registered
     * @param sourceContract The address of the source contract
     * @param relationshipType The type of relationship
     * @return isRegistered True if the source contract is registered
     */
    function _isSourceContractRegistered(
        address sourceContract,
        bytes32 relationshipType
    ) internal view returns (bool isRegistered) {
        return
            registeredSourceContracts[relationshipType].contains(
                sourceContract
            );
    }

    /**
     * @notice Internal function to get relationship count
     * @param relationshipType The type of relationship
     * @return count The number of registered relationships
     */
    function _getRelationshipCount(
        bytes32 relationshipType
    ) internal view returns (uint256 count) {
        return registeredSourceContracts[relationshipType].length();
    }

    /**
     * @notice Internal function to get supported relationship types
     * @return relationshipTypes Array of supported relationship type hashes
     */
    function _getSupportedRelationshipTypes()
        internal
        view
        returns (bytes32[] memory relationshipTypes)
    {
        return supportedRelationshipTypes;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL UTILITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Generate a unique key for a relationship
     * @param sourceContract The source contract address
     * @param relationshipType The relationship type
     * @param targetChainId The target chain ID
     * @return key The unique relationship key
     */
    function _getRelationshipKey(
        address sourceContract,
        bytes32 relationshipType,
        uint16 targetChainId
    ) internal pure returns (bytes32 key) {
        return
            keccak256(
                abi.encode(sourceContract, relationshipType, targetChainId)
            );
    }

    /**
     * @notice Generate a unique key for target lookup
     * @param sourceChainId The source chain ID
     * @param targetChainId The target chain ID
     * @param targetContract The target contract address
     * @param relationshipType The relationship type
     * @return key The unique target key
     */
    function _getTargetKey(
        uint16 sourceChainId,
        uint16 targetChainId,
        address targetContract,
        bytes32 relationshipType
    ) internal pure returns (bytes32 key) {
        return
            keccak256(
                abi.encode(
                    sourceChainId,
                    targetChainId,
                    targetContract,
                    relationshipType
                )
            );
    }

    /**
     * @notice Generate a unique key for tracking source contracts and their relationship types
     * @param sourceContract The source contract address
     * @param relationshipType The relationship type
     * @return key The unique source tracking key
     */
    function _getSourceTrackingKey(
        address sourceContract,
        bytes32 relationshipType
    ) internal pure returns (bytes32 key) {
        return keccak256(abi.encode(sourceContract, relationshipType));
    }

    /**
     * @notice Get target chain IDs for a source contract and relationship type
     * @param sourceContract The source contract address
     * @param relationshipType The relationship type
     * @return targetChainIds Array of target chain IDs
     */
    function _getTargetChains(
        address sourceContract,
        bytes32 relationshipType
    ) internal view returns (uint16[] memory targetChainIds) {
        bytes32 sourceTrackingKey = _getSourceTrackingKey(
            sourceContract,
            relationshipType
        );
        return sourceToTargetChains[sourceTrackingKey];
    }

    /**
     * @notice Add a new relationship type to the registry
     * @param relationshipType The relationship type to add
     */
    function _addRelationshipType(bytes32 relationshipType) internal {
        // Validate that the relationship type does not already exist
        if (!relationshipTypeSupported[relationshipType]) {
            supportedRelationshipTypes.push(relationshipType);
            relationshipTypeSupported[relationshipType] = true;
            emit RelationshipTypeAdded(relationshipType);
        }
    }

    /**
     * @notice Determines if both source and target chain IDs match the current deployment chain
     * @return True if both chains are the current chain (same-chain relationship)
     */
    function _isSameChain(
        uint16 sourceChainId,
        uint16 targetChainId
    ) internal view returns (bool) {
        return
            sourceChainId == CURRENT_CHAIN_ID &&
            targetChainId == CURRENT_CHAIN_ID;
    }

    /**
     * @notice Get the current chain ID
     * @return The current chain ID
     */
    function _currentChainId() internal view returns (uint16) {
        return CURRENT_CHAIN_ID;
    }

    /**
     * @notice Internal function to set bridge router
     * @param newBridgeRouter The new bridge router address
     */
    function _setBridgeRouter(address newBridgeRouter) internal {
        if (newBridgeRouter == address(0)) {
            revert AddressZero();
        }
        emit BridgeRouterUpdated(bridgeRouter, newBridgeRouter);
        bridgeRouter = newBridgeRouter;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL GOVERNANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICrossChainRegistry
    function registerRelationship(
        address sourceContract,
        address targetContract,
        uint16 sourceChainId,
        uint16 targetChainId,
        bytes32 relationshipType
    ) external onlyGovernor {
        _registerRelationship(
            sourceContract,
            targetContract,
            sourceChainId,
            targetChainId,
            relationshipType
        );
    }

    /// @inheritdoc ICrossChainRegistry
    function unregisterRelationship(
        address sourceContract,
        bytes32 relationshipType,
        uint16 targetChainId
    ) external onlyGovernor {
        _unregisterRelationship(
            sourceContract,
            relationshipType,
            targetChainId
        );
    }

    /*//////////////////////////////////////////////////////////////
                        BRIDGE CONFIG FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICrossChainRegistry
    function setBridgeRouter(address newBridgeRouter) external onlyGovernor {
        _setBridgeRouter(newBridgeRouter);
    }

    /*//////////////////////////////////////////////////////////////
                            QUERY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICrossChainRegistry
    function getSourceForTarget(
        uint16 sourceChainId,
        uint16 targetChainId,
        address targetContract,
        bytes32 relationshipType
    ) external view returns (address sourceContract) {
        return
            _getSourceForTarget(
                sourceChainId,
                targetChainId,
                targetContract,
                relationshipType
            );
    }

    /// @inheritdoc ICrossChainRegistry
    function isValidCrossChainPair(
        address sourceContract,
        address targetContract,
        uint16 sourceChainId,
        uint16 targetChainId,
        bytes32 relationshipType
    ) external view returns (bool isValid) {
        return
            _isValidCrossChainPair(
                sourceContract,
                targetContract,
                sourceChainId,
                targetChainId,
                relationshipType
            );
    }

    /// @inheritdoc ICrossChainRegistry
    function getRelationship(
        address sourceContract,
        bytes32 relationshipType
    ) external view returns (CrossChainRelation memory relation) {
        CrossChainRelation[] memory relationships = _getRelationships(
            sourceContract,
            relationshipType
        );

        if (relationships.length == 0) {
            // Return empty relationship struct when no relationships exist
            return
                CrossChainRelation({
                    sourceContract: address(0),
                    targetContract: address(0),
                    sourceChainId: 0,
                    targetChainId: 0,
                    relationshipType: bytes32(0)
                });
        }

        // Return the first relationship found
        return relationships[0];
    }

    /// @inheritdoc ICrossChainRegistry
    function getAllTargetsForSource(
        address sourceContract,
        bytes32 relationshipType
    )
        external
        view
        returns (
            address[] memory targetContracts,
            uint16[] memory targetChainIds
        )
    {
        return _getTargetsForSource(sourceContract, relationshipType);
    }

    /// @inheritdoc ICrossChainRegistry
    function getRelationshipByTarget(
        address sourceContract,
        bytes32 relationshipType,
        uint16 targetChainId
    ) external view returns (CrossChainRelation memory relation) {
        return
            _getRelationshipByTarget(
                sourceContract,
                relationshipType,
                targetChainId
            );
    }

    /*//////////////////////////////////////////////////////////////
                        ENUMERATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICrossChainRegistry
    function getRegisteredSourceContracts(
        bytes32 relationshipType
    ) external view returns (address[] memory sourceContracts) {
        return _getRegisteredSourceContracts(relationshipType);
    }

    /// @inheritdoc ICrossChainRegistry
    function isSourceContractRegistered(
        address sourceContract,
        bytes32 relationshipType
    ) external view returns (bool isRegistered) {
        return _isSourceContractRegistered(sourceContract, relationshipType);
    }

    /// @inheritdoc ICrossChainRegistry
    function getRelationshipCount(
        bytes32 relationshipType
    ) external view override returns (uint256 count) {
        return _getRelationshipCount(relationshipType);
    }

    /// @inheritdoc ICrossChainRegistry
    function getSupportedRelationshipTypes()
        external
        view
        returns (bytes32[] memory relationshipTypes)
    {
        return _getSupportedRelationshipTypes();
    }

    /// @inheritdoc ICrossChainRegistry
    function addSupportedRelationshipType(
        bytes32 relationshipType
    ) external onlyGovernor {
        _addRelationshipType(relationshipType);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICrossChainRegistry
    function currentChainId() external view returns (uint16) {
        return _currentChainId();
    }
}
