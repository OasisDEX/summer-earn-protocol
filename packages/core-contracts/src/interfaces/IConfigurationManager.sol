// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IConfigurationManagerAccessControl} from "./IConfigurationManagerAccessControl.sol";
import {IConfigurationManagerEvents} from "./IConfigurationManagerEvents.sol";

/**
 * @title IConfigurationManager
 * @notice Defines the setters for system-wide parameters
 */
interface IConfigurationManager is IConfigurationManagerAccessControl, IConfigurationManagerEvents {
    function governor() external returns (address);
    function raft() external returns (address);
    function setGovernor(address newGovernor) external;
    function setRaft(address newRaft) external;
}