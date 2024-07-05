// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IConfigurationManager} from "../interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "../types/ConfigurationManagerTypes.sol";

/**
 * @custom:see IConfigurationManager
 */
contract ConfigurationManager is IConfigurationManager {
    /**
     * @notice The governor contract address which is authorised to call protected methods
     */
    address public governor;

    /**
     * @notice The Rewards And Farmed Tokens contract. It is where rewards and farmed tokens are
     *         sent for processing
     */
    address public raft;

    constructor(ConfigurationManager memory params) {
        governor = params.governor;
        raft = params.raft;
    }

    function setGovernor(address newGovernor) public onlyGovernor {
        governor = newGovernor;

        emit GovernorUpdated(newGovernor);
    }

    function setRaft(address newRaft) public onlyGovernor {
        raft = newRaft;

        emit RaftUpdated(newRaft);
    }

}