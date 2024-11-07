// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IRaftErrors} from "../errors/IRaftErrors.sol";
import {IRaftEvents} from "../events/IRaftEvents.sol";

import {AuctionDefaultParameters} from "../types/CommonAuctionTypes.sol";
import {DutchAuctionLibrary} from "@summerfi/dutch-auction/DutchAuctionLibrary.sol";

/**
 * @title IRaft
 * @notice Interface for the Raft contract which manages harvesting, auctioning, and reinvesting of rewards.
 * @dev This interface defines the core functionality for managing rewards from various Arks.
 */
interface IRaft is IRaftEvents, IRaftErrors {
    /**
     * @dev Harvests rewards from the specified Ark and starts an auction for the harvested tokens
     * @param ark The address of the Ark contract to harvest rewards from
     * @param paymentToken The address of the token used for payment in the auction
     * @param rewardData Additional data required by a protocol to harvest
     * @custom:internal-logic
     * - Harvests rewards from the specified Ark
     * - Starts an auction for each harvested token
     * @custom:effects
     * - Updates obtainedTokens mapping
     * - Creates new auctions
     * @custom:security-considerations
     * - Ensure only authorized addresses can call this function
     * - Validate input parameters
     */
    function harvestAndStartAuction(
        address ark,
        address paymentToken,
        bytes calldata rewardData
    ) external;

    /**
     * @dev Harvests rewards from the specified Ark without auctioning or reinvesting
     * @param ark The address of the Ark contract to harvest rewards from
     * @param rewardData Additional data required by a protocol to harvest
     * @custom:internal-logic
     * - Calls the harvest function on the specified Ark
     * - Updates the obtainedTokens mapping with harvested amounts
     * @custom:effects
     * - Updates obtainedTokens mapping
     * @custom:security-considerations
     * - Validate the Ark address
     * - Ensure proper handling of rewardData
     */
    function harvest(address ark, bytes calldata rewardData) external;

    /**
     * @dev Sweeps tokens from the specified Ark and returns them to the caller
     * @param ark The address of the Ark contract to sweep tokens from
     * @param tokens The addresses of the tokens to sweep
     * @return sweptTokens The addresses of the tokens that were swept
     * @return sweptAmounts The amounts of the tokens that were swept
     * @custom:internal-logic
     * - Calls the sweep function on the specified Ark
     * - Updates the obtainedTokens mapping with swept amounts
     * @custom:effects
     * - Updates obtainedTokens mapping
     * - Transfers swept tokens to the contract
     * @custom:security-considerations
     * - Validate input parameters
     */
    function sweep(
        address ark,
        address[] calldata tokens
    )
        external
        returns (address[] memory sweptTokens, uint256[] memory sweptAmounts);

    /**
     * @dev Sweeps tokens from the specified Ark and starts an auction for them
     * @param ark The address of the Ark contract to sweep tokens from
     * @param tokens The addresses of the tokens to sweep
     * @param paymentToken The address of the token used for payment in the auction
     * @custom:internal-logic
     * - Sweeps specified tokens from the Ark
     * - Starts an auction for each swept token
     * @custom:effects
     * - Updates obtainedTokens mapping
     * - Creates new auctions
     * @custom:security-considerations
     * - Validate input parameters
     */
    function sweepAndStartAuction(
        address ark,
        address[] calldata tokens,
        address paymentToken
    ) external;

    /**
     * @dev Retrieves the amount of harvested rewards for a specific Ark and reward token
     * @param ark The address of the Ark contract
     * @param rewardToken The address of the reward token
     * @return The amount of harvested rewards for the specified Ark and token
     * @custom:internal-logic
     * - Retrieves the value from the obtainedTokens mapping
     * @custom:effects
     * - No state changes (view function)
     * @custom:security-considerations
     * - Ensure the returned data doesn't expose sensitive information
     */
    function getObtainedTokens(
        address ark,
        address rewardToken
    ) external view returns (uint256);

    /**
     * @dev Starts a Dutch auction for the harvested rewards of a specific Ark and reward token
     * @param ark The address of the Ark contract
     * @param rewardToken The address of the reward token to be auctioned
     * @param paymentToken The address of the token used for payment in the auction
     * @custom:internal-logic
     * - Creates a new auction for the specified reward token
     * - Resets obtainedTokens and unsoldTokens for the given Ark and reward token
     * @custom:effects
     * - Creates a new auction
     * - Updates obtainedTokens and unsoldTokens mappings
     * @custom:security-considerations
     * - Ensure only authorized addresses can call this function
     * - Check for existing auctions before starting a new one
     */
    function startAuction(
        address ark,
        address rewardToken,
        address paymentToken
    ) external;

