// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AdapterCrossChainRegistry} from "./AdapterCrossChainRegistry.sol";
import {ExecutorCrossChainRegistry} from "./ExecutorCrossChainRegistry.sol";
import {BaseCrossChainRegistry} from "./BaseCrossChainRegistry.sol";

/**
 * @title CrossChainRegistry
 * @notice Main registry contract that combines adapter and executor functionality
 * @dev Inherits from both AdapterCrossChainRegistry and ExecutorCrossChainRegistry
 * to provide a complete cross-chain relationship management system
 */
contract CrossChainRegistry is
    BaseCrossChainRegistry,
    AdapterCrossChainRegistry,
    ExecutorCrossChainRegistry
{
    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the CrossChainRegistry
     * @param _accessManager Address of the access manager
     */
    constructor(
        address _accessManager
    )
        BaseCrossChainRegistry(_accessManager)
        AdapterCrossChainRegistry(_accessManager)
        ExecutorCrossChainRegistry(_accessManager)
    {
        // All constructors are called to initialize relationship types
    }
}
