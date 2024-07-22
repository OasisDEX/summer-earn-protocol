// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IConfigurationManagerEvents} from "./IConfigurationManagerEvents.sol";

/**
 * @title IConfigurationManager
 * @notice Defines the setters for system-wide parameters
 */
interface IConfigurationManager is IConfigurationManagerEvents {

    function raft() external returns (address);
    function setRaft(address newRaft) external;

}
