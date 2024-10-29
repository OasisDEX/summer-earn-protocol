// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IConfigurationManagerErrors} from "./IConfigurationManagerErrors.sol";
import {IConfigurationManagerEvents} from "./IConfigurationManagerEvents.sol";
import {ConfigurationManagerParams} from "./ConfigurationManagerTypes.sol";
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
     * @notice Initialize the configuration with the given parameters
     * @param params The parameters to initialize the configuration with
     * @dev Can only be called by the governor
     */
    function initializeConfiguration(
        ConfigurationManagerParams memory params
    ) external;

    /**
     * @notice Get the address of the Raft contract
     * @return The address of the Raft contract
     * @dev This is where rewards and farmed tokens are sent for processing
     */
    function raft() external view returns (address);

    /**
     * @notice Get the current tip jar address
     * @return The current tip jar address
     * @dev This is the contract that owns tips and is responsible for
     *     dispensing them to claimants
     */
    function tipJar() external view returns (address);

    /**
     * @notice Get the current treasury address
     * @return The current treasury address
     *       @dev This is the contract that owns the treasury and is responsible for
     *      dispensing funds to the protocol's operations
     */
    function treasury() external view returns (address);

    /**
     * @notice Get the address of theHarbor command
     * @return The address of theHarbor command
     * @dev This is the contract that's the registry of all Fleet Commanders
     */
    function harborCommand() external view returns (address);

    /**
     * @notice Get the address of the governor
     * @return The address of the governor
     */
    function governor() external view returns (address);

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

    /**
     * @notice Set a new harbor command address
     * @param newHarborCommand The address of the new harbor command
     * @dev Can only be called by the governor
     */
    function setHarborCommand(address newHarborCommand) external;

    /**
     * @notice Set a new governor address
     * @param newGovernor The address of the new governor
     * @dev Can only be called by the governor
     */
    function setGovernor(address newGovernor) external;
}
