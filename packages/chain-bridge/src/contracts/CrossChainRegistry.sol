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

    /// @notice The bridge router contract address
    address public bridgeRouter;

    /// @notice The default gas limit for cross-chain transactions
    uint256 public defaultGasLimit;

    /// @notice Constants for relationship types
    bytes32 public constant ADAPTER_PEER = keccak256("ADAPTER_PEER");
    bytes32 public constant ARK_FLEET = keccak256("ARK_FLEET");
    bytes32 public constant EXECUTOR = keccak256("EXECUTOR"); // New constant

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

        _addRelationshipType(ADAPTER_PEER);
        _addRelationshipType(ARK_FLEET);

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
    ) public onlyGovernor {
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
    ) public onlyGovernor {
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
     * @param _bridgeRouter The address of the bridge router contract
     * @param _defaultGasLimit The default gas limit for cross-chain transactions
     */
    function initializeBridgeConfiguration(
        address _bridgeRouter,
        uint256 _defaultGasLimit
    ) external onlyGovernor {
        if (bridgeConfigInitialized) {
            revert BridgeConfigAlreadyInitialized();
        }

        if (_bridgeRouter == address(0)) {
            revert AddressZero();
        }

        if (_defaultGasLimit == 0) {
            revert InvalidGasLimit();
        }

        bridgeRouter = _bridgeRouter;
        defaultGasLimit = _defaultGasLimit;

        emit BridgeRouterUpdated(address(0), _bridgeRouter);
        emit DefaultGasLimitUpdated(0, _defaultGasLimit);

        bridgeConfigInitialized = true;
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
    ) public view returns (address targetContract, uint16 targetChainId) {
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
    ) public view returns (address sourceContract) {
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
    ) public view returns (bool isValid) {
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
    ) external view returns (CrossChainRelation memory relation) {
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
        public
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

    /// @inheritdoc ICrossChainRegistry
    function getRelationshipByTarget(
        address sourceContract,
        bytes32 relationshipType,
        uint16 targetChainId
    ) external view returns (CrossChainRelation memory relation) {
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
    ) external view returns (address[] memory sourceContracts) {
        return registeredSourceContracts[relationshipType].values();
    }

    /// @inheritdoc ICrossChainRegistry
    function isSourceContractRegistered(
        address sourceContract,
        bytes32 relationshipType
    ) external view returns (bool isRegistered) {
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
        returns (bytes32[] memory relationshipTypes)
    {
        return supportedRelationshipTypes;
    }

    /*//////////////////////////////////////////////////////////////
                        ADAPTER PEER CONVENIENCE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Register a peer relationship between two bridge adapters
     * @param sourceAdapter Address of the source adapter
     * @param targetAdapter Address of the target adapter
     * @param sourceChainId Chain ID where the source adapter is deployed
     * @param targetChainId Chain ID where the target adapter is deployed
     */
    function registerAdapterPeer(
        address sourceAdapter,
        address targetAdapter,
        uint16 sourceChainId,
        uint16 targetChainId
    ) external onlyGovernor {
        registerCrossChainRelationship(
            sourceAdapter,
            targetAdapter,
            sourceChainId,
            targetChainId,
            ADAPTER_PEER
        );
    }

    /**
     * @notice Get the peer adapter address for a given source adapter and target chain
     * @param sourceAdapter Address of the source adapter
     * @param targetChainId Chain ID where the target adapter is deployed
     * @return targetAdapter Address of the target adapter
     */
    function getAdapterPeer(
        address sourceAdapter,
        uint16 targetChainId
    ) external view returns (address targetAdapter) {
        (targetAdapter, ) = getTargetForSource(sourceAdapter, ADAPTER_PEER);

        // Validate the target chain matches
        bytes32 relationshipKey = _getRelationshipKey(
            sourceAdapter,
            ADAPTER_PEER,
            targetChainId
        );
        CrossChainRelation memory relation = crossChainRelations[
            relationshipKey
        ];
        if (relation.targetChainId != targetChainId) {
            revert InvalidChainRelationship(
                relation.sourceChainId,
                targetChainId,
                currentChainId
            );
        }
    }

    /**
     * @notice Check if two adapters are registered as valid peers
     * @param sourceAdapter Address of the source adapter
     * @param targetAdapter Address of the target adapter
     * @param sourceChainId Chain ID where the source adapter is deployed
     * @param targetChainId Chain ID where the target adapter is deployed
     * @return True if the adapters are registered peers
     */
    function isValidAdapterPeer(
        address sourceAdapter,
        address targetAdapter,
        uint16 sourceChainId,
        uint16 targetChainId
    ) external view returns (bool) {
        return
            isValidCrossChainPair(
                sourceAdapter,
                targetAdapter,
                sourceChainId,
                targetChainId,
                ADAPTER_PEER
            );
    }

    /*//////////////////////////////////////////////////////////////
                        ARK/FLEET CONVENIENCE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Register a relationship between an Ark and its Fleet
     * @param arkProxy Address of the Ark proxy
     * @param fleetProxy Address of the Fleet proxy
     * @param arkChainId Chain ID where the Ark is deployed
     * @param fleetChainId Chain ID where the Fleet is deployed
     */
    function registerArkFleet(
        address arkProxy,
        address fleetProxy,
        uint16 arkChainId,
        uint16 fleetChainId
    ) external onlyGovernor {
        registerCrossChainRelationship(
            arkProxy,
            fleetProxy,
            arkChainId,
            fleetChainId,
            ARK_FLEET
        );
    }

    /**
     * @notice Get the Fleet proxy address for a given Ark proxy
     * @param arkProxy Address of the Ark proxy
     * @return fleetProxy Address of the Fleet proxy
     * @return fleetChainId Chain ID where the Fleet is deployed
     */
    function getFleetForArk(
        address arkProxy
    ) external view returns (address fleetProxy, uint16 fleetChainId) {
        return getTargetForSource(arkProxy, ARK_FLEET);
    }

    /**
     * @notice Get the Ark proxy address for a given Fleet proxy and chain IDs
     * @param fleetProxy Address of the Fleet proxy
     * @param arkChainId Chain ID where the Ark is deployed
     * @param fleetChainId Chain ID where the Fleet is deployed
     * @return arkProxy Address of the Ark proxy
     */
    function getArkForFleet(
        address fleetProxy,
        uint16 arkChainId,
        uint16 fleetChainId
    ) external view returns (address arkProxy) {
        return
            getSourceForTarget(arkChainId, fleetChainId, fleetProxy, ARK_FLEET);
    }

    /**
     * @notice Check if an Ark and Fleet are properly registered
     * @param arkProxy Address of the Ark proxy
     * @param fleetProxy Address of the Fleet proxy
     * @param arkChainId Chain ID where the Ark is deployed
     * @param fleetChainId Chain ID where the Fleet is deployed
     * @return True if the Ark and Fleet are properly registered
     */
    function isValidArkFleet(
        address arkProxy,
        address fleetProxy,
        uint16 arkChainId,
        uint16 fleetChainId
    ) external view returns (bool) {
        return
            isValidCrossChainPair(
                arkProxy,
                fleetProxy,
                arkChainId,
                fleetChainId,
                ARK_FLEET
            );
    }

    /**
     * @notice Get all Fleets registered for a given Ark
     * @param arkProxy Address of the Ark proxy
     * @return fleetProxies Array of Fleet proxy addresses
     * @return fleetChainIds Array of chain IDs where the Fleets are deployed
     */
    function getAllFleetsForArk(
        address arkProxy
    )
        external
        view
        returns (address[] memory fleetProxies, uint16[] memory fleetChainIds)
    {
        return getTargetsForSource(arkProxy, ARK_FLEET);
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
     * @notice Register a relationship between two contracts on the same chain
     * @param sourceContract The source contract address
     * @param targetContract The target contract address
     * @param relationshipType The relationship type
     */
    function registerSourceChainRelationship(
        address sourceContract,
        address targetContract,
        bytes32 relationshipType
    ) public onlyGovernor {
        if (sourceContract == address(0))
            revert InvalidSourceContract(sourceContract);
        if (targetContract == address(0))
            revert InvalidTargetContract(targetContract);
        if (relationshipType == bytes32(0))
            revert InvalidRelationshipType(relationshipType);

        // Add relationship type if not already supported
        if (!relationshipTypeSupported[relationshipType]) {
            _addRelationshipType(relationshipType);
        }

        bytes32 relationshipKey = _getRelationshipKey(
            sourceContract,
            relationshipType,
            currentChainId // Use currentChainId for target since it's same-chain
        );

        // Check if this specific relationship already exists
        if (crossChainRelations[relationshipKey].sourceContract != address(0)) {
            revert RelationshipAlreadyExists(
                sourceContract,
                relationshipType,
                currentChainId
            );
        }

        // Check if target contract is already registered for this relationship type
        bytes32 targetKey = _getTargetKey(
            currentChainId,
            currentChainId,
            targetContract,
            relationshipType
        );
        if (targetToSource[targetKey] != address(0)) {
            revert TargetContractAlreadyRegistered(
                targetContract,
                currentChainId,
                currentChainId,
                relationshipType,
                targetToSource[targetKey]
            );
        }

        // Create the relationship
        crossChainRelations[relationshipKey] = CrossChainRelation({
            sourceContract: sourceContract,
            targetContract: targetContract,
            sourceChainId: currentChainId,
            targetChainId: currentChainId,
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
        sourceToTargetChains[sourceTrackingKey].push(currentChainId);

        emit CrossChainRelationshipRegistered(
            sourceContract,
            targetContract,
            currentChainId,
            currentChainId,
            relationshipType
        );
    }

    /**
     * @notice Register an executor for the bridge router
     * @param executor The address of the executor to register
     */
    function registerExecutor(address executor) external onlyGovernor {
        registerSourceChainRelationship(executor, bridgeRouter, EXECUTOR);
    }

    /**
     * @notice Remove an executor from the bridge router
     * @param executor The address of the executor to remove
     */
    function removeExecutor(address executor) external onlyGovernor {
        unregisterCrossChainRelationship(executor, EXECUTOR, currentChainId);
    }

    /**
     * @notice Check if an address is an authorized executor
     * @param executor The address to check
     * @return True if the address is an authorized executor
     */
    function isAuthorizedExecutor(
        address executor
    ) external view returns (bool) {
        return
            isValidCrossChainPair(
                executor,
                bridgeRouter,
                currentChainId,
                currentChainId,
                EXECUTOR
            );
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

        // Allow same-chain relationships (removed the SameChainRelationship check)
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
