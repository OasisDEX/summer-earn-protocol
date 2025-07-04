// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ICrossChainConfigManager, CrossChainConfigManagerParams} from "../interfaces/ICrossChainConfigManager.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";

/**
 * @title CrossChainConfigManager
 * @notice Manages cross-chain bridge configuration parameters for the protocol
 * @custom:see ICrossChainConfigManager
 */
contract CrossChainConfigManager is
    ICrossChainConfigManager,
    ProtocolAccessManaged
{
    bool public initialized;

    /// @inheritdoc ICrossChainConfigManager
    address public bridgeQueue;

    /// @inheritdoc ICrossChainConfigManager
    address public bridgeRouter;

    /// @inheritdoc ICrossChainConfigManager
    address public crossChainRegistry;

    /// @inheritdoc ICrossChainConfigManager
    uint256 public defaultGasLimit;

    /**
     * @notice Constructs the CrossChainConfigManager contract
     * @param _accessManager The address of the ProtocolAccessManager contract
     */
    constructor(address _accessManager) ProtocolAccessManaged(_accessManager) {}

    /// @inheritdoc ICrossChainConfigManager
    function initializeCrossChainConfiguration(
        CrossChainConfigManagerParams memory params
    ) external onlyGovernor {
        if (initialized) {
            revert CrossChainConfigManagerAlreadyInitialized();
        }

        if (
            params.bridgeQueue == address(0) ||
            params.bridgeRouter == address(0) ||
            params.crossChainRegistry == address(0)
        ) {
            revert AddressZero();
        }

        if (params.defaultGasLimit == 0) {
            revert InvalidGasLimit();
        }

        bridgeQueue = params.bridgeQueue;
        bridgeRouter = params.bridgeRouter;
        crossChainRegistry = params.crossChainRegistry;
        defaultGasLimit = params.defaultGasLimit;

        emit BridgeQueueUpdated(address(0), params.bridgeQueue);
        emit BridgeRouterUpdated(address(0), params.bridgeRouter);
        emit CrossChainRegistryUpdated(address(0), params.crossChainRegistry);
        emit DefaultGasLimitUpdated(0, params.defaultGasLimit);

        initialized = true;
    }

    /// @inheritdoc ICrossChainConfigManager
    function setBridgeQueue(address newBridgeQueue) external onlyGovernor {
        if (newBridgeQueue == address(0)) {
            revert AddressZero();
        }
        emit BridgeQueueUpdated(bridgeQueue, newBridgeQueue);
        bridgeQueue = newBridgeQueue;
    }

    /// @inheritdoc ICrossChainConfigManager
    function setBridgeRouter(address newBridgeRouter) external onlyGovernor {
        if (newBridgeRouter == address(0)) {
            revert AddressZero();
        }
        emit BridgeRouterUpdated(bridgeRouter, newBridgeRouter);
        bridgeRouter = newBridgeRouter;
    }

    /// @inheritdoc ICrossChainConfigManager
    function setCrossChainRegistry(
        address newCrossChainRegistry
    ) external onlyGovernor {
        if (newCrossChainRegistry == address(0)) {
            revert AddressZero();
        }
        emit CrossChainRegistryUpdated(
            crossChainRegistry,
            newCrossChainRegistry
        );
        crossChainRegistry = newCrossChainRegistry;
    }

    /// @inheritdoc ICrossChainConfigManager
    function setDefaultGasLimit(
        uint256 newDefaultGasLimit
    ) external onlyGovernor {
        if (newDefaultGasLimit == 0) {
            revert InvalidGasLimit();
        }
        emit DefaultGasLimitUpdated(defaultGasLimit, newDefaultGasLimit);
        defaultGasLimit = newDefaultGasLimit;
    }
}
