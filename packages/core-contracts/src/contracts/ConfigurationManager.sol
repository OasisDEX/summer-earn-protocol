// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IConfigurationManager} from "../interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "../types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";

/**
 * @custom:see IConfigurationManager
 */
contract ConfigurationManager is IConfigurationManager, ProtocolAccessManaged {
    /**
     * @notice The Rewards And Farmed Tokens contract. It is where rewards and farmed tokens are
     *         sent for processing
     */
    address public raft;

    constructor(
        ConfigurationManagerParams memory _params
    ) ProtocolAccessManaged(_params.accessManager) {
        raft = _params.raft;
    }

    function setRaft(address newRaft) external onlyGovernor {
        raft = newRaft;

        emit RaftUpdated(newRaft);
    }
}
