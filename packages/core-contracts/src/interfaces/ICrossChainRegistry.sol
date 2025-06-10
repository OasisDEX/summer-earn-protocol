// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title ICrossChainRegistry
 * @notice Interface for managing cross-chain relationships between CrossChainArk and FleetProxy contracts
 * @dev Provides centralized management of cross-chain relationships with enhanced security and observability
 */
interface ICrossChainRegistry {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Represents a relationship between an Ark and a Proxy on a target chain
     * @param proxy The address of the FleetProxy contract on the target chain
     * @param targetChainId The chain ID where the proxy is deployed
     * @param status The current status of the relationship
     */
    struct ArkProxyRelation {
        address proxy;
        uint16 targetChainId;
        RelationshipStatus status;
    }

    /**
     * @notice Metadata for a cross-chain relationship
     * @param description Human-readable description of the relationship
     * @param createdAt Timestamp when the relationship was created
     * @param creator Address that created the relationship
     * @param configHash Hash of the configuration used for the relationship
     */
    struct RelationshipMetadata {
        string description;
        uint256 createdAt;
        address creator;
        bytes32 configHash;
    }

    /**
     * @notice Historical record of relationship changes
     * @param action The type of action performed
     * @param timestamp When the action occurred
     * @param actor Who performed the action
     * @param data Additional data about the action
     */
    struct RelationshipHistoryEntry {
        RelationshipAction action;
        uint256 timestamp;
        address actor;
        bytes data;
    }

    /**
     * @notice Enhanced relationship status
     */
    enum RelationshipStatus {
        INACTIVE,
        ACTIVE,
        PAUSED,
        DEPRECATED
    }

    /**
     * @notice Types of actions that can be performed on relationships
     */
    enum RelationshipAction {
        CREATED,
        ACTIVATED,
        DEACTIVATED,
        PAUSED,
        RESUMED,
        DEPRECATED,
        DELETED,
        METADATA_UPDATED
    }

    /**
     * @notice Parameters for batch registration
     * @param ark The address of the CrossChainArk contract
     * @param targetChainId The chain ID where the proxy is deployed
     * @param proxy The address of the FleetProxy contract
     * @param description Optional description for the relationship
     */
    struct BatchRegistrationParams {
        address ark;
        uint16 targetChainId;
        address proxy;
        string description;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when an Ark-Proxy relationship is registered
    /// @param ark The address of the CrossChainArk contract
    /// @param targetChainId The chain ID where the proxy is deployed
    /// @param proxy The address of the FleetProxy contract
    /// @param creator The address that created the relationship
    event ArkProxyRegistered(
        address indexed ark,
        uint16 indexed targetChainId,
        address indexed proxy,
        address creator
    );

    /// @notice Emitted when an Ark-Proxy relationship is unregistered
    /// @param ark The address of the CrossChainArk contract
    /// @param targetChainId The chain ID where the proxy was deployed
    /// @param proxy The address of the FleetProxy contract
    event ArkProxyUnregistered(
        address indexed ark,
        uint16 indexed targetChainId,
        address indexed proxy
    );

    /// @notice Emitted when a relationship's active status is updated
    /// @param ark The address of the CrossChainArk contract
    /// @param targetChainId The chain ID where the proxy is deployed
    /// @param proxy The address of the FleetProxy contract
    /// @param isActive The new active status
    event RelationshipStatusUpdated(
        address indexed ark,
        uint16 indexed targetChainId,
        address indexed proxy,
        bool isActive
    );

    /// @notice Emitted when a relationship's status is updated to a specific state
    /// @param ark The address of the CrossChainArk contract
    /// @param targetChainId The chain ID where the proxy is deployed
    /// @param proxy The address of the FleetProxy contract
    /// @param oldStatus The previous status
    /// @param newStatus The new status
    event RelationshipStatusChanged(
        address indexed ark,
        uint16 indexed targetChainId,
        address indexed proxy,
        RelationshipStatus oldStatus,
        RelationshipStatus newStatus
    );

    /// @notice Emitted when relationship metadata is updated
    /// @param ark The address of the CrossChainArk contract
    /// @param description The new description
    /// @param configHash The new configuration hash
    event RelationshipMetadataUpdated(
        address indexed ark,
        string description,
        bytes32 configHash
    );

