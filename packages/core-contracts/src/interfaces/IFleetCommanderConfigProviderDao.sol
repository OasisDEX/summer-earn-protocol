// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IFleetCommanderConfigProviderErrors} from "../errors/IFleetCommanderConfigProviderErrors.sol";

import {IFleetCommanderConfigProviderEvents} from "../events/IFleetCommanderConfigProviderEvents.sol";

import {FleetConfigDao} from "../types/FleetCommanderTypes.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

/**
 * @title IFleetCommanderDao Interface
 * @notice Interface for the FleetCommander contract, which manages asset allocation across multiple Arks
 */
interface IFleetCommanderConfigProviderDao is
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
     * @notice Retrieves the arks currently linked to fleet (excluding the buffer ark)
     */
    function getActiveArks() external view returns (address[] memory);

    /**
     * @notice Retrieves the current fleet config
     */
    function getConfig() external view returns (FleetConfigDao memory);

    /**
     * @notice Retrieves the buffer ark address
     */
    function bufferArk() external view returns (address);

    /**
     * @notice Checks if the ark is part of the fleet or is the buffer ark
     * @param ark The address of the Ark
     * @return bool Returns true if the ark is active or the buffer ark, false otherwise.
     */
    function isArkActiveOrBufferArk(address ark) external view returns (bool);

    /* FUNCTIONS - EXTERNAL - GOVERNANCE */

    /**
     * @notice Adds a new Ark
     * @param ark The address of the new Ark
     */
    function addArk(address ark) external;

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
     * @notice Sets the deposit cap for Fleet to zero. Failsafe mechanism to prevent deposits if needed.
     * @dev Only callable by the guardian
     */
    function setFleetDepositCapToZero() external;

    /**
     * @notice Sets a new deposit cap for an Ark
     * @param ark The address of the Ark
     * @param newDepositCap The new deposit cap
     */
    function setArkDepositCap(address ark, uint256 newDepositCap) external;
    /**
     * @notice Sets the deposit cap for an Ark to zero. Failsafe mechanism to prevent deposits if needed.
     * @param ark The address of the Ark
     * @dev Only callable by the guardian
     */
    function setArkDepositCapToZero(address ark) external;

    /**
     * @notice Sets the max deposit percentage of TVL for an Ark
     * @param ark The address of the Ark
     * @param newMaxDepositPercentageOfTVL The new max deposit percentage of TVL
     */
    function setArkMaxDepositPercentageOfTVL(
        address ark,
        Percentage newMaxDepositPercentageOfTVL
    ) external;

    /**
     * @dev Sets the minimum buffer balance for the fleet commander.
     * @param newMinimumBalance The new minimum buffer balance to be set.
     */
    function setMinimumBufferBalance(uint256 newMinimumBalance) external;

    /**
     * @dev Sets the maximum number of allowed rebalance operations per rebalance call.
     * @param newMaxRebalanceOperations The new maximum allowed rebalance operations.
     */
    function setMaxRebalanceOperations(
        uint256 newMaxRebalanceOperations
    ) external;

    /**
     * @notice Sets the maxRebalanceOutflow for an Ark
     * @dev Only callable by the curator
     * @param ark The address of the Ark
     * @param newMaxRebalanceOutflow The new maxRebalanceOutflow value
     */
    function setArkMaxRebalanceOutflow(
        address ark,
        uint256 newMaxRebalanceOutflow
    ) external;

    /**
     * @notice Sets the maxRebalanceInflow for an Ark
     * @dev Only callable by the curator
     * @param ark The address of the Ark
     * @param newMaxRebalanceInflow The new maxRebalanceInflow value
     */
    function setArkMaxRebalanceInflow(
        address ark,
        uint256 newMaxRebalanceInflow
    ) external;

    /**
     *   @notice Sets the tip jar address for the FleetCommanderDao
     *   @param newTipJar The address of the new tip jar
     *   @dev Only callable by the curator
     */
    function setTipJar(address newTipJar) external;
}
