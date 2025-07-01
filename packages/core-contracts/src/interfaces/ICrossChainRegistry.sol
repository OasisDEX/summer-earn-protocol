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
     * @notice Represents a relationship between a CrossChainArk and a FleetProxy on a target chain
     * @param fleetProxy The address of the FleetProxy contract on the target chain
     * @param targetChainId The chain ID where the fleetProxy is deployed
     * @param sourceChainId The chain ID where the crossChainArk is deployed
     * @param isActive Simple boolean status instead of complex enum
     */
    struct CrossChainArkFleetProxyRelation {
        address fleetProxy;
        uint16 targetChainId;
        uint16 sourceChainId;
        bool isActive;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a CrossChainArk-FleetProxy relationship is registered
    /// @param crossChainArk The address of the CrossChainArk contract
    /// @param sourceChainId The chain ID where the crossChainArk is deployed
    /// @param fleetProxy The address of the FleetProxy contract
    event CrossChainArkFleetProxyRegistered(
        address indexed crossChainArk,
        uint16 indexed sourceChainId,
        address indexed fleetProxy
    );

    /// @notice Emitted when a CrossChainArk-FleetProxy relationship is unregistered
    /// @param crossChainArk The address of the CrossChainArk contract
    /// @param sourceChainId The chain ID where the crossChainArk was deployed
    /// @param fleetProxy The address of the FleetProxy contract
    event CrossChainArkFleetProxyUnregistered(
        address indexed crossChainArk,
        uint16 indexed sourceChainId,
        address indexed fleetProxy
    );

    /// @notice Emitted when a relationship's status is updated
    /// @param crossChainArk The address of the CrossChainArk contract
    /// @param isActive The new active status
    event RelationshipStatusUpdated(
        address indexed crossChainArk,
        bool isActive
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when trying to register a relationship that already exists
    error RelationshipAlreadyExists(
        address crossChainArk,
        uint16 sourceChainId,
        address fleetProxy
    );

    /// @notice Thrown when trying to access a relationship that doesn't exist
    error RelationshipDoesNotExist(address crossChainArk);

    /// @notice Thrown when an invalid crossChainArk address is provided
    error InvalidCrossChainArk(address crossChainArk);

    /// @notice Thrown when an invalid fleetProxy address is provided
    error InvalidFleetProxy(address fleetProxy);

    /// @notice Thrown when an invalid chain ID is provided
    error InvalidChainId(uint16 chainId);

    /// @notice Thrown when trying to register a fleetProxy that's already registered to another crossChainArk
    error FleetProxyAlreadyRegistered(
        address fleetProxy,
        uint16 chainId,
        address existingCrossChainArk
    );

    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Register a new CrossChainArk-FleetProxy relationship
     * @param crossChainArk The address of the CrossChainArk contract
     * @param sourceChainId The chain ID where the crossChainArk is deployed
     * @param targetChainId The chain ID where the fleetProxy is deployed
     * @param fleetProxy The address of the FleetProxy contract
     */
    function registerCrossChainArkFleetProxy(
        address crossChainArk,
        uint16 sourceChainId,
        uint16 targetChainId,
        address fleetProxy
    ) external;

    /**
     * @notice Unregister an existing CrossChainArk-FleetProxy relationship
     * @param crossChainArk The address of the CrossChainArk contract
     */
    function unregisterCrossChainArkFleetProxy(address crossChainArk) external;

    /**
     * @notice Update the status of a relationship
     * @param crossChainArk The address of the CrossChainArk contract
     * @param isActive Whether the relationship should be active
     */
    function updateRelationshipStatus(
        address crossChainArk,
        bool isActive
    ) external;

    /*//////////////////////////////////////////////////////////////
                            QUERY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the fleetProxy and target chain for a given crossChainArk
     * @param crossChainArk The address of the CrossChainArk contract
     * @return fleetProxy The address of the FleetProxy contract
     * @return targetChainId The chain ID where the fleetProxy is deployed
     */
    function getFleetProxyForCrossChainArk(
        address crossChainArk
    ) external view returns (address fleetProxy, uint16 targetChainId);

    /**
     * @notice Get the crossChainArk address for a given fleetProxy on a source chain
     * @param sourceChainId The chain ID of the source chain
     * @param fleetProxy The address of the FleetProxy contract
     * @return crossChainArk The address of the CrossChainArk contract
     */
    function getCrossChainArkForFleetProxy(
        uint16 sourceChainId,
        address fleetProxy
    ) external view returns (address crossChainArk);

    /**
     * @notice Check if a crossChainArk-fleetProxy pair is valid and active
     * @param crossChainArk The address of the CrossChainArk contract
     * @param sourceChainId The chain ID where the crossChainArk is deployed
     * @param fleetProxy The address of the FleetProxy contract
     * @return isValid True if the relationship exists and is active
     */
    function isValidCrossChainArkFleetProxyPair(
        address crossChainArk,
        uint16 sourceChainId,
        address fleetProxy
    ) external view returns (bool isValid);

    /*//////////////////////////////////////////////////////////////
                        ENUMERATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get all registered crossChainArk addresses
     * @return crossChainArks Array of registered crossChainArk addresses
     */
    function getRegisteredCrossChainArks()
        external
        view
        returns (address[] memory crossChainArks);

    /**
     * @notice Check if a crossChainArk is registered
     * @param crossChainArk The address of the CrossChainArk contract
     * @return isRegistered True if the crossChainArk is registered
     */
    function isCrossChainArkRegistered(
        address crossChainArk
    ) external view returns (bool isRegistered);

    /**
     * @notice Get the total number of registered relationships
     * @return count The number of registered relationships
     */
    function getRelationshipCount() external view returns (uint256 count);
}
