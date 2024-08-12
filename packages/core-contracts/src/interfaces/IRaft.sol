// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IRaftEvents} from "../events/IRaftEvents.sol";

/**
 * @title IRaft
 * @notice Interface for the Raft contract which manages harvesting, swapping, and reinvesting of rewards.
 * @dev This interface defines the core functionality for managing rewards from various Arks.
 */
interface IRaft is IRaftEvents {
    /**
     * @notice Harvests rewards from the specified Ark without swapping or reinvesting.
     * @dev This function only collects rewards, storing them in the Raft contract for later use.
     * @param ark The address of the Ark contract to harvest rewards from.
     * @param rewardToken The address of the reward token to be harvested.
     * @param extraHarvestData Additional data required by a protocol to harvest
     */
    function harvest(
        address ark,
        address rewardToken,
        bytes calldata extraHarvestData
    ) external;

    /**
     * @notice Retrieves the amount of harvested rewards for a specific Ark and reward token.
     * @dev This function allows querying the balance of harvested rewards before deciding on further actions.
     * @param ark The address of the Ark contract.
     * @param rewardToken The address of the reward token.
     * @return The amount of harvested rewards for the specified Ark and token.
     */
    function getHarvestedRewards(
        address ark,
        address rewardToken
    ) external view returns (uint256);
}
