// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BaseCrossChainRegistry} from "./BaseCrossChainRegistry.sol";

/**
 * @title ExecutorCrossChainRegistry
 * @notice Specialized registry for managing authorized executors
 * @dev Inherits from BaseCrossChainRegistry and provides executor-specific convenience functions
 */
abstract contract ExecutorCrossChainRegistry is BaseCrossChainRegistry {
    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the ExecutorCrossChainRegistry
     * @param _accessManager Address of the access manager
     */
    constructor(
        address _accessManager
    ) BaseCrossChainRegistry(_accessManager) {}

    /*//////////////////////////////////////////////////////////////
                        EXECUTOR_RELATIONSHIP FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Register an executor for the bridge router
     * @param executor The address of the executor to register
     */
    function registerExecutor(address executor) external onlyGovernor {
        _registerRelationship(
            executor,
            bridgeRouter,
            _currentChainId(),
            _currentChainId(),
            EXECUTOR_RELATIONSHIP
        );
    }

    /**
     * @notice Remove an executor from the bridge router
     * @param executor The address of the executor to remove
     */
    function removeExecutor(address executor) external onlyGovernor {
        _unregisterRelationship(
            executor,
            EXECUTOR_RELATIONSHIP,
            _currentChainId()
        );
    }

    /**
     * @notice Check if an address is an authorized executor
     * @param executor The address to check
     * @return True if the address is an authorized executor
     */
    function isAuthorizedExecutor(
        address executor
    ) external view returns (bool) {
        return
            _isValidCrossChainPair(
                executor,
                bridgeRouter,
                _currentChainId(),
                _currentChainId(),
                EXECUTOR_RELATIONSHIP
            );
    }

    /**
     * @notice Get all registered executors
     * @return executors Array of registered executor addresses
     */
    function getRegisteredExecutors()
        external
        view
        returns (address[] memory executors)
    {
        return _getRegisteredSourceContracts(EXECUTOR_RELATIONSHIP);
    }

    /**
     * @notice Check if an executor is registered
     * @param executor The address of the executor to check
     * @return isRegistered True if the executor is registered
     */
    function isExecutorRegistered(
        address executor
    ) external view returns (bool isRegistered) {
        return _isSourceContractRegistered(executor, EXECUTOR_RELATIONSHIP);
    }

    /**
     * @notice Get the total number of registered executors
     * @return count The number of registered executors
     */
    function getExecutorCount() external view returns (uint256 count) {
        return _getRelationshipCount(EXECUTOR_RELATIONSHIP);
    }

    /**
     * @notice Get executor relationship details
     * @param executor The address of the executor
     * @return relation The complete relationship details
     */
    function getExecutorRelationship(
        address executor
    ) external view returns (CrossChainRelation memory relation) {
        return
            _getRelationshipByTarget(
                executor,
                EXECUTOR_RELATIONSHIP,
                _currentChainId()
            );
    }

    /**
     * @notice Batch register multiple executors
     * @param executors Array of executor addresses to register
     */
    function batchRegisterExecutors(
        address[] calldata executors
    ) external onlyGovernor {
        for (uint256 i = 0; i < executors.length; i++) {
            _registerRelationship(
                executors[i],
                bridgeRouter,
                _currentChainId(),
                _currentChainId(),
                EXECUTOR_RELATIONSHIP
            );
        }
    }

    /**
     * @notice Batch remove multiple executors
     * @param executors Array of executor addresses to remove
     */
    function batchRemoveExecutors(
        address[] calldata executors
    ) external onlyGovernor {
        for (uint256 i = 0; i < executors.length; i++) {
            _unregisterRelationship(
                executors[i],
                EXECUTOR_RELATIONSHIP,
                _currentChainId()
            );
        }
    }

    /**
     * @notice Check if multiple addresses are authorized executors
     * @param executors Array of addresses to check
     * @return results Array of boolean results indicating authorization status
     */
    function batchCheckExecutors(
        address[] calldata executors
    ) external view returns (bool[] memory results) {
        results = new bool[](executors.length);
        for (uint256 i = 0; i < executors.length; i++) {
            results[i] = _isValidCrossChainPair(
                executors[i],
                bridgeRouter,
                _currentChainId(),
                _currentChainId(),
                EXECUTOR_RELATIONSHIP
            );
        }
    }
}
