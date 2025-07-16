// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICrossChainConfigManaged} from "../interfaces/ICrossChainConfigManaged.sol";
import {ICrossChainRegistry} from "../interfaces/ICrossChainRegistry.sol";

/**
 * @title CrossChainConfigManaged
 * @notice Base contract for contracts that need to read from the CrossChainRegistry
 * @custom:see ICrossChainConfigManaged
 */
abstract contract CrossChainConfigManaged is ICrossChainConfigManaged {
    address private immutable CROSS_CHAIN_REGISTRY;

    /**
     * @notice Constructs the CrossChainConfigManaged contract
     * @param _crossChainRegistry The address of the CrossChainRegistry contract
     */
    constructor(address _crossChainRegistry) {
        if (_crossChainRegistry == address(0)) {
            revert CrossChainRegistryZeroAddress();
        }
        CROSS_CHAIN_REGISTRY = _crossChainRegistry;
    }

    /// @inheritdoc ICrossChainConfigManaged
    function bridgeRouter() public view virtual returns (address) {
        return ICrossChainRegistry(CROSS_CHAIN_REGISTRY).bridgeRouter();
    }

    /// @inheritdoc ICrossChainConfigManaged
    function defaultGasLimit() public view virtual returns (uint256) {
        return ICrossChainRegistry(CROSS_CHAIN_REGISTRY).defaultGasLimit();
    }

    /// @inheritdoc ICrossChainConfigManaged
    function crossChainRegistry() public view virtual returns (address) {
        return CROSS_CHAIN_REGISTRY;
    }

    /// @notice Error thrown when CrossChainRegistry address is zero
    error CrossChainRegistryZeroAddress();
}
