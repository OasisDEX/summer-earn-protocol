// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {ICrossChainRegistry} from "../interfaces/ICrossChainRegistry.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title CrossChainRegistry
 * @notice Generic centralized registry for managing cross-chain relationships between different contract types
 * @dev Inherits from ProtocolAccessManaged for access control and implements ICrossChainRegistry with support for multiple relationship types
 */
contract CrossChainRegistry is ICrossChainRegistry, ProtocolAccessManaged {
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The chain ID of the current deployment
    uint16 public immutable currentChainId;

    /// @notice Mapping from relationship key to relationship information
    /// Key: keccak256(abi.encode(sourceContract, relationshipType))
    mapping(bytes32 => CrossChainRelation) private crossChainRelations;

    /// @notice Mapping from target key to source contract address
    /// Key: keccak256(abi.encode(sourceChainId, targetChainId, targetContract, relationshipType))
    mapping(bytes32 => address) private targetToSource;

    /// @notice EnumerableSet of all registered source contracts per relationship type
    mapping(bytes32 => EnumerableSet.AddressSet)
        private registeredSourceContracts;

    /// @notice Mapping to track all target chain IDs for each source contract and relationship type
    /// Key: keccak256(abi.encode(sourceContract, relationshipType))
    mapping(bytes32 => uint16[]) private sourceToTargetChains;

    /// @notice Array of supported relationship types
    bytes32[] private supportedRelationshipTypes;

    /// @notice Mapping to track if a relationship type is supported
    mapping(bytes32 => bool) private relationshipTypeSupported;

    /// @notice Flag to track if bridge configuration has been initialized
    bool public bridgeConfigInitialized;

    /// @notice The bridge queue contract address
    address public bridgeQueue;

    /// @notice The bridge router contract address
    address public bridgeRouter;

    /// @notice The default gas limit for cross-chain transactions
    uint256 public defaultGasLimit;

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
        if (relationshipType == bytes32(0))
            revert InvalidRelationshipType(relationshipType);

        // Enhanced chain ID validation
        _validateChainIds(sourceChainId, targetChainId);

        // Add relationship type if not already supported
        if (!relationshipTypeSupported[relationshipType]) {
            _addRelationshipType(relationshipType);
        }

        bytes32 relationshipKey = _getRelationshipKey(
            sourceContract,
            relationshipType,
            targetChainId
        );

        // Check if this specific relationship already exists
        if (crossChainRelations[relationshipKey].sourceContract != address(0)) {
            revert RelationshipAlreadyExists(
                sourceContract,
                relationshipType,
                targetChainId
            );
        }

        // Check if target contract is already registered for this relationship type
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

        // Create the relationship
        crossChainRelations[relationshipKey] = CrossChainRelation({
            sourceContract: sourceContract,
            targetContract: targetContract,
            sourceChainId: sourceChainId,
            targetChainId: targetChainId,
            relationshipType: relationshipType
        });

        // Set reverse mapping
        targetToSource[targetKey] = sourceContract;

        // Update tracking
        registeredSourceContracts[relationshipType].add(sourceContract);

        // Update sourceToTargetChains
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

    /// @inheritdoc ICrossChainRegistry
    function unregisterCrossChainRelationship(
        address sourceContract,
        bytes32 relationshipType,
        uint16 targetChainId
    ) external override onlyGovernor {
        bytes32 relationshipKey = _getRelationshipKey(
            sourceContract,
            relationshipType,
            targetChainId
        );

        // Check if this specific relationship exists
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

        // Remove reverse mapping
        bytes32 targetKey = _getTargetKey(
            relation.sourceChainId,
            relation.targetChainId,
            relation.targetContract,
            relationshipType
        );
        delete targetToSource[targetKey];

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
                        BRIDGE CONFIG FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the bridge configuration parameters
     * @param _bridgeQueue The address of the bridge queue contract
     * @param _bridgeRouter The address of the bridge router contract
     * @param _defaultGasLimit The default gas limit for cross-chain transactions
     */
    function initializeBridgeConfiguration(
        address _bridgeQueue,
        address _bridgeRouter,
        uint256 _defaultGasLimit
    ) external onlyGovernor {
        if (bridgeConfigInitialized) {
            revert BridgeConfigAlreadyInitialized();
        }

        if (_bridgeQueue == address(0) || _bridgeRouter == address(0)) {
            revert AddressZero();
        }

        if (_defaultGasLimit == 0) {
            revert InvalidGasLimit();
        }

        bridgeQueue = _bridgeQueue;
        bridgeRouter = _bridgeRouter;
        defaultGasLimit = _defaultGasLimit;

        emit BridgeQueueUpdated(address(0), _bridgeQueue);
        emit BridgeRouterUpdated(address(0), _bridgeRouter);
        emit DefaultGasLimitUpdated(0, _defaultGasLimit);

        bridgeConfigInitialized = true;
    }

    /**
     * @notice Updates the bridge queue address
     * @param newBridgeQueue The new bridge queue address
     */
    function setBridgeQueue(address newBridgeQueue) external onlyGovernor {
        if (newBridgeQueue == address(0)) {
            revert AddressZero();
        }
        emit BridgeQueueUpdated(bridgeQueue, newBridgeQueue);
        bridgeQueue = newBridgeQueue;
    }

    /**
     * @notice Updates the bridge router address
     * @param newBridgeRouter The new bridge router address
     */
    function setBridgeRouter(address newBridgeRouter) external onlyGovernor {
        if (newBridgeRouter == address(0)) {
            revert AddressZero();
        }
        emit BridgeRouterUpdated(bridgeRouter, newBridgeRouter);
        bridgeRouter = newBridgeRouter;
    }

    /**
     * @notice Updates the default gas limit
     * @param newDefaultGasLimit The new default gas limit
     */
    function setDefaultGasLimit(
        uint256 newDefaultGasLimit
    ) external onlyGovernor {
        if (newDefaultGasLimit == 0) {
            revert InvalidGasLimit();
        }
        emit DefaultGasLimitUpdated(defaultGasLimit, newDefaultGasLimit);
        defaultGasLimit = newDefaultGasLimit;
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

        // Get the first target chain for this source contract and relationship type
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

    /// @inheritdoc ICrossChainRegistry
    function getSourceForTarget(
        uint16 sourceChainId,
        uint16 targetChainId,
        address targetContract,
        bytes32 relationshipType
    ) external view override returns (address sourceContract) {
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

    /// @inheritdoc ICrossChainRegistry
    function isValidCrossChainPair(
        address sourceContract,
        address targetContract,
        uint16 sourceChainId,
        uint16 targetChainId,
        bytes32 relationshipType
    ) external view override returns (bool isValid) {
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

    /// @inheritdoc ICrossChainRegistry
    function getRelationship(
        address sourceContract,
        bytes32 relationshipType
    ) external view override returns (CrossChainRelation memory relation) {
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

        // Get the first target chain for this source contract and relationship type
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
        external
        view
        override
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

    /// @inheritdoc ICrossChainRegistry
    function getRelationshipByTarget(
        address sourceContract,
        bytes32 relationshipType,
        uint16 targetChainId
    ) external view override returns (CrossChainRelation memory relation) {
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

    /*//////////////////////////////////////////////////////////////
                        ENUMERATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICrossChainRegistry
    function getRegisteredSourceContracts(
        bytes32 relationshipType
    ) external view override returns (address[] memory sourceContracts) {
        return registeredSourceContracts[relationshipType].values();
    }

    /// @inheritdoc ICrossChainRegistry
    function isSourceContractRegistered(
        address sourceContract,
        bytes32 relationshipType
    ) external view override returns (bool isRegistered) {
        return
            registeredSourceContracts[relationshipType].contains(
                sourceContract
            );
    }

    /// @inheritdoc ICrossChainRegistry
    function getRelationshipCount(
        bytes32 relationshipType
    ) external view override returns (uint256 count) {
        return registeredSourceContracts[relationshipType].length();
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
     * @notice Validate chain IDs for cross-chain relationships
     * @param sourceChainId The source chain ID to validate
     * @param targetChainId The target chain ID to validate
     */
    function _validateChainIds(
        uint16 sourceChainId,
        uint16 targetChainId
    ) internal view {
        // Basic non-zero validation
        if (sourceChainId == 0) revert InvalidChainId(sourceChainId);
        if (targetChainId == 0) revert InvalidChainId(targetChainId);

        // Prevent same-chain relationships for cross-chain registry
        if (sourceChainId == targetChainId) {
            revert SameChainRelationship(sourceChainId);
        }

        // At least one chain must be the deployment chain
        if (
            sourceChainId != currentChainId && targetChainId != currentChainId
        ) {
            revert InvalidChainRelationship(
                sourceChainId,
                targetChainId,
                currentChainId
            );
        }
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
}
