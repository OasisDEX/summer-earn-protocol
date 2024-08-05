// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {SwapData} from "../types/RaftTypes.sol";
import {IRaftEvents} from "./IRaftEvents.sol";

/**
 * @title IRaft
 * @notice Interface for the Raft contract which manages harvesting, swapping, and reinvesting of rewards.
 * @dev This interface defines the core functionality for managing rewards from various Arks.
 */
interface IRaft is IRaftEvents {
    /**
     * @notice Harvests rewards from the specified Ark, swaps them, and reinvests the proceeds.
     * @dev This function combines harvesting, swapping, and reinvesting in a single transaction.
     * @param ark The address of the Ark contract to harvest rewards from.
     * @param rewardToken The address of the reward token to be harvested and swapped.
     * @param swapData Data required for the swap operation, including the target token and minimum received amount.
     * @param extraHarvestData Additional data required by a protocol to harvest
     */
    function harvestAndBoard(
        address ark,
        address rewardToken,
        SwapData calldata swapData,
        bytes calldata extraHarvestData
    ) external;

    /**
     * @notice Swaps previously harvested rewards and reinvests them into the specified Ark.
     * @dev This function assumes rewards have already been harvested and are held by the Raft contract.
     * @param ark The address of the Ark contract to reinvest into.
     * @param rewardToken The address of the harvested reward token to be swapped.
     * @param swapData Data required for the swap operation, including the target token and minimum received amount.
     */
    function swapAndBoard(
        address ark,
        address rewardToken,
        SwapData calldata swapData
    ) external;

    /**
     * @notice Harvests rewards from the specified Ark without swapping or reinvesting.
     * @dev This function only collects rewards, storing them in the Raft contract for later use.
     * @param ark The address of the Ark contract to harvest rewards from.
     * @param rewardToken The address of the reward token to be harvested.
     * @param extraHarvestData Additional data required by a protocol to harvest
     */
    function harvest(address ark, address rewardToken, bytes calldata extraHarvestData) external;

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
