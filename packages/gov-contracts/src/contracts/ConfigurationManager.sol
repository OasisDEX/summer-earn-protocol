// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IConfigurationManager} from "../interfaces/IConfigurationManager.sol";

import {ConfigurationManagerParams} from "../types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";

/**
 * @title ConfigurationManager
 * @notice Manages system-wide configuration parameters for the protocol
 * @custom:see IConfigurationManager
 */
contract ConfigurationManager is IConfigurationManager, ProtocolAccessManaged {
    bool public initialized;

    /// @inheritdoc IConfigurationManager
    address public raft;

    /// @inheritdoc IConfigurationManager
    address public tipJar;

    /// @inheritdoc IConfigurationManager
    address public treasury;

    /// @inheritdoc IConfigurationManager
    address public harborCommand;

    /// @inheritdoc IConfigurationManager
    address public fleetCommanderRewardsManagerFactory;

    /**
     * @notice Constructs the ConfigurationManager contract
     * @param _accessManager The address of the ProtocolAccessManager contract
     */
    constructor(address _accessManager) ProtocolAccessManaged(_accessManager) {}

    /// @inheritdoc IConfigurationManager
    function initializeConfiguration(
        ConfigurationManagerParams memory params
    ) external onlyGovernor {
        if (initialized) {
            revert ConfigurationManagerAlreadyInitialized();
        }
        if (
            params.raft == address(0) ||
            params.tipJar == address(0) ||
            params.treasury == address(0) ||
            params.harborCommand == address(0) ||
            params.fleetCommanderRewardsManagerFactory == address(0)
        ) {
            revert AddressZero();
        }
        raft = params.raft;
        tipJar = params.tipJar;
        treasury = params.treasury;
        harborCommand = params.harborCommand;
        fleetCommanderRewardsManagerFactory = params
            .fleetCommanderRewardsManagerFactory;
        emit RaftUpdated(address(0), params.raft);
        emit TipJarUpdated(address(0), params.tipJar);
        emit TreasuryUpdated(address(0), params.treasury);
        emit HarborCommandUpdated(address(0), params.harborCommand);
        emit FleetCommanderRewardsManagerFactoryUpdated(
            address(0),
            params.fleetCommanderRewardsManagerFactory
        );
        initialized = true;
    }

    /// @inheritdoc IConfigurationManager
    function setRaft(address newRaft) external onlyGovernor {
        if (newRaft == address(0)) {
            revert AddressZero();
        }
        emit RaftUpdated(raft, newRaft);
        raft = newRaft;
    }

    /// @inheritdoc IConfigurationManager
    function setTipJar(address newTipJar) external onlyGovernor {
        if (newTipJar == address(0)) {
            revert AddressZero();
        }
        emit TipJarUpdated(tipJar, newTipJar);
        tipJar = newTipJar;
    }

    /// @inheritdoc IConfigurationManager
    function setTreasury(address newTreasury) external onlyGovernor {
        if (newTreasury == address(0)) {
            revert AddressZero();
        }
        emit TreasuryUpdated(treasury, newTreasury);
        treasury = newTreasury;
    }

    /// @inheritdoc IConfigurationManager
    function setHarborCommand(address newHarborCommand) external onlyGovernor {
        if (newHarborCommand == address(0)) {
            revert AddressZero();
        }
        emit HarborCommandUpdated(harborCommand, newHarborCommand);
        harborCommand = newHarborCommand;
    }

    /// @inheritdoc IConfigurationManager
    function setFleetCommanderRewardsManagerFactory(
        address newFleetCommanderRewardsManagerFactory
    ) external onlyGovernor {
        if (newFleetCommanderRewardsManagerFactory == address(0)) {
            revert AddressZero();
        }
        emit FleetCommanderRewardsManagerFactoryUpdated(
            fleetCommanderRewardsManagerFactory,
            newFleetCommanderRewardsManagerFactory
        );
        fleetCommanderRewardsManagerFactory = newFleetCommanderRewardsManagerFactory;
    }
}
