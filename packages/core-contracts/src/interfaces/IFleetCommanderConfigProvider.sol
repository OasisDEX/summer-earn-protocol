// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IFleetCommanderConfigProviderErrors} from "../errors/IFleetCommanderConfigProviderErrors.sol";

import {IFleetCommanderConfigProviderEvents} from "../events/IFleetCommanderConfigProviderEvents.sol";

import {FleetConfig} from "../types/FleetCommanderTypes.sol";

/**
 * @title IFleetCommander Interface
 * @notice Interface for the FleetCommander contract, which manages asset allocation across multiple Arks
 */
interface IFleetCommanderConfigProvider is
    IFleetCommanderConfigProviderErrors,
    IFleetCommanderConfigProviderEvents
{
    /**
     * @notice Retrieves the ark address at the specified index
     * @param index The index of the ark in the arks array
     * @return The address of the ark at the specified index
     */
    function arks(uint256 index) external view returns (address);

    /**
     * @notice Retrieves the arks currently linked to fleet
     */
    function getArks() external view returns (address[] memory);

    /**
     * @notice Retrieves the current fleet config
     */
    function getConfig() external view returns (FleetConfig memory);

    /**
     * @notice Retrieves the buffer ark address
     */
    function bufferArk() external view returns (address);

    /**
     * @notice Checks if the ark is part of the fleet
     * @param ark The address of the Ark
     * @return bool Returns true if the ark is active, false otherwise.
     */
    function isArkActive(address ark) external view returns (bool);

    /* FUNCTIONS - EXTERNAL - GOVERNANCE */

    /**
     * @notice Adds a new Ark
     * @param ark The address of the new Ark
     */
    function addArk(address ark) external;

    /**
     * @notice Adds multiple Arks in a batch
     * @param arks Array of ark addresses
     */
    function addArks(address[] calldata arks) external;

    /**
     * @notice Removes an existing Ark
     * @param ark The address of the Ark to remove
     */
    function removeArk(address ark) external;

    /**
     * @notice Sets a new deposit cap for Fleet
     * @param newDepositCap The new deposit cap
     */
    function setFleetDepositCap(uint256 newDepositCap) external;

    /**
     * @notice Sets a new deposit cap for an Ark
     * @param ark The address of the Ark
     * @param newDepositCap The new deposit cap
     */
    function setArkDepositCap(address ark, uint256 newDepositCap) external;

    /**
     * @dev Sets the minimum buffer balance for the fleet commander.
     * @param newMinimumBalance The new minimum buffer balance to be set.
     */
    function setMinimumBufferBalance(uint256 newMinimumBalance) external;

    /**
     * @dev Sets the minimum number of allowe rebalance operations.
     * @param newMaxRebalanceOperations The new maximum allowed rebalance operations.
     */
    function setMaxRebalanceOperations(
        uint256 newMaxRebalanceOperations
    ) external;

    /**
     * @notice Sets the maxRebalanceOutflow for an Ark
     * @dev Only callable by the governor
     * @param ark The address of the Ark
     * @param newMaxRebalanceOutflow The new maxRebalanceOutflow value
     */
    function setArkMaxRebalanceOutflow(
        address ark,
        uint256 newMaxRebalanceOutflow
    ) external;

    /**
     * @notice Sets the maxRebalanceInflow for an Ark
     * @dev Only callable by the governor
     * @param ark The address of the Ark
     * @param newMaxRebalanceInflow The new maxRebalanceInflow value
     */
    function setArkMaxRebalanceInflow(
        address ark,
        uint256 newMaxRebalanceInflow
    ) external;

    /**
     * @notice Sets the staking rewards manager contract address
     * @param newStakingRewardsManager The address  of the new staking rewards manager contract
     */
    function setStakingRewardsManager(
        address newStakingRewardsManager
    ) external;
}
