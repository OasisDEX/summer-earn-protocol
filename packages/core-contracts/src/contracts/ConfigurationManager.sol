// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IConfigurationManager} from "../interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "../types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @custom:see IConfigurationManager
 */
contract ConfigurationManager is Initializable, IConfigurationManager, ProtocolAccessManaged {
    /**
     * @notice The Rewards And Farmed Tokens contract. It is where rewards and farmed tokens are
     *         sent for processing
     */
    address public raft;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        ConfigurationManagerParams memory params
    ) public initializer {
        ProtocolAccessManaged.__ProtocolAccessManaged_init(params.accessManager);
        raft = params.raft;
    }

    function setRaft(address newRaft) external onlyGovernor {
        raft = newRaft;

        emit RaftUpdated(newRaft);
    }
}
