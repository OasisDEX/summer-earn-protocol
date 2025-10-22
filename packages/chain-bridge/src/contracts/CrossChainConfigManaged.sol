// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICrossChainConfigManaged} from "../interfaces/ICrossChainConfigManaged.sol";
import {ICrossChainRegistry} from "../interfaces/ICrossChainRegistry.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";

/**
 * @title CrossChainConfigManaged
 * @notice Base contract for contracts that need to read from the CrossChainRegistry
 * @custom:see ICrossChainConfigManaged
 */
abstract contract CrossChainConfigManaged is ICrossChainConfigManaged {
    ICrossChainRegistry public immutable CROSS_CHAIN_REGISTRY;

    /**
     * @notice Constructs the CrossChainConfigManaged contract
     * @param _crossChainRegistry The address of the CrossChainRegistry contract
     */
    constructor(address _crossChainRegistry) {
        if (_crossChainRegistry == address(0)) {
            revert CrossChainRegistryZeroAddress();
        }
        CROSS_CHAIN_REGISTRY = ICrossChainRegistry(_crossChainRegistry);
    }

    /*//////////////////////////////////////////////////////////////
                        MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Modifier ensuring the caller (`msg.sender`) is registered as an executor in the registry.
     * Reverts with `OnlyAuthorizedExecutor` if the caller is not registered.
     */
    modifier onlyAuthorizedExecutor() {
        if (!isExecutor(msg.sender)) revert OnlyAuthorizedExecutor();
        _;
    }

    /**
     * @dev Modifier ensuring the caller (`msg.sender`) is the bridge router.
     * Reverts with `OnlyBridgeRouter` if the caller is not the bridge router.
     */
    modifier onlyRouter() {
        if (msg.sender != bridgeRouter()) revert OnlyBridgeRouter();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICrossChainConfigManaged
    function bridgeRouter() public view virtual returns (address) {
        return CROSS_CHAIN_REGISTRY.bridgeRouter();
    }

    /// @inheritdoc ICrossChainConfigManaged
    function defaultGasLimit() public view virtual returns (uint256) {
        return CROSS_CHAIN_REGISTRY.defaultGasLimit();
    }

    /// @inheritdoc ICrossChainConfigManaged
    function crossChainRegistry() public view virtual returns (address) {
        return address(CROSS_CHAIN_REGISTRY);
    }

    /// @inheritdoc ICrossChainConfigManaged
    function isExecutor(address executor) public view virtual returns (bool) {
        return CROSS_CHAIN_REGISTRY.isAuthorizedExecutor(executor);
    }

    /// @notice Error thrown when CrossChainRegistry address is zero
    error CrossChainRegistryZeroAddress();
}
