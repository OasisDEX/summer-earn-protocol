// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {ICrossChainRegistry} from "../interfaces/ICrossChainRegistry.sol";

/**
 * @title CrossChainRegistry
 * @notice Enhanced centralized registry for managing cross-chain relationships between CrossChainArk and FleetProxy contracts
 * @dev Inherits from ProtocolAccessManaged for access control and implements ICrossChainRegistry with advanced features
 */
contract CrossChainRegistry is ICrossChainRegistry, ProtocolAccessManaged {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The chain ID of the current deployment
    uint16 public immutable currentChainId;

    /// @notice Mapping from ark address to relationship information
    mapping(address => ArkProxyRelation) private arkToProxy;

    /// @notice Mapping from keccak256(abi.encode(sourceChainId, proxy)) to ark address
    mapping(bytes32 => address) private proxyToArk;

    /// @notice Mapping from ark address to relationship metadata
    mapping(address => RelationshipMetadata) private arkToMetadata;

    /// @notice Mapping from ark address to relationship history
    mapping(address => RelationshipHistoryEntry[]) private arkToHistory;

    /// @notice Array of all registered ark addresses for enumeration
    address[] private registeredArks;

    /// @notice Mapping to track if an ark is registered (for gas optimization)
    mapping(address => bool) private arkRegistered;

    /// @notice Mapping from chain ID to array of proxy addresses
    mapping(uint16 => address[]) private chainIdToProxies;

    /// @notice Mapping from chain ID and proxy to check if registered
    mapping(uint16 => mapping(address => bool)) private chainProxyRegistered;

    /// @notice Statistics tracking
    mapping(RelationshipStatus => uint256) private statusCounts;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the registry is initialized
    event RegistryInitialized(uint16 currentChainId);

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
        emit RegistryInitialized(_currentChainId);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL GOVERNANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICrossChainRegistry
    function registerArkProxy(
        address ark,
        uint16 targetChainId,
        address proxy,
        string calldata description
    ) external override onlyGovernor {
        if (ark == address(0)) revert InvalidArk(ark);
        if (proxy == address(0)) revert InvalidProxy(proxy);
        if (targetChainId == 0) revert InvalidChainId(targetChainId);

        // Check if ark already exists
        if (arkRegistered[ark]) {
            revert RelationshipAlreadyExists(ark, targetChainId, proxy);
        }

        // Check if proxy is already registered to another ark
        bytes32 proxyKey = keccak256(abi.encode(currentChainId, proxy));
        if (proxyToArk[proxyKey] != address(0)) {
            revert ProxyAlreadyRegistered(
                proxy,
                currentChainId,
                proxyToArk[proxyKey]
            );
        }

        // Validate contract existence
        require(validateContractExists(ark), "Ark contract does not exist");
        require(validateContractExists(proxy), "Proxy contract does not exist");

        // Create the relationship
        arkToProxy[ark] = ArkProxyRelation({
            proxy: proxy,
            targetChainId: targetChainId,
            status: RelationshipStatus.ACTIVE
        });

        // Set reverse mapping
        proxyToArk[proxyKey] = ark;

        // Store metadata
        arkToMetadata[ark] = RelationshipMetadata({
            description: description,
            createdAt: block.timestamp,
            creator: msg.sender,
            configHash: keccak256(
                abi.encode(ark, targetChainId, proxy, description)
            )
        });

        // Update tracking
        registeredArks.push(ark);
        arkRegistered[ark] = true;
        chainIdToProxies[currentChainId].push(proxy);
        chainProxyRegistered[currentChainId][proxy] = true;
        statusCounts[RelationshipStatus.ACTIVE]++;

        emit ArkProxyRegistered(ark, targetChainId, proxy, msg.sender);

        // Record history
        _recordHistory(
            ark,
            RelationshipAction.CREATED,
            abi.encode(targetChainId, proxy, description)
        );
    }

    /// @inheritdoc ICrossChainRegistry
    function unregisterArkProxy(address ark) external override onlyGovernor {
        _unregisterArkProxy(ark);
    }

    /// @inheritdoc ICrossChainRegistry
    function updateRelationshipStatus(
        address ark,
        bool isActive
    ) external override onlyGovernor {
        if (!arkRegistered[ark]) {
            revert RelationshipDoesNotExist(ark);
        }

        RelationshipStatus newStatus = isActive
            ? RelationshipStatus.ACTIVE
            : RelationshipStatus.INACTIVE;
        _updateStatus(ark, newStatus);
    }

    /// @inheritdoc ICrossChainRegistry
    function setRelationshipStatus(
        address ark,
        RelationshipStatus status
    ) external override onlyGovernor {
        if (!arkRegistered[ark]) {
            revert RelationshipDoesNotExist(ark);
        }
        _updateStatus(ark, status);
    }

    /// @inheritdoc ICrossChainRegistry
    function batchRegisterArkProxy(
        BatchRegistrationParams[] calldata params
    ) external override onlyGovernor {
        uint256 count = params.length;
        require(count > 0, "Empty batch");

        for (uint256 i = 0; i < count; i++) {
            BatchRegistrationParams calldata param = params[i];

            // Use internal function to avoid duplicate access control checks
            _registerArkProxy(
                param.ark,
                param.targetChainId,
                param.proxy,
                param.description
            );
        }

        emit BatchRegistrationCompleted(count, msg.sender);
    }

    /// @inheritdoc ICrossChainRegistry
    function batchUnregisterArkProxy(
        address[] calldata arks
    ) external override onlyGovernor {
        uint256 count = arks.length;
        require(count > 0, "Empty batch");

        for (uint256 i = 0; i < count; i++) {
            // Use internal function to avoid access control issues
            _unregisterArkProxy(arks[i]);
        }
    }

    /// @inheritdoc ICrossChainRegistry
    function updateRelationshipMetadata(
        address ark,
        string calldata description,
        bytes32 configHash
    ) external override onlyGovernor {
        if (!arkRegistered[ark]) {
            revert RelationshipDoesNotExist(ark);
        }

        RelationshipMetadata storage metadata = arkToMetadata[ark];
        metadata.description = description;
        metadata.configHash = configHash;

        emit RelationshipMetadataUpdated(ark, description, configHash);

        _recordHistory(
            ark,
            RelationshipAction.METADATA_UPDATED,
            abi.encode(description, configHash)
        );
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICrossChainRegistry
    function getProxyForArk(
        address ark
    ) external view override returns (address proxy, uint16 targetChainId) {
        if (!arkRegistered[ark]) {
            revert RelationshipDoesNotExist(ark);
        }

        ArkProxyRelation memory relation = arkToProxy[ark];
        return (relation.proxy, relation.targetChainId);
    }

    /// @inheritdoc ICrossChainRegistry
    function getArkForProxy(
        uint16 sourceChainId,
        address proxy
    ) external view override returns (address ark) {
        bytes32 key = keccak256(abi.encode(sourceChainId, proxy));
        ark = proxyToArk[key];

        if (ark == address(0)) {
            revert RelationshipDoesNotExist(address(0));
        }
    }

    /// @inheritdoc ICrossChainRegistry
    function isValidArkProxyPair(
        address ark,
        uint16 targetChainId,
        address proxy
    ) external view override returns (bool isValid) {
        if (!arkRegistered[ark]) return false;

        ArkProxyRelation memory relation = arkToProxy[ark];
        return
            relation.proxy == proxy &&
            relation.targetChainId == targetChainId &&
            relation.status == RelationshipStatus.ACTIVE;
    }

    /// @inheritdoc ICrossChainRegistry
    function getRelation(
        address ark
    ) external view override returns (ArkProxyRelation memory relation) {
        if (!arkRegistered[ark]) {
            revert RelationshipDoesNotExist(ark);
        }
        return arkToProxy[ark];
    }

    /// @inheritdoc ICrossChainRegistry
    function getRelationshipMetadata(
        address ark
    ) external view override returns (RelationshipMetadata memory metadata) {
        if (!arkRegistered[ark]) {
            revert RelationshipDoesNotExist(ark);
        }
        return arkToMetadata[ark];
    }

    /// @inheritdoc ICrossChainRegistry
    function getRegisteredArks()
        external
        view
        override
        returns (address[] memory arks)
    {
        return registeredArks;
    }

    /// @inheritdoc ICrossChainRegistry
    function getRegisteredProxies(
        uint16 chainId
    ) external view override returns (address[] memory proxies) {
        return chainIdToProxies[chainId];
    }

    /// @inheritdoc ICrossChainRegistry
    function getRelationshipCount()
        external
        view
        override
        returns (uint256 count)
    {
        return registeredArks.length;
    }

    /// @inheritdoc ICrossChainRegistry
    function isArkRegistered(
        address ark
    ) external view override returns (bool isRegistered) {
        return arkRegistered[ark];
    }

    /// @inheritdoc ICrossChainRegistry
    function isProxyRegistered(
        address proxy,
        uint16 chainId
    ) external view override returns (bool isRegistered) {
        return chainProxyRegistered[chainId][proxy];
    }

    /*//////////////////////////////////////////////////////////////
                        ENHANCED VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICrossChainRegistry
    function getRelationshipStatus(
        address ark
    ) external view override returns (RelationshipStatus status) {
        if (!arkRegistered[ark]) {
            revert RelationshipDoesNotExist(ark);
        }
        return arkToProxy[ark].status;
    }

    /// @inheritdoc ICrossChainRegistry
    function getRelationshipHistory(
        address ark
    )
        external
        view
        override
        returns (RelationshipHistoryEntry[] memory history)
    {
        return arkToHistory[ark];
    }

    /// @inheritdoc ICrossChainRegistry
    function getLatestHistoryEntry(
        address ark
    ) external view override returns (RelationshipHistoryEntry memory entry) {
        RelationshipHistoryEntry[] memory history = arkToHistory[ark];
        require(history.length > 0, "No history entries");
        return history[history.length - 1];
    }

    /// @inheritdoc ICrossChainRegistry
    function getRelationshipsByStatus(
        RelationshipStatus status
    ) external view override returns (address[] memory arks) {
        uint256 count = statusCounts[status];
        address[] memory result = new address[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < registeredArks.length; i++) {
            if (arkToProxy[registeredArks[i]].status == status) {
                result[index] = registeredArks[i];
                index++;
            }
        }

        return result;
    }

    /// @inheritdoc ICrossChainRegistry
    function getRelationshipStatistics()
        external
        view
        override
        returns (
            uint256 totalRelationships,
            uint256 activeRelationships,
            uint256 pausedRelationships,
            uint256 deprecatedRelationships
        )
    {
        return (
            registeredArks.length,
            statusCounts[RelationshipStatus.ACTIVE],
            statusCounts[RelationshipStatus.PAUSED],
            statusCounts[RelationshipStatus.DEPRECATED]
        );
    }

    /// @inheritdoc ICrossChainRegistry
    function getChainStatistics(
        uint16 chainId
    )
        external
        view
        override
        returns (uint256 totalProxies, uint256 activeProxies)
    {
        address[] memory proxies = chainIdToProxies[chainId];
        totalProxies = proxies.length;

        for (uint256 i = 0; i < proxies.length; i++) {
            bytes32 key = keccak256(abi.encode(chainId, proxies[i]));
            address ark = proxyToArk[key];
            if (
                ark != address(0) &&
                arkToProxy[ark].status == RelationshipStatus.ACTIVE
            ) {
                activeProxies++;
            }
        }
    }

    /// @inheritdoc ICrossChainRegistry
    function relationshipExists(
        address ark
    ) external view override returns (bool exists) {
        return arkRegistered[ark];
    }

    /// @inheritdoc ICrossChainRegistry
    function validateContractExists(
        address contractAddress
    ) public view override returns (bool isContract) {
        return contractAddress.code.length > 0;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to register an ark-proxy relationship
     * @param ark The address of the CrossChainArk contract
     * @param targetChainId The chain ID where the proxy is deployed
     * @param proxy The address of the FleetProxy contract
     * @param description Optional description for the relationship
     */
    function _registerArkProxy(
        address ark,
        uint16 targetChainId,
        address proxy,
        string calldata description
    ) internal {
        if (ark == address(0)) revert InvalidArk(ark);
        if (proxy == address(0)) revert InvalidProxy(proxy);
        if (targetChainId == 0) revert InvalidChainId(targetChainId);

        // Check if ark already exists
        if (arkRegistered[ark]) {
            revert RelationshipAlreadyExists(ark, targetChainId, proxy);
        }

        // Check if proxy is already registered to another ark
        bytes32 proxyKey = keccak256(abi.encode(currentChainId, proxy));
        if (proxyToArk[proxyKey] != address(0)) {
            revert ProxyAlreadyRegistered(
                proxy,
                currentChainId,
                proxyToArk[proxyKey]
            );
        }

        // Create the relationship
        arkToProxy[ark] = ArkProxyRelation({
            proxy: proxy,
            targetChainId: targetChainId,
            status: RelationshipStatus.ACTIVE
        });

        // Set reverse mapping
        proxyToArk[proxyKey] = ark;

        // Store metadata
        arkToMetadata[ark] = RelationshipMetadata({
            description: description,
            createdAt: block.timestamp,
            creator: msg.sender,
            configHash: keccak256(
                abi.encode(ark, targetChainId, proxy, description)
            )
        });

        // Update tracking
        registeredArks.push(ark);
        arkRegistered[ark] = true;
        chainIdToProxies[currentChainId].push(proxy);
        chainProxyRegistered[currentChainId][proxy] = true;
        statusCounts[RelationshipStatus.ACTIVE]++;

        emit ArkProxyRegistered(ark, targetChainId, proxy, msg.sender);

        // Record history
        _recordHistory(
            ark,
            RelationshipAction.CREATED,
            abi.encode(targetChainId, proxy, description)
        );
    }

    /**
     * @notice Internal function to unregister an ark-proxy relationship
     * @param ark The address of the CrossChainArk contract
     */
    function _unregisterArkProxy(address ark) internal {
        if (!arkRegistered[ark]) {
            revert RelationshipDoesNotExist(ark);
        }

        ArkProxyRelation memory relation = arkToProxy[ark];

        // Update status counts
        statusCounts[relation.status]--;

        // Remove reverse mapping
        bytes32 proxyKey = keccak256(
            abi.encode(currentChainId, relation.proxy)
        );
        delete proxyToArk[proxyKey];

        // Remove from arrays (expensive operation, but needed for complete cleanup)
        _removeFromArray(registeredArks, ark);
        _removeFromArray(chainIdToProxies[currentChainId], relation.proxy);

        // Clear mappings
        delete arkToProxy[ark];
        delete arkToMetadata[ark];
        arkRegistered[ark] = false;
        chainProxyRegistered[currentChainId][relation.proxy] = false;

        emit ArkProxyUnregistered(ark, relation.targetChainId, relation.proxy);

        // Record history before deletion
        _recordHistory(
            ark,
            RelationshipAction.DELETED,
            abi.encode(relation.targetChainId, relation.proxy)
        );
    }

    /**
     * @notice Internal function to update relationship status
     * @param ark The address of the CrossChainArk contract
     * @param newStatus The new status to set
     */
    function _updateStatus(address ark, RelationshipStatus newStatus) internal {
        ArkProxyRelation storage relation = arkToProxy[ark];
        RelationshipStatus oldStatus = relation.status;

        if (oldStatus == newStatus) return; // No change needed

        // Update status counts
        statusCounts[oldStatus]--;
        statusCounts[newStatus]++;

        // Update the status
        relation.status = newStatus;

        // Record history based on action
        RelationshipAction action;
        if (newStatus == RelationshipStatus.ACTIVE)
            action = RelationshipAction.ACTIVATED;
        else if (newStatus == RelationshipStatus.INACTIVE)
            action = RelationshipAction.DEACTIVATED;
        else if (newStatus == RelationshipStatus.PAUSED)
            action = RelationshipAction.PAUSED;
        else if (newStatus == RelationshipStatus.DEPRECATED)
            action = RelationshipAction.DEPRECATED;

        emit RelationshipStatusChanged(
            ark,
            relation.targetChainId,
            relation.proxy,
            oldStatus,
            newStatus
        );

        // Maintain backward compatibility
        bool isActive = newStatus == RelationshipStatus.ACTIVE;
        emit RelationshipStatusUpdated(
            ark,
            relation.targetChainId,
            relation.proxy,
            isActive
        );

        _recordHistory(ark, action, abi.encode(oldStatus, newStatus));
    }

    /**
     * @notice Records a historical entry for a relationship
     * @param ark The address of the CrossChainArk contract
     * @param action The action being performed
     * @param data Additional data about the action
     */
    function _recordHistory(
        address ark,
        RelationshipAction action,
        bytes memory data
    ) internal {
        arkToHistory[ark].push(
            RelationshipHistoryEntry({
                action: action,
                timestamp: block.timestamp,
                actor: msg.sender,
                data: data
            })
        );

        emit RelationshipActionRecorded(ark, action, msg.sender);
    }

    /**
     * @notice Removes an element from an address array
     * @param array The array to modify
     * @param element The element to remove
     */
    function _removeFromArray(
        address[] storage array,
        address element
    ) internal {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == element) {
                array[i] = array[array.length - 1];
                array.pop();
                break;
            }
        }
    }
}
