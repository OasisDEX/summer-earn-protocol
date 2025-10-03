// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICrossChainRegistry} from "../interfaces/ICrossChainRegistry.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";

/**
 * @title BaseCrossChainRegistry
 * @notice Abstract base contract for managing cross-chain relationships between different contract types
 * @dev Provides core functionality for cross-chain relationship management with internal methods
 * that can be extended by specialized registry contracts
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
    /// Key: keccak256(abi.encode(sourceContract, relationshipType, targetChainId))
    mapping(bytes32 => CrossChainRelation) internal crossChainRelations;

    /// @notice Mapping from target key to source contract address
    /// Key: keccak256(abi.encode(sourceChainId, targetChainId, targetContract, relationshipType))
    mapping(bytes32 => address) private targetToSource;

    /// @notice EnumerableSet of all registered source contracts per relationship type
    mapping(bytes32 => EnumerableSet.AddressSet)
        private registeredSourceContracts;

    /// @notice Mapping to track all target chain IDs for each source contract and relationship type
    /// Key: keccak256(abi.encode(sourceContract, relationshipType))
    mapping(bytes32 => uint16[]) internal sourceToTargetChains;

    /// @notice Array of supported relationship types
    bytes32[] private supportedRelationshipTypes;

    /// @notice Mapping to track if a relationship type is supported
    mapping(bytes32 => bool) private relationshipTypeSupported;

    /// @notice The bridge router contract address
    address public bridgeRouter;

    /// @notice Constants for relationship types
    bytes32 public constant PEER_RELATIONSHIP = keccak256("PEER_RELATIONSHIP");
    bytes32 public constant EXECUTOR_RELATIONSHIP =
        keccak256("EXECUTOR_RELATIONSHIP");

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the BaseCrossChainRegistry
     * @param _accessManager Address of the access manager
     */
    constructor(address _accessManager) ProtocolAccessManaged(_accessManager) {
        CURRENT_CHAIN_ID = uint16(block.chainid);

        _addRelationshipType(PEER_RELATIONSHIP);
        _addRelationshipType(EXECUTOR_RELATIONSHIP);

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

        // basic parameter validation
        if (sourceContract == address(0))
            revert InvalidSourceContract(sourceContract);
        if (targetContract == address(0))
            revert InvalidTargetContract(targetContract);
        if (relationshipType == bytes32(0))
            revert InvalidRelationshipType(relationshipType);

        // enforce that relationship type must be supported
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
            bytes32 targetKey = _getTargetKey(
                sourceChainId,
                targetChainId,
                targetContract,
                relationshipType
            );
            if (targetToSource[targetKey] != address(0)) {
                revert TargetContractAlreadyRegistered(
                    targetContract,
                    sourceChainId,
                    targetChainId,
                    relationshipType,
                    targetToSource[targetKey]
                );
            }
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
        bytes32 relationshipKey = _getRelationshipKey(
            sourceContract,
            relationshipType,
            targetChainId
        );

        // Verify the relationship exists before attempting to unregister
        if (crossChainRelations[relationshipKey].sourceContract == address(0)) {
            revert RelationshipDoesNotExist(
                sourceContract,
                relationshipType,
                targetChainId
            );
        }

        CrossChainRelation memory relation = crossChainRelations[
            relationshipKey
        ];

        // Remove reverse mapping only when it was stored (inter-chain)
        bool sameChain = _isSameChain(
            relation.sourceChainId,
            relation.targetChainId
        );
        bytes32 targetKey = _getTargetKey(
            relation.sourceChainId,
            relation.targetChainId,
            relation.targetContract,
            relationshipType
        );

        if (!sameChain && targetToSource[targetKey] == sourceContract) {
            delete targetToSource[targetKey];
        }

        // Remove from sourceToTargetChains
        bytes32 sourceTrackingKey = _getSourceTrackingKey(
            sourceContract,
            relationshipType
        );
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
     * @notice Internal function to get target for source
     * @param sourceContract The address of the source contract
     * @param relationshipType The type of relationship
     * @return targetContract The address of the target contract
     * @return targetChainId The chain ID where the target contract is deployed
     */
    function _getTargetForSource(
        address sourceContract,
        bytes32 relationshipType
    ) internal view returns (address targetContract, uint16 targetChainId) {
        if (
            !registeredSourceContracts[relationshipType].contains(
                sourceContract
            )
        ) {
            revert RelationshipDoesNotExist(
                sourceContract,
                relationshipType,
                0
            );
        }

        // Get the first registered target chain for this source contract and relationship type
        // Note: Returns only the first relationship found, not necessarily all relationships
        bytes32 sourceTrackingKey = _getSourceTrackingKey(
            sourceContract,
            relationshipType
        );
        uint16[] memory targetChains = sourceToTargetChains[sourceTrackingKey];

        if (targetChains.length == 0) {
            revert RelationshipDoesNotExist(
                sourceContract,
                relationshipType,
                0
            );
        }

        uint16 firstTargetChainId = targetChains[0];
        bytes32 relationshipKey = _getRelationshipKey(
            sourceContract,
            relationshipType,
            firstTargetChainId
        );

        CrossChainRelation memory relation = crossChainRelations[
            relationshipKey
        ];
        return (relation.targetContract, relation.targetChainId);
    }

    /**
     * @notice Internal function to get source for target
     * @param sourceChainId The chain ID of the source chain
     * @param targetChainId The chain ID of the target chain
     * @param targetContract The address of the target contract
     * @param relationshipType The type of relationship
     * @return sourceContract The address of the source contract
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

        if (sourceContract == address(0)) {
            revert RelationshipDoesNotExist(
                address(0),
                relationshipType,
                targetChainId
            );
        }
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
        bytes32 relationshipKey = _getRelationshipKey(
            sourceContract,
            relationshipType,
            targetChainId
        );

        if (
            !registeredSourceContracts[relationshipType].contains(
                sourceContract
            )
        ) {
            return false;
        }

        CrossChainRelation memory relation = crossChainRelations[
            relationshipKey
        ];
        return (relation.targetContract == targetContract &&
            relation.sourceChainId == sourceChainId &&
            relation.targetChainId == targetChainId);
    }

    /**
     * @notice Internal function to get relationship by target
     * @param sourceContract The address of the source contract
     * @param relationshipType The type of relationship
     * @param targetChainId The target chain ID
     * @return relation The complete relationship details
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
        if (relation.sourceContract == address(0)) {
            revert RelationshipDoesNotExist(
                sourceContract,
                relationshipType,
                targetChainId
            );
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
        bytes32 sourceTrackingKey = _getSourceTrackingKey(
            sourceContract,
            relationshipType
        );
        uint16[] memory targetChains = sourceToTargetChains[sourceTrackingKey];

        targetContracts = new address[](targetChains.length);
        targetChainIds = new uint16[](targetChains.length);

        for (uint256 i = 0; i < targetChains.length; i++) {
            bytes32 relationshipKey = _getRelationshipKey(
                sourceContract,
                relationshipType,
                targetChains[i]
            );
            CrossChainRelation memory relation = crossChainRelations[
                relationshipKey
            ];
            targetContracts[i] = relation.targetContract;
            targetChainIds[i] = relation.targetChainId;
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
     * @notice Add a new relationship type to the registry
     * @param relationshipType The relationship type to add
     */
    function _addRelationshipType(bytes32 relationshipType) internal {
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
    ) public onlyGovernor {
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
    ) public onlyGovernor {
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
    function getTargetForSource(
        address sourceContract,
        bytes32 relationshipType
    ) public view returns (address targetContract, uint16 targetChainId) {
        return _getTargetForSource(sourceContract, relationshipType);
    }

    /// @inheritdoc ICrossChainRegistry
    function getSourceForTarget(
        uint16 sourceChainId,
        uint16 targetChainId,
        address targetContract,
        bytes32 relationshipType
    ) public view returns (address sourceContract) {
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
    ) public view returns (bool isValid) {
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
        if (!_isSourceContractRegistered(sourceContract, relationshipType)) {
            revert RelationshipDoesNotExist(
                sourceContract,
                relationshipType,
                0
            );
        }

        // Get the first registered target chain for this source contract and relationship type
        // Note: Returns only the first relationship found, not necessarily all relationships
        bytes32 sourceTrackingKey = _getSourceTrackingKey(
            sourceContract,
            relationshipType
        );
        uint16[] memory targetChains = sourceToTargetChains[sourceTrackingKey];

        if (targetChains.length == 0) {
            revert RelationshipDoesNotExist(
                sourceContract,
                relationshipType,
                0
            );
        }

        uint16 firstTargetChainId = targetChains[0];
        bytes32 relationshipKey = _getRelationshipKey(
            sourceContract,
            relationshipType,
            firstTargetChainId
        );

        return crossChainRelations[relationshipKey];
    }

    /// @inheritdoc ICrossChainRegistry
    function getTargetsForSource(
        address sourceContract,
        bytes32 relationshipType
    )
        public
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
