// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "./DecayFunctions.sol";
import "./DutchAuctionErrors.sol";
import "./DutchAuctionEvents.sol";
import "./DutchAuctionLibrary.sol";

import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Dutch Auction Manager
 * @author Your Name
 * @notice This contract manages multiple Dutch auctions using the DutchAuctionLibrary
 * @dev This contract is responsible for creating and managing auctions, and acts as the interface for users to interact
 * with auctions
 */
contract DutchAuctionManager is
    ReentrancyGuard,
    DutchAuctionErrors,
    DutchAuctionEvents
{
    using DutchAuctionLibrary for DutchAuctionLibrary.AuctionState;

    mapping(uint256 => DutchAuctionLibrary.Auction) public auctions;
    uint256 public auctionCounter;

    /**
     * @notice Creates a new Dutch auction
     * @dev This function creates a new auction and returns its unique identifier
     * @param _auctionToken The address of the token being auctioned
     * @param _paymentToken The address of the token used for payment
     * @param _duration The duration of the auction in seconds
     * @param _startPrice The starting price of the auctioned token
     * @param _endPrice The ending price of the auctioned token
     * @param _totalTokens The total number of tokens being auctioned
     * @param _kickerRewardPercentage The percentage of sold tokens to be given as reward to the auction kicker
     * @param _unsoldTokensRecipient The address to receive any unsold tokens at the end of the auction
     * @param _decayType The type of price decay function to use for the auction
     * @return auctionId The unique identifier of the created auction
     */
    function createAuction(
        IERC20 _auctionToken,
        IERC20 _paymentToken,
        uint256 _duration,
        uint256 _startPrice,
        uint256 _endPrice,
        uint256 _totalTokens,
        Percentage _kickerRewardPercentage,
        address _unsoldTokensRecipient,
        DecayFunctions.DecayType _decayType
    ) external nonReentrant returns (uint256 auctionId) {
        auctionId = auctionCounter++;
        auctions[auctionId] = DutchAuctionLibrary.createAuction(
            DutchAuctionLibrary.AuctionParams(
                auctionId,
                _auctionToken,
                _paymentToken,
                uint40(_duration),
                _startPrice,
                _endPrice,
                _totalTokens,
                _kickerRewardPercentage,
                msg.sender,
                _unsoldTokensRecipient,
                _decayType
            )
        );
    }

    /**
     * @notice Gets the current price of tokens in an ongoing auction
     * @dev This function returns the current price based on the auction's decay function and elapsed time
     * @param _auctionId The unique identifier of the auction
     * @return The current price of tokens in the auction
     */
    function getCurrentPrice(uint256 _auctionId) public view returns (uint256) {
        return DutchAuctionLibrary.getCurrentPrice(auctions[_auctionId]);
    }

    /**
     * @notice Allows a user to purchase tokens from an ongoing auction
     * @dev This function handles the token purchase, including price calculation and token transfers
     * @param _auctionId The unique identifier of the auction
     * @param _amount The number of tokens to purchase
     */
    function buyTokens(
        uint256 _auctionId,
        uint256 _amount
    ) external nonReentrant returns (uint256) {
        return DutchAuctionLibrary.buyTokens(auctions[_auctionId], _amount);
    }

    /**
     * @notice Finalizes an auction after its end time has been reached
     * @dev This function can be called by anyone after the auction end time
     * @param _auctionId The unique identifier of the auction to be finalized
     */
    function finalizeAuction(uint256 _auctionId) external nonReentrant {
        DutchAuctionLibrary.finalizeAuction(auctions[_auctionId]);
        delete auctions[_auctionId];
    }
}
