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
     * @param isActive Whether the relationship is currently active
     */
    struct ArkProxyRelation {
        address proxy;
        uint16 targetChainId;
        bool isActive;
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
     * @notice Checks if a proxy is registered
     * @param proxy The address of the FleetProxy contract
     * @param chainId The chain ID where the proxy is deployed
     * @return isRegistered True if the proxy is registered
     */
    function isProxyRegistered(
        address proxy,
        uint16 chainId
    ) external view returns (bool isRegistered);
}
