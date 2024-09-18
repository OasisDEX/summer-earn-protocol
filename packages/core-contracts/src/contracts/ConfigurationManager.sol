// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IConfigurationManager} from "../interfaces/IConfigurationManager.sol";

import {ConfigurationManagerParams} from "../types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";

/**
 * @title ConfigurationManager
 * @notice Manages system-wide configuration parameters for the protocol
 * @dev Implements the IConfigurationManager interface and inherits from ProtocolAccessManaged
 */
contract ConfigurationManager is IConfigurationManager, ProtocolAccessManaged {
    bool public initialized;
    /**
     * @notice The address of the Raft contract
     * @dev This is where rewards and farmed tokens are sent for processing
     */
    address public raft;

    /**
     * @notice The address of the TipJar contract
     * @dev This is the contract that owns tips and is responsible for
     *      dispensing them to claimants
     */
    address public tipJar;

    /**
     * @notice The address of the Treasury contract
     * @dev This is the contract that owns the treasury and is responsible for
     *      dispensing funds to the protocol's operations
     */
    address public treasury;

    /**
     * @notice Constructs the ConfigurationManager contract
     * @param _accessManager The address of the ProtocolAccessManager contract
     */
    constructor(address _accessManager) ProtocolAccessManaged(_accessManager) {}

    function initialize(
        ConfigurationManagerParams memory params
    ) external onlyGovernor {
        if (initialized) {
            revert ConfigurationManagerAlreadyInitialized();
        }
        raft = params.raft;
        tipJar = params.tipJar;
        treasury = params.treasury;
        initialized = true;
    }
    /**
     * @notice Sets a new address for the Raft contract
     * @param newRaft The new address for the Raft contract
     * @dev Can only be called by the governor
     * @dev Emits a RaftUpdated event
     */
    function setRaft(address newRaft) external onlyGovernor {
        raft = newRaft;
        emit RaftUpdated(newRaft);
    }

    /**
     * @notice Sets a new address for the TipJar contract
     * @param newTipJar The new address for the TipJar contract
     * @dev Can only be called by the governor
     * @dev Emits a TipJarUpdated event
     */
    function setTipJar(address newTipJar) external onlyGovernor {
        tipJar = newTipJar;
        emit TipJarUpdated(newTipJar);
    }

    /**
     * @notice Sets a new address for the Treasury contract
     * @param newTreasury The new address for the Treasury contract
     * @dev Can only be called by the governor
     * @dev Emits a TreasuryUpdated event
     */
    function setTreasury(address newTreasury) external onlyGovernor {
        treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }
}
