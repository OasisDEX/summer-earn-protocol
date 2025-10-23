// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICrossChainRegistry} from "../interfaces/ICrossChainRegistry.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";

/**
 * @title CrossChainRegistry
 * @notice Generic centralized registry for managing cross-chain relationships between different contract types
 * @dev Inherits from ProtocolAccessManaged for access control and implements ICrossChainRegistry with support for
 * multiple relationship types
 */
contract CrossChainRegistry is ICrossChainRegistry, ProtocolAccessManaged {
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The chain ID of the current deployment
    uint16 private immutable CURRENT_CHAIN_ID;

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

    /// @notice The bridge router contract address
    address public bridgeRouter;

    /// @notice The gas limit for cross-chain messages
    uint256 public defaultGasLimit;

    /// @notice Constants for relationship types
    bytes32 public constant PEER_RELATIONSHIP = keccak256("PEER_RELATIONSHIP");
    bytes32 public constant ARK_FLEET_RELATIONSHIP =
        keccak256("ARK_FLEET_RELATIONSHIP");
    bytes32 public constant EXECUTOR_RELATIONSHIP =
        keccak256("EXECUTOR_RELATIONSHIP");

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

        CURRENT_CHAIN_ID = _currentChainId;

        _addRelationshipType(PEER_RELATIONSHIP);
        _addRelationshipType(ARK_FLEET_RELATIONSHIP);
        _addRelationshipType(EXECUTOR_RELATIONSHIP);

        emit RegistryInitialized(_currentChainId);
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
        // shared registration logic
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

    /// @inheritdoc ICrossChainRegistry
    function registerExecutor(address executor) external onlyGovernor {
        _registerRelationship(
            executor,
            bridgeRouter,
            CURRENT_CHAIN_ID,
            CURRENT_CHAIN_ID,
            EXECUTOR_RELATIONSHIP
        );
    }

    /// @inheritdoc ICrossChainRegistry
    function removeExecutor(address executor) external onlyGovernor {
        unregisterRelationship(
            executor,
            EXECUTOR_RELATIONSHIP,
            CURRENT_CHAIN_ID
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
        if (bridgeRouter != address(0)) {
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
     * @notice Updates the message gas limit
     * @param newDefaultGasLimit The new message gas limit
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
                        ADAPTER PEER_RELATIONSHIP CONVENIENCE
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
        registerRelationship(
            sourceAdapter,
            targetAdapter,
            sourceChainId,
            targetChainId,
            PEER_RELATIONSHIP
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
        CrossChainRelation memory relation = _getRelationshipByTarget(
            sourceAdapter,
            PEER_RELATIONSHIP,
            targetChainId
        );
        return relation.targetContract;
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
                PEER_RELATIONSHIP
            );
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICrossChainRegistry
    function currentChainId() external view returns (uint16) {
        return CURRENT_CHAIN_ID;
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
     * @notice Internal helper to load a relationship by explicit target chain
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

    /// @inheritdoc ICrossChainRegistry
    function isAuthorizedExecutor(
        address executor
    ) external view returns (bool) {
        return
            isValidCrossChainPair(
                executor,
                bridgeRouter,
                CURRENT_CHAIN_ID,
                CURRENT_CHAIN_ID,
                EXECUTOR_RELATIONSHIP
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
     * @notice Shortcut to determine if both contracts live on the deployment chain
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
     * @dev Common registration implementation used by both public entry points.
     *      Performs basic parameter validation and handles registration logic.
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

        // add relationship type if new
        if (!relationshipTypeSupported[relationshipType]) {
            _addRelationshipType(relationshipType);
        }

        bytes32 relationshipKey = _getRelationshipKey(
            sourceContract,
            relationshipType,
            targetChainId
        );

        // uniqueness check
        if (crossChainRelations[relationshipKey].sourceContract != address(0)) {
            revert RelationshipAlreadyExists(
                sourceContract,
                relationshipType,
                targetChainId
            );
        }

        bool sameChain = _isSameChain(sourceChainId, targetChainId);

        // inter-chain reverse-lookup uniqueness
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

        // store the relation
        crossChainRelations[relationshipKey] = CrossChainRelation({
            sourceContract: sourceContract,
            targetContract: targetContract,
            sourceChainId: sourceChainId,
            targetChainId: targetChainId,
            relationshipType: relationshipType
        });

        // tracking helpers
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
}
