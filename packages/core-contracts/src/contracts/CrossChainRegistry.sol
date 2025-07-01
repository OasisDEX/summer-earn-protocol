// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {ICrossChainRegistry} from "../interfaces/ICrossChainRegistry.sol";

/**
 * @title CrossChainRegistry
 * @notice Generic centralized registry for managing cross-chain relationships between different contract types
 * @dev Inherits from ProtocolAccessManaged for access control and implements ICrossChainRegistry with support for multiple relationship types
 */
contract CrossChainRegistry is ICrossChainRegistry, ProtocolAccessManaged {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The chain ID of the current deployment
    uint16 public immutable currentChainId;

    /// @notice Mapping from relationship key to relationship information
    /// Key: keccak256(abi.encode(sourceContract, relationshipType))
    mapping(bytes32 => CrossChainRelation) private crossChainRelations;

    /// @notice Mapping from target key to source contract address
    /// Key: keccak256(abi.encode(sourceChainId, targetContract, relationshipType))
    mapping(bytes32 => address) private targetToSource;

    /// @notice Array of all registered source contracts per relationship type
    mapping(bytes32 => address[]) private registeredSourceContracts;

    /// @notice Mapping to track if a source contract is registered for a relationship type
    mapping(bytes32 => bool) private sourceContractRegistered;

    /// @notice Array of supported relationship types
    bytes32[] private supportedRelationshipTypes;

    /// @notice Mapping to track if a relationship type is supported
    mapping(bytes32 => bool) private relationshipTypeSupported;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the registry is initialized
    event RegistryInitialized(uint16 currentChainId);

    /// @notice Emitted when a new relationship type is added
    event RelationshipTypeAdded(bytes32 indexed relationshipType);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the current chain ID is zero
    error InvalidCurrentChainId();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the CrossChainRegistry
     * @param _accessManager Address of the access manager
     * @param _currentChainId The chain ID of the current deployment
     */
    constructor(
        address _accessManager,
        uint16 _currentChainId
    ) ProtocolAccessManaged(_accessManager) {
        if (_currentChainId == 0) revert InvalidCurrentChainId();

        currentChainId = _currentChainId;

        // Add the default ARK_FLEET relationship type
        _addRelationshipType(keccak256("ARK_FLEET"));

        emit RegistryInitialized(_currentChainId);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL GOVERNANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICrossChainRegistry
    function registerCrossChainRelationship(
        address sourceContract,
        address targetContract,
        uint16 sourceChainId,
        uint16 targetChainId,
        bytes32 relationshipType
    ) external override onlyGovernor {
        if (sourceContract == address(0))
            revert InvalidSourceContract(sourceContract);
        if (targetContract == address(0))
            revert InvalidTargetContract(targetContract);
        if (sourceChainId == 0) revert InvalidChainId(sourceChainId);
        if (targetChainId == 0) revert InvalidChainId(targetChainId);
        if (relationshipType == bytes32(0))
            revert InvalidRelationshipType(relationshipType);

        // Add relationship type if not already supported
        if (!relationshipTypeSupported[relationshipType]) {
            _addRelationshipType(relationshipType);
        }

        bytes32 relationshipKey = _getRelationshipKey(
            sourceContract,
            relationshipType
        );

        // Check if relationship already exists
        if (sourceContractRegistered[relationshipKey]) {
            revert RelationshipAlreadyExists(sourceContract, relationshipType);
        }

        // Check if target contract is already registered for this relationship type
        bytes32 targetKey = _getTargetKey(
            sourceChainId,
            targetContract,
            relationshipType
        );
        if (targetToSource[targetKey] != address(0)) {
            revert TargetContractAlreadyRegistered(
                targetContract,
                sourceChainId,
                relationshipType,
                targetToSource[targetKey]
            );
        }

        // Create the relationship
        crossChainRelations[relationshipKey] = CrossChainRelation({
            sourceContract: sourceContract,
            targetContract: targetContract,
            sourceChainId: sourceChainId,
            targetChainId: targetChainId,
            relationshipType: relationshipType,
            isActive: true
        });

        // Set reverse mapping
        targetToSource[targetKey] = sourceContract;

        // Update tracking
        registeredSourceContracts[relationshipType].push(sourceContract);
        sourceContractRegistered[relationshipKey] = true;

        emit CrossChainRelationshipRegistered(
            sourceContract,
            targetContract,
            sourceChainId,
            targetChainId,
            relationshipType
        );
    }

    /// @inheritdoc ICrossChainRegistry
    function unregisterCrossChainRelationship(
        address sourceContract,
        bytes32 relationshipType
    ) external override onlyGovernor {
        bytes32 relationshipKey = _getRelationshipKey(
            sourceContract,
            relationshipType
        );

        if (!sourceContractRegistered[relationshipKey]) {
            revert RelationshipDoesNotExist(sourceContract, relationshipType);
        }

        CrossChainRelation memory relation = crossChainRelations[
            relationshipKey
        ];

        // Remove reverse mapping
        bytes32 targetKey = _getTargetKey(
            relation.sourceChainId,
            relation.targetContract,
            relationshipType
        );
        delete targetToSource[targetKey];

        // Remove from registered source contracts array
        address[] storage sources = registeredSourceContracts[relationshipType];
        for (uint256 i = 0; i < sources.length; i++) {
            if (sources[i] == sourceContract) {
                sources[i] = sources[sources.length - 1];
                sources.pop();
                break;
            }
        }

        // Clean up mappings
        delete crossChainRelations[relationshipKey];
        delete sourceContractRegistered[relationshipKey];

        emit CrossChainRelationshipUnregistered(
            sourceContract,
            relation.targetContract,
            relation.sourceChainId,
            relation.targetChainId,
            relationshipType
        );
    }

    /// @inheritdoc ICrossChainRegistry
    function updateRelationshipStatus(
        address sourceContract,
        bytes32 relationshipType,
        bool isActive
    ) external override onlyGovernor {
        bytes32 relationshipKey = _getRelationshipKey(
            sourceContract,
            relationshipType
        );

        if (!sourceContractRegistered[relationshipKey]) {
            revert RelationshipDoesNotExist(sourceContract, relationshipType);
        }

        crossChainRelations[relationshipKey].isActive = isActive;
        emit RelationshipStatusUpdated(
            sourceContract,
            relationshipType,
            isActive
        );
    }

    /*//////////////////////////////////////////////////////////////
                            QUERY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICrossChainRegistry
    function getTargetForSource(
        address sourceContract,
        bytes32 relationshipType
    )
        external
        view
        override
        returns (address targetContract, uint16 targetChainId)
    {
        bytes32 relationshipKey = _getRelationshipKey(
            sourceContract,
            relationshipType
        );

        if (!sourceContractRegistered[relationshipKey]) {
            revert RelationshipDoesNotExist(sourceContract, relationshipType);
        }

        CrossChainRelation memory relation = crossChainRelations[
            relationshipKey
        ];
        return (relation.targetContract, relation.targetChainId);
    }

    /// @inheritdoc ICrossChainRegistry
    function getSourceForTarget(
        uint16 sourceChainId,
        address targetContract,
        bytes32 relationshipType
    ) external view override returns (address sourceContract) {
        bytes32 targetKey = _getTargetKey(
            sourceChainId,
            targetContract,
            relationshipType
        );
        sourceContract = targetToSource[targetKey];

        if (sourceContract == address(0)) {
            revert RelationshipDoesNotExist(targetContract, relationshipType);
        }
    }

    /// @inheritdoc ICrossChainRegistry
    function isValidCrossChainPair(
        address sourceContract,
        address targetContract,
        uint16 sourceChainId,
        bytes32 relationshipType
    ) external view override returns (bool isValid) {
        bytes32 relationshipKey = _getRelationshipKey(
            sourceContract,
            relationshipType
        );

        if (!sourceContractRegistered[relationshipKey]) {
            return false;
        }

        CrossChainRelation memory relation = crossChainRelations[
            relationshipKey
        ];
        return (relation.targetContract == targetContract &&
            relation.sourceChainId == sourceChainId &&
            relation.isActive);
    }

    /// @inheritdoc ICrossChainRegistry
    function getRelationship(
        address sourceContract,
        bytes32 relationshipType
    ) external view override returns (CrossChainRelation memory relation) {
        bytes32 relationshipKey = _getRelationshipKey(
            sourceContract,
            relationshipType
        );

        if (!sourceContractRegistered[relationshipKey]) {
            revert RelationshipDoesNotExist(sourceContract, relationshipType);
        }

        return crossChainRelations[relationshipKey];
    }

    /*//////////////////////////////////////////////////////////////
                        ENUMERATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICrossChainRegistry
    function getRegisteredSourceContracts(
        bytes32 relationshipType
    ) external view override returns (address[] memory sourceContracts) {
        return registeredSourceContracts[relationshipType];
    }

    /// @inheritdoc ICrossChainRegistry
    function isSourceContractRegistered(
        address sourceContract,
        bytes32 relationshipType
    ) external view override returns (bool isRegistered) {
        bytes32 relationshipKey = _getRelationshipKey(
            sourceContract,
            relationshipType
        );
        return sourceContractRegistered[relationshipKey];
    }

    /// @inheritdoc ICrossChainRegistry
    function getRelationshipCount(
        bytes32 relationshipType
    ) external view override returns (uint256 count) {
        return registeredSourceContracts[relationshipType].length;
    }

    /// @inheritdoc ICrossChainRegistry
    function getSupportedRelationshipTypes()
        external
        view
        override
        returns (bytes32[] memory relationshipTypes)
    {
        return supportedRelationshipTypes;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Generate a unique key for a relationship
     * @param sourceContract The source contract address
     * @param relationshipType The relationship type
     * @return key The unique relationship key
     */
    function _getRelationshipKey(
        address sourceContract,
        bytes32 relationshipType
    ) internal pure returns (bytes32 key) {
        return keccak256(abi.encode(sourceContract, relationshipType));
    }

    /**
     * @notice Generate a unique key for target lookup
     * @param sourceChainId The source chain ID
     * @param targetContract The target contract address
     * @param relationshipType The relationship type
     * @return key The unique target key
     */
    function _getTargetKey(
        uint16 sourceChainId,
        address targetContract,
        bytes32 relationshipType
    ) internal pure returns (bytes32 key) {
        return
            keccak256(
                abi.encode(sourceChainId, targetContract, relationshipType)
            );
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
}
