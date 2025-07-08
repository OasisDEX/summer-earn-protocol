// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ICrossChainConfigManaged} from "../interfaces/ICrossChainConfigManaged.sol";
import {ICrossChainRegistry} from "../interfaces/ICrossChainRegistry.sol";

/**
 * @title CrossChainConfigManaged
 * @notice Base contract for contracts that need to read from the CrossChainRegistry
 * @custom:see ICrossChainConfigManaged
 */
abstract contract CrossChainConfigManaged is ICrossChainConfigManaged {
    address public immutable crossChainRegistry;

    /**
     * @notice Constructs the CrossChainConfigManaged contract
     * @param _crossChainRegistry The address of the CrossChainRegistry contract
     */
    constructor(address _crossChainRegistry) {
        if (_crossChainRegistry == address(0)) {
            revert CrossChainRegistryZeroAddress();
        }
        crossChainRegistry = _crossChainRegistry;
    }

    /// @inheritdoc ICrossChainConfigManaged
    function bridgeQueue() public view virtual returns (address) {
        return ICrossChainRegistry(crossChainRegistry).bridgeQueue();
    }

    /// @inheritdoc ICrossChainConfigManaged
    function bridgeRouter() public view virtual returns (address) {
        return ICrossChainRegistry(crossChainRegistry).bridgeRouter();
    }

    /// @inheritdoc ICrossChainConfigManaged
    function defaultGasLimit() public view virtual returns (uint256) {
        return ICrossChainRegistry(crossChainRegistry).defaultGasLimit();
    }

    /// @notice Error thrown when CrossChainRegistry address is zero
    error CrossChainRegistryZeroAddress();
}
