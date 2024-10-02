// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {IConfigurationManagerErrors} from "../errors/IConfigurationManagerErrors.sol";
import {IConfigurationManagerEvents} from "../events/IConfigurationManagerEvents.sol";
import {ConfigurationManagerParams} from "../types/ConfigurationManagerTypes.sol";
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
     * @notice Initialize the ConfigurationManager contract
     * @param params The parameters to initialize the contract with
     * @dev Can only be called by the governor
     */
    function initialize(ConfigurationManagerParams memory params) external;
    /**
     * @notice Get the address of the Raft contract
     * @return The address of the Raft contract
     */
    function raft() external view returns (address);

    /**
     * @notice Get the current tip jar address
     * @return The current tip jar address
     */
    function tipJar() external view returns (address);

    /**
     * @notice Get the current treasury address
     * @return The current treasury address
     */
    function treasury() external view returns (address);

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

    /**
     * @notice Set a new treasury address
     * @param newTreasury The address of the new treasury
     * @dev Can only be called by the governor
     */
    function setTreasury(address newTreasury) external;
}
