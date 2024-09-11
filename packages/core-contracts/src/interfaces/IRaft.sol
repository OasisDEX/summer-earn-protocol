// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IRaftErrors} from "../errors/IRaftErrors.sol";
import {IRaftEvents} from "../events/IRaftEvents.sol";

/**
 * @title IRaft
 * @notice Interface for the Raft contract which manages harvesting, auctioning, and reinvesting of rewards.
 * @dev This interface defines the core functionality for managing rewards from various Arks.
 */
interface IRaft is IRaftEvents, IRaftErrors {
    /**
     * @notice Harvests rewards from the specified Ark without auctioning or reinvesting.
     * @dev This function only collects rewards, storing them in the Raft contract for later use.
     * @param ark The address of the Ark contract to harvest rewards from.
     * @param extraHarvestData Additional data required by a protocol to harvest
     */
    function harvest(address ark, bytes calldata extraHarvestData) external;

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

    /**
     * @notice Starts a Dutch auction for the harvested rewards of a specific Ark and reward token.
     * @dev This function initiates the auction process for selling harvested rewards.
     * @param ark The address of the Ark contract.
     * @param rewardToken The address of the reward token to be auctioned.
     * @param paymentToken The address of the token used for payment in the auction.
     */
    function startAuction(
        address ark,
        address rewardToken,
        address paymentToken
    ) external;

    /**
     * @notice Allows users to buy tokens from an active auction.
     * @dev This function handles the token purchase process in the Dutch auction.
     * @param ark The address of the Ark contract.
     * @param rewardToken The address of the reward token being auctioned.
     * @param amount The amount of tokens to purchase.
     * @return paymentAmount The amount of payment tokens required to purchase the specified amount of reward tokens.
     */
    function buyTokens(
        address ark,
        address rewardToken,
        uint256 amount
    ) external returns (uint256 paymentAmount);

    /**
     * @notice Finalizes an auction after its end time has been reached.
     * @dev This function settles the auction and handles unsold tokens.
     * @param ark The address of the Ark contract.
     * @param rewardToken The address of the reward token that was auctioned.
     */
    function finalizeAuction(address ark, address rewardToken) external;

    /**
     * @dev Returns the current price of a given asset in terms of the reward token.
     * @param ark The address of the asset.
     * @param rewardToken The address of the reward token.
     * @return The current price of the asset.
     */
    function getCurrentPrice(
        address ark,
        address rewardToken
    ) external view returns (uint256);
}
