// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ICrossChainConfigManaged} from "../interfaces/ICrossChainConfigManaged.sol";
import {ICrossChainConfigManager} from "../interfaces/ICrossChainConfigManager.sol";

/**
 * @title CrossChainConfigManaged
 * @notice Base contract for contracts that need to read from the CrossChainConfigManager
 * @custom:see ICrossChainConfigManaged
 */
abstract contract CrossChainConfigManaged is ICrossChainConfigManaged {
    ICrossChainConfigManager public immutable crossChainConfigManager;

    /**
     * @notice Constructs the CrossChainConfigManaged contract
     * @param _crossChainConfigManager The address of the CrossChainConfigManager contract
     */
    constructor(address _crossChainConfigManager) {
        if (_crossChainConfigManager == address(0)) {
            revert CrossChainConfigManagerZeroAddress();
        }
        crossChainConfigManager = ICrossChainConfigManager(
            _crossChainConfigManager
        );
    }

    /// @inheritdoc ICrossChainConfigManaged
    function bridgeQueue() public view virtual returns (address) {
        return crossChainConfigManager.bridgeQueue();
    }

    /// @inheritdoc ICrossChainConfigManaged
    function bridgeRouter() public view virtual returns (address) {
        return crossChainConfigManager.bridgeRouter();
    }

    /// @inheritdoc ICrossChainConfigManaged
    function crossChainRegistry() public view virtual returns (address) {
        return crossChainConfigManager.crossChainRegistry();
    }

    /// @inheritdoc ICrossChainConfigManaged
    function defaultGasLimit() public view virtual returns (uint256) {
        return crossChainConfigManager.defaultGasLimit();
    }
}
