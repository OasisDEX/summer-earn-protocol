// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IArkAccessControl} from "./IArkAccessControl.sol";

interface IArkFactory is IArkAccessControl {
    /* ERRORS */
    error CannotSetRaftToZeroAddress();

    /* STRUCTS */

    /**
     * @notice Configuration parameters for the ArkFactory contract
     *
     * @dev Used to prevent stack too deep error
     */
    struct ArkFactoryParams {
        address governor;
        address raft;
        address aaveV3Pool;
    }

    /* EVENTS */
    event ArkCreated(address indexed arkAddress, address raft, address token, string arkType);
    event RaftUpdated(address newRaft);
    event GovernorUpdated(address newGovernor);

    /* FUNCTIONS - FACTORIES */
    function createAaveV3Ark(address _token) external returns (address);
}
