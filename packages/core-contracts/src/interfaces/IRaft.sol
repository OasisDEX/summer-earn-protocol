// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {SwapData} from "../types/RaftTypes.sol";
import {IRaftEvents} from "./IRaftEvents.sol";

/**
 * @title IRaft
 * @notice Interface for the Raft contract which manages harvesting, swapping, and reinvesting of rewards.
 */
interface IRaft is IRaftEvents {
    /**
     * @notice Harvests rewards from the specified Ark and reinvests them.
     * @param ark The address of the Ark contract.
     * @param rewardToken The address of the reward token to be harvested.
     */
    function harvestAndBoard(
        address ark,
        address rewardToken
    ) external;

    /**
     * @notice Swaps harvested rewards and reinvests them.
     * @param ark The address of the Ark contract.
     * @param rewardToken The address of the reward token to be swapped.
     */
    function swapAndBoard(
        address ark,
        address rewardToken
    ) external;

    /**
     * @notice Harvests rewards from the specified Ark.
     * @param ark The address of the Ark contract.
     * @param rewardToken The address of the reward token to be harvested.
     */
    function harvest(address ark, address rewardToken) external;

    /**
     * @notice Gets the amount of harvested rewards for a specific Ark and reward token.
     * @param ark The address of the Ark contract.
     * @param rewardToken The address of the reward token.
     * @return The amount of harvested rewards.
     */
    function getHarvestedRewards(
        address ark,
        address rewardToken
    ) external view returns (uint256);
}
