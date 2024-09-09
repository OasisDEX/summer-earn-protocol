// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IConfigurationManagerEvents} from "../events/IConfigurationManagerEvents.sol";
import {IConfigurationManagerErrors} from "../errors/IConfigurationManagerErrors.sol";

/**
 * @title IConfigurationManager
 * @notice Interface for the ConfigurationManager contract, which manages system-wide parameters
 * @dev This interface defines the getters and setters for system-wide parameters
 */
interface IConfigurationManager is
    IConfigurationManagerEvents,
    IConfigurationManagerErrors
{
    /**
     * @notice Get the address of the Raft contract
     * @return The address of the Raft contract
     */
    function raft() external returns (address);

    /**
     * @notice Get the current tip jar address
     * @return The current tip jar address
     */
    function tipJar() external returns (address);

    /**
     * @notice Set a new address for the Raft contract
     * @param newRaft The new address for the Raft contract
     * @dev Can only be called by the governor
     */
    function setRaft(address newRaft) external;

    /**
     * @notice Set a new tip ar address
     * @param newTipJar The address of the new tip jar
     * @dev Can only be called by the governor
     */
    function setTipJar(address newTipJar) external;
}
