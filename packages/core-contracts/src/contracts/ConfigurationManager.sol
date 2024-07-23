// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IConfigurationManager} from "../interfaces/IConfigurationManager.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {ConfigurationManagerParams} from "../types/ConfigurationManagerTypes.sol";

/**
 * @title ConfigurationManager
 * @notice Manages system-wide configuration parameters for the protocol
 * @dev Implements the IConfigurationManager interface and inherits from ProtocolAccessManaged
 */
contract ConfigurationManager is IConfigurationManager, ProtocolAccessManaged {
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
     * @notice The current tip rate
     */
    uint8 public tipRate;

    /**
     * @notice Constructs the ConfigurationManager contract
     * @param params A struct containing the initial configuration parameters
     */
    constructor(
        ConfigurationManagerParams memory params
    ) ProtocolAccessManaged(params.accessManager) {
        raft = params.raft;
        tipRate = params.tipRate;
        tipJar = params.tipJar;
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
     * @notice Sets a new tip rate
     * @param newTipRate The new tip rate to set
     * @dev Can only be called by the governor
     * @dev Emits a TipRateUpdated event
     */
    function setTipRate(uint8 newTipRate) external onlyGovernor {
        tipRate = newTipRate;
        emit TipRateUpdated(newTipRate);
    }
}
