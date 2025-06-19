// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title ICrossChainRegistry
 * @notice Simplified interface for managing cross-chain relationships between CrossChainArk and FleetProxy contracts
 * @dev Provides centralized management of cross-chain relationships with focus on core functionality
 */
interface ICrossChainRegistry {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Represents a relationship between an Ark and a Proxy on a target chain
     * @param proxy The address of the FleetProxy contract on the target chain
     * @param targetChainId The chain ID where the proxy is deployed
     * @param sourceChainId The chain ID where the ark is deployed
     * @param isActive Simple boolean status instead of complex enum
     */
    struct ArkProxyRelation {
        address proxy;
        uint16 targetChainId;
        uint16 sourceChainId;
        bool isActive;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when an Ark-Proxy relationship is registered
    /// @param ark The address of the CrossChainArk contract
    /// @param sourceChainId The chain ID where the ark is deployed
    /// @param proxy The address of the FleetProxy contract
    event ArkProxyRegistered(
        address indexed ark,
        uint16 indexed sourceChainId,
        address indexed proxy
    );

    /// @notice Emitted when an Ark-Proxy relationship is unregistered
    /// @param ark The address of the CrossChainArk contract
    /// @param sourceChainId The chain ID where the ark was deployed
    /// @param proxy The address of the FleetProxy contract
    event ArkProxyUnregistered(
        address indexed ark,
        uint16 indexed sourceChainId,
        address indexed proxy
    );

    /// @notice Emitted when a relationship's status is updated
    /// @param ark The address of the CrossChainArk contract
    /// @param isActive The new active status
    event RelationshipStatusUpdated(address indexed ark, bool isActive);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when trying to register a relationship that already exists
    error RelationshipAlreadyExists(
        address ark,
        uint16 sourceChainId,
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
     * @notice Register a new Ark-Proxy relationship
     * @param ark The address of the CrossChainArk contract
     * @param sourceChainId The chain ID where the ark is deployed
     * @param targetChainId The chain ID where the proxy is deployed
     * @param proxy The address of the FleetProxy contract
     */
    function registerArkProxy(
        address ark,
        uint16 sourceChainId,
        uint16 targetChainId,
        address proxy
    ) external;

    /**
     * @notice Unregister an existing Ark-Proxy relationship
     * @param ark The address of the CrossChainArk contract
     */
    function unregisterArkProxy(address ark) external;

    /**
     * @notice Update the status of a relationship
     * @param ark The address of the CrossChainArk contract
     * @param isActive Whether the relationship should be active
     */
    function updateRelationshipStatus(address ark, bool isActive) external;

    /*//////////////////////////////////////////////////////////////
                            QUERY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the proxy and target chain for a given ark
     * @param ark The address of the CrossChainArk contract
     * @return proxy The address of the FleetProxy contract
     * @return targetChainId The chain ID where the proxy is deployed
     */
    function getProxyForArk(
        address ark
    ) external view returns (address proxy, uint16 targetChainId);

    /**
     * @notice Get the ark address for a given proxy on a source chain
     * @param sourceChainId The chain ID of the source chain
     * @param proxy The address of the FleetProxy contract
     * @return ark The address of the CrossChainArk contract
     */
    function getArkForProxy(
        uint16 sourceChainId,
        address proxy
    ) external view returns (address ark);

    /**
     * @notice Check if an ark-proxy pair is valid and active
     * @param ark The address of the CrossChainArk contract
     * @param sourceChainId The chain ID where the ark is deployed
     * @param proxy The address of the FleetProxy contract
     * @return isValid True if the relationship exists and is active
     */
    function isValidArkProxyPair(
        address ark,
        uint16 sourceChainId,
        address proxy
    ) external view returns (bool isValid);

    /*//////////////////////////////////////////////////////////////
                        ENUMERATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get all registered ark addresses
     * @return arks Array of registered ark addresses
     */
    function getRegisteredArks() external view returns (address[] memory arks);

    /**
     * @notice Check if an ark is registered
     * @param ark The address of the CrossChainArk contract
     * @return isRegistered True if the ark is registered
     */
    function isArkRegistered(
        address ark
    ) external view returns (bool isRegistered);

    /**
     * @notice Get the total number of registered relationships
     * @return count The number of registered relationships
     */
    function getRelationshipCount() external view returns (uint256 count);
}
