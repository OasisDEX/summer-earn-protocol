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
     * @notice The current tip rate
     */
    uint8 public tipRate;

    /**
     * @notice Constructs the ConfigurationManager contract
     * @param _params A struct containing the initial configuration parameters
     */
    constructor(ConfigurationManagerParams memory _params) ProtocolAccessManaged(_params.accessManager) {
        raft = _params.raft;
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