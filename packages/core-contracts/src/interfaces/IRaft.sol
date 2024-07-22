// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {SwapData} from "../types/RaftTypes.sol";
import {IRaftEvents} from "./IRaftEvents.sol";

/**
 * @title IRaft
 * @notice Interface for the Raft contract, which manages harvesting, swapping, and boarding of rewards for Arks
 */
interface IRaft is IRaftEvents {
    /**
     * @notice Harvests rewards from an Ark, swaps them, and boards them back into the Ark
     * @param ark The address of the Ark contract
     * @param rewardToken The address of the reward token
     */
    function harvestAndBoard(address ark, address rewardToken) external;

    /**
     * @notice Swaps harvested rewards and boards them back into the Ark
     * @param ark The address of the Ark contract
     * @param rewardToken The address of the reward token
     */
    function swapAndBoard(address ark, address rewardToken) external;

    /**
     * @notice Harvests rewards from an Ark
     * @param ark The address of the Ark contract
     * @param rewardToken The address of the reward token
     */
    function harvest(address ark, address rewardToken) external;

    /**
     * @notice Gets the amount of harvested rewards for a specific Ark and reward token
     * @param ark The address of the Ark contract
     * @param rewardToken The address of the reward token
     * @return The amount of harvested rewards
     */
    function getHarvestedRewards(address ark, address rewardToken) external view returns (uint256);

    /**
     * @notice Sets the allowed fee tiers for Uniswap V3 pools
     * @param _allowedFeeTiers_ An array of allowed fee tiers
     */
    function setAllowedFeeTiers(uint24[] memory _allowedFeeTiers_) external;

    /**
     * @notice Gets the price and fee for a token pair
     * @param tokenIn The address of the input token
     * @param tokenOut The address of the output token
     * @param fees An array of fee tiers to check
     * @return price The price of tokenOut in terms of tokenIn
     * @return fee The fee tier of the selected pool
     */
    function getPrice(
        address tokenIn,
        address tokenOut,
        uint24[] memory fees
    ) external view returns (uint256 price, uint24 fee);
}