    /// @notice Emitted when multiple relationships are registered in batch
    /// @param count The number of relationships registered
    /// @param actor The address that performed the batch operation
    event BatchRegistrationCompleted(uint256 count, address indexed actor);

    /// @notice Emitted when a historical action is recorded
    /// @param ark The address of the CrossChainArk contract
    /// @param action The type of action performed
    /// @param actor Who performed the action
    event RelationshipActionRecorded(
        address indexed ark,
        RelationshipAction indexed action,
        address indexed actor
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when trying to register a relationship that already exists
    error RelationshipAlreadyExists(
        address ark,
        uint16 targetChainId,
        address proxy
    );

    /// @notice Thrown when trying to access a relationship that doesn't exist
    error RelationshipDoesNotExist(address ark);

    /// @notice Thrown when an invalid ark address is provided
    error InvalidArk(address ark);

    /// @notice Thrown when an invalid proxy address is provided
    error InvalidProxy(address proxy);

    /// @notice Thrown when an invalid chain ID is provided
    error InvalidChainId(uint16 chainId);

    /// @notice Thrown when trying to register a proxy that's already registered to another ark
    error ProxyAlreadyRegistered(
        address proxy,
        uint16 chainId,
        address existingArk
    );

    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Registers a relationship between a CrossChainArk and FleetProxy
     * @param ark The address of the CrossChainArk contract
     * @param targetChainId The chain ID where the proxy is deployed
     * @param proxy The address of the FleetProxy contract
     * @param description Optional description for the relationship
     * @dev Only callable by governance
     */
    function registerArkProxy(
        address ark,
        uint16 targetChainId,
        address proxy,
        string calldata description
    ) external;

    /**
     * @notice Unregisters a relationship for a given ark
     * @param ark The address of the CrossChainArk contract
     * @dev Only callable by governance
     */
    function unregisterArkProxy(address ark) external;

    /**
     * @notice Updates the active status of a relationship
     * @param ark The address of the CrossChainArk contract
     * @param isActive The new active status
     * @dev Only callable by governance
     */
    function updateRelationshipStatus(address ark, bool isActive) external;

    /**
     * @notice Updates the status of a relationship to a specific state
     * @param ark The address of the CrossChainArk contract
     * @param status The new relationship status
     * @dev Only callable by governance
     */
    function setRelationshipStatus(
        address ark,
        RelationshipStatus status
    ) external;

    /**
     * @notice Batch registers multiple ark-proxy relationships
     * @param params Array of registration parameters
     * @dev Only callable by governance. More gas efficient for multiple registrations
     */
    function batchRegisterArkProxy(
        BatchRegistrationParams[] calldata params
    ) external;

    /**
     * @notice Batch unregisters multiple ark-proxy relationships
     * @param arks Array of ark addresses to unregister
     * @dev Only callable by governance
     */
    function batchUnregisterArkProxy(address[] calldata arks) external;

    /**
     * @notice Updates the metadata for an existing relationship
     * @param ark The address of the CrossChainArk contract
     * @param description New description for the relationship
     * @param configHash New configuration hash
     * @dev Only callable by governance
     */
    function updateRelationshipMetadata(
        address ark,
        string calldata description,
        bytes32 configHash
    ) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the proxy and target chain for a given ark
     * @param ark The address of the CrossChainArk contract
     * @return proxy The address of the FleetProxy contract
     * @return targetChainId The chain ID where the proxy is deployed
     */
    function getProxyForArk(
        address ark
    ) external view returns (address proxy, uint16 targetChainId);

    /**
     * @notice Gets the ark for a given proxy and source chain
     * @param sourceChainId The chain ID where the ark is deployed
     * @param proxy The address of the FleetProxy contract
     * @return ark The address of the CrossChainArk contract
     */
    function getArkForProxy(
        uint16 sourceChainId,
        address proxy
    ) external view returns (address ark);

    /**
     * @notice Checks if an ark-proxy pair is valid and active
     * @param ark The address of the CrossChainArk contract
     * @param targetChainId The chain ID where the proxy is deployed
     * @param proxy The address of the FleetProxy contract
     * @return isValid True if the relationship exists and is active
     */
    function isValidArkProxyPair(
        address ark,
        uint16 targetChainId,
        address proxy
    ) external view returns (bool isValid);

    /**
     * @notice Gets the complete relationship information for an ark
     * @param ark The address of the CrossChainArk contract
     * @return relation The ArkProxyRelation struct
     */
    function getRelation(
        address ark
    ) external view returns (ArkProxyRelation memory relation);

    /**
     * @notice Gets the metadata for a relationship
     * @param ark The address of the CrossChainArk contract
     * @return metadata The RelationshipMetadata struct
     */
    function getRelationshipMetadata(
        address ark
    ) external view returns (RelationshipMetadata memory metadata);

    /**
     * @notice Gets all registered ark addresses
     * @return arks Array of all registered ark addresses
     */
    function getRegisteredArks() external view returns (address[] memory arks);

    /**
     * @notice Gets all registered proxy addresses for a given chain
     * @param chainId The chain ID to query
     * @return proxies Array of proxy addresses on the specified chain
     */
    function getRegisteredProxies(
        uint16 chainId
    ) external view returns (address[] memory proxies);

    /**
     * @notice Gets the total number of relationships
     * @return count The total number of registered relationships
     */
    function getRelationshipCount() external view returns (uint256 count);

    /**
     * @notice Checks if an ark is registered
     * @param ark The address of the CrossChainArk contract
     * @return isRegistered True if the ark is registered
     */
    function isArkRegistered(
        address ark
    ) external view returns (bool isRegistered);

    /**
     * @notice Checks if a proxy is registered on a specific chain
     * @param proxy The address of the FleetProxy contract
     * @param chainId The chain ID to check
     * @return isRegistered True if the proxy is registered on the specified chain
     */
    function isProxyRegistered(
        address proxy,
        uint16 chainId
    ) external view returns (bool isRegistered);

    /*//////////////////////////////////////////////////////////////
                        ENHANCED VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the current status of a relationship
     * @param ark The address of the CrossChainArk contract
     * @return status The current relationship status
     */
    function getRelationshipStatus(
        address ark
    ) external view returns (RelationshipStatus status);

    /**
     * @notice Gets the relationship history for an ark
     * @param ark The address of the CrossChainArk contract
     * @return history Array of historical entries
     */
    function getRelationshipHistory(
        address ark
    ) external view returns (RelationshipHistoryEntry[] memory history);

    /**
     * @notice Gets the latest history entry for an ark
     * @param ark The address of the CrossChainArk contract
     * @return entry The most recent historical entry
     */
    function getLatestHistoryEntry(
        address ark
    ) external view returns (RelationshipHistoryEntry memory entry);

    /**
     * @notice Gets relationships by status
     * @param status The status to filter by
     * @return arks Array of ark addresses with the specified status
     */
    function getRelationshipsByStatus(
        RelationshipStatus status
    ) external view returns (address[] memory arks);

    /**
     * @notice Gets relationship statistics
     * @return totalRelationships Total number of relationships
     * @return activeRelationships Number of active relationships
     * @return pausedRelationships Number of paused relationships
     * @return deprecatedRelationships Number of deprecated relationships
     */
    function getRelationshipStatistics()
        external
        view
        returns (
            uint256 totalRelationships,
            uint256 activeRelationships,
            uint256 pausedRelationships,
            uint256 deprecatedRelationships
        );

    /**
     * @notice Gets chain-specific statistics
     * @param chainId The chain ID to get statistics for
     * @return totalProxies Total number of proxies on the chain
     * @return activeProxies Number of active proxies on the chain
     */
    function getChainStatistics(
        uint16 chainId
    ) external view returns (uint256 totalProxies, uint256 activeProxies);

    /**
     * @notice Checks if a relationship exists
     * @param ark The address of the CrossChainArk contract
     * @return exists True if the relationship exists
     */
    function relationshipExists(
        address ark
    ) external view returns (bool exists);

    /**
     * @notice Validates if a contract address exists
     * @param contractAddress The address to validate
     * @return isContract True if the address is a contract
     */
    function validateContractExists(
        address contractAddress
    ) external view returns (bool isContract);
}
