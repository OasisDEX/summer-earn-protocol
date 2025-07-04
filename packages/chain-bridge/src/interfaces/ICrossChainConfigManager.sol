// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

/**
 * @title ICrossChainConfigManager
 * @notice Interface for the CrossChainConfigManager contract
 * @dev Manages cross-chain bridge configuration parameters for the protocol
 */
interface ICrossChainConfigManager {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the configuration manager is already initialized
    error CrossChainConfigManagerAlreadyInitialized();

    /// @notice Thrown when an address parameter is zero
    error AddressZero();

    /// @notice Thrown when a gas limit parameter is invalid
    error InvalidGasLimit();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the bridge queue address is updated
    event BridgeQueueUpdated(
        address indexed oldBridgeQueue,
        address indexed newBridgeQueue
    );

    /// @notice Emitted when the bridge router address is updated
    event BridgeRouterUpdated(
        address indexed oldBridgeRouter,
        address indexed newBridgeRouter
    );

    /// @notice Emitted when the cross chain registry address is updated
    event CrossChainRegistryUpdated(
        address indexed oldCrossChainRegistry,
        address indexed newCrossChainRegistry
    );

    /// @notice Emitted when the default gas limit is updated
    event DefaultGasLimitUpdated(
        uint256 oldDefaultGasLimit,
        uint256 newDefaultGasLimit
    );

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the address of the bridge queue contract
    function bridgeQueue() external view returns (address);

    /// @notice Returns the address of the bridge router contract
    function bridgeRouter() external view returns (address);

    /// @notice Returns the address of the cross chain registry contract
    function crossChainRegistry() external view returns (address);

    /// @notice Returns the default gas limit for cross-chain operations
    function defaultGasLimit() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                        CONFIGURATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the cross-chain configuration
    /// @param params The configuration parameters
    function initializeCrossChainConfiguration(
        CrossChainConfigManagerParams memory params
    ) external;

    /// @notice Sets the bridge queue address
    /// @param newBridgeQueue The new bridge queue address
    function setBridgeQueue(address newBridgeQueue) external;

    /// @notice Sets the bridge router address
    /// @param newBridgeRouter The new bridge router address
    function setBridgeRouter(address newBridgeRouter) external;

    /// @notice Sets the cross chain registry address
    /// @param newCrossChainRegistry The new cross chain registry address
    function setCrossChainRegistry(address newCrossChainRegistry) external;

    /// @notice Sets the default gas limit for cross-chain operations
    /// @param newDefaultGasLimit The new default gas limit
    function setDefaultGasLimit(uint256 newDefaultGasLimit) external;
}

/**
 * @title CrossChainConfigManagerParams
 * @notice Parameters for initializing the CrossChainConfigManager
 */
struct CrossChainConfigManagerParams {
    /// @notice Address of the bridge queue contract
    address bridgeQueue;
    /// @notice Address of the bridge router contract
    address bridgeRouter;
    /// @notice Address of the cross chain registry contract
    address crossChainRegistry;
    /// @notice Default gas limit for cross-chain operations
    uint256 defaultGasLimit;
}