    /**
     * @dev Allows users to buy tokens from an active auction
     * @param ark The address of the Ark contract
     * @param rewardToken The address of the reward token being auctioned
     * @param amount The amount of tokens to purchase
     * @return paymentAmount The amount of payment tokens required to purchase the specified amount of reward tokens
     * @custom:internal-logic
     * - Retrieves the auction data for the specified Ark and reward token
     * - Calls the buyTokens function of the DutchAuctionLibrary
     * - Updates the paymentTokensToBoard mapping
     * - Settles the auction if all tokens are sold
     * @custom:effects
     * - Transfers tokens between the buyer and the contract
     * - Updates the auction state
     * - May settle the auction if all tokens are sold
     * @custom:security-considerations
     * - Ensure proper token transfers and balance updates
     * - Handle potential reentrancy risks
     */
    function buyTokens(
        address ark,
        address rewardToken,
        uint256 amount
    ) external returns (uint256 paymentAmount);

    /**
     * @dev Finalizes an auction after its end time has been reached
     * @param ark The address of the Ark contract
     * @param rewardToken The address of the reward token that was auctioned
     * @custom:internal-logic
     * - Retrieves the auction data
     * - Calls the finalizeAuction function of the DutchAuctionLibrary
     * - Settles the auction
     * - if an ark doesn't require keeper data, the raised funds will be boarded autoamtically
     * @custom:effects
     * - Updates the auction state
     * - May transfer unsold tokens
     * - May initiate boarding of payment tokens
     * @custom:security-considerations
     * - Ensure the auction has ended before finalizing
     * - Handle potential edge cases with unsold tokens
     */
    function finalizeAuction(address ark, address rewardToken) external;

    /**
     * @dev Retrieves information about a specific auction
     * @param ark The address of the Ark contract
     * @param rewardToken The address of the reward token
     * @return The Auction struct containing auction details
     * @custom:internal-logic
     * - Retrieves the auction data from the auctions mapping
     * @custom:effects
     * - No state changes (view function)
     * @custom:security-considerations
     * - Ensure the returned data doesn't expose sensitive information
     */
    function getAuctionInfo(
        address ark,
        address rewardToken
    ) external view returns (DutchAuctionLibrary.Auction memory);

    /**
     * @dev Gets the current price of tokens in an ongoing auction
     * @param ark The address of the Ark contract
     * @param rewardToken The address of the reward token
     * @return The current price of the auction
     * @custom:internal-logic
     * - Retrieves the auction data
     * - Calls the getCurrentPrice function of the DutchAuctionLibrary
     * @custom:effects
     * - No state changes (view function)
     * @custom:security-considerations
     * - Ensure the auction is ongoing when calling this function
     */
    function getCurrentPrice(
        address ark,
        address rewardToken
    ) external view returns (uint256);

    /**
     * @dev Updates the default parameters for future auctions
     * @param newConfig The new default parameters
     * @custom:internal-logic
     * - Updates the auctionDefaultParameters with the new configuration
     * @custom:effects
     * - Modifies the auctionDefaultParameters
     * @custom:security-considerations
     * - Ensure only authorized addresses can update parameters
     * - Validate the new parameters
     */
    function updateAuctionDefaultParameters(
        AuctionDefaultParameters calldata newConfig
    ) external;

    /**
     * @dev Boards the auctioned token to an Ark
     * @param ark The address of the Ark contract
     * @param rewardToken The address of the reward token to board the rewards to
     * @param data Additional data required by the Ark to board rewards
     * @custom:internal-logic
     * - Checks if the Ark requires keeper data
     * - Approves and boards the payment tokens to the Ark
     * @custom:effects
     * - Transfers payment tokens to the Ark
     * - Resets the paymentTokensToBoard mapping
     * @custom:security-considerations
     * - Ensure only authorized addresses can call this function
     * - Validate the Ark address and data
     * - Handle potential failures in the boarding process
     */
    function board(
        address ark,
        address rewardToken,
        bytes calldata data
    ) external;
}
