// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./DutchAuctionErrors.sol";
import "./DutchAuctionEvents.sol";

/**
 * @title Dutch Auction Library
 * @author halaprix
 * @notice This library implements core functionality for running Dutch auctions
 * @dev This library is designed to be used by a contract managing multiple auctions
 */
library DutchAuctionLibrary {
    using SafeERC20 for IERC20;

    /**
     * @notice Struct representing a single Dutch auction
     * @dev This struct contains all necessary information to run and manage an auction
     */
    struct Auction {
        IERC20 auctionToken; // The token being auctioned
        IERC20 paymentToken; // The token used for payment
        uint256 startTime; // The start time of the auction
        uint256 endTime; // The end time of the auction
        uint256 startPrice; // The starting price of the auctioned token
        uint256 endPrice; // The ending price of the auctioned token
        uint256 totalTokens; // The total number of tokens being auctioned
        uint256 remainingTokens; // The number of tokens remaining to be sold
        address auctionKicker; // The address that initiated the auction
        uint256 kickerRewardAmount; // The amount of tokens reserved as kicker reward
        address unsoldTokensRecipient; // The address to receive any unsold tokens
        bool isLinearDecay; // Whether the price decay is linear (true) or exponential (false)
        bool isFinalized; // Whether the auction has been finalized
    }

    /**
     * @notice Creates a new Dutch auction
     * @dev This function initializes a new auction with the given parameters
     * @param auctions The storage mapping of all auctions
     * @param auctionId The unique identifier for this auction
     * @param _auctionToken The address of the token being auctioned
     * @param _paymentToken The address of the token used for payment
     * @param _duration The duration of the auction in seconds
     * @param _startPrice The starting price of the auctioned token
     * @param _endPrice The ending price of the auctioned token
     * @param _totalTokens The total number of tokens being auctioned
     * @param _kickerRewardPercentage The percentage of total tokens to be given as reward to the auction kicker
     * @param _kicker The address of the auction kicker
     * @param _unsoldTokensRecipient The address to receive any unsold tokens at the end of the auction
     * @param _isLinearDecay Whether the price decay should be linear (true) or exponential (false)
     */
    function createAuction(
        mapping(uint256 => Auction) storage auctions,
        uint256 auctionId,
        IERC20 _auctionToken,
        IERC20 _paymentToken,
        uint256 _duration,
        uint256 _startPrice,
        uint256 _endPrice,
        uint256 _totalTokens,
        uint256 _kickerRewardPercentage,
        address _kicker,
        address _unsoldTokensRecipient,
        bool _isLinearDecay
    ) external {
        if (_duration == 0) revert DutchAuctionErrors.InvalidDuration();
        if (_startPrice <= _endPrice) revert DutchAuctionErrors.InvalidPrices();
        if (_totalTokens == 0) revert DutchAuctionErrors.InvalidTokenAmount();
        if (_kickerRewardPercentage >= 100)
            revert DutchAuctionErrors.InvalidKickerRewardPercentage();

        Auction storage auction = auctions[auctionId];

        uint256 kickerRewardAmount = (_totalTokens * _kickerRewardPercentage) /
            100;
        uint256 auctionedTokens = _totalTokens - kickerRewardAmount;

        {
            auction.auctionToken = _auctionToken;
            auction.paymentToken = _paymentToken;
            auction.startTime = block.timestamp;
            auction.endTime = block.timestamp + _duration;
            auction.startPrice = _startPrice;
            auction.endPrice = _endPrice;
            auction.totalTokens = auctionedTokens;
        }
        {
            auction.remainingTokens = auctionedTokens;
            auction.auctionKicker = _kicker;
            auction.kickerRewardAmount = kickerRewardAmount;
            auction.unsoldTokensRecipient = _unsoldTokensRecipient;
            auction.isLinearDecay = _isLinearDecay;
            auction.isFinalized = false;
        }
        {
            _claimKickerReward(auction);

            emit DutchAuctionEvents.AuctionCreated(
                auctionId,
                msg.sender,
                auctionedTokens,
                kickerRewardAmount
            );
        }
    }

    /**
     * @notice Calculates the current price of tokens in an ongoing auction
     * @dev This function computes the price based on the elapsed time and decay function
     * @param auction The storage pointer to the auction
     * @return The current price of tokens in the auction
     */
    function getCurrentPrice(
        Auction storage auction
    ) public view returns (uint256) {
        if (block.timestamp >= auction.endTime) {
            return auction.endPrice;
        }

        uint256 timeElapsed = block.timestamp - auction.startTime;
        uint256 totalDuration = auction.endTime - auction.startTime;
        uint256 priceDifference = auction.startPrice - auction.endPrice;

        if (auction.isLinearDecay) {
            return
                auction.startPrice -
                ((priceDifference * timeElapsed) / totalDuration);
        } else {
            // Exponential decay
            return
                auction.endPrice +
                ((priceDifference * (totalDuration - timeElapsed) ** 2) /
                    totalDuration ** 2);
        }
    }

    /**
     * @notice Allows a user to purchase tokens from an ongoing auction
     * @dev This function handles the token purchase, including price calculation and token transfers
     * @param auction The storage pointer to the auction
     * @param _amount The number of tokens to purchase
     */
    function buyTokens(Auction storage auction, uint256 _amount) external {
        if (auction.isFinalized)
            revert DutchAuctionErrors.AuctionAlreadyFinalized();
        if (block.timestamp >= auction.endTime)
            revert DutchAuctionErrors.AuctionNotActive();
        if (_amount > auction.remainingTokens)
            revert DutchAuctionErrors.InsufficientTokensAvailable();

        uint256 currentPrice = getCurrentPrice(auction);
        uint256 totalCost = currentPrice * _amount;

        auction.paymentToken.safeTransferFrom(
            msg.sender,
            address(this),
            totalCost
        );
        auction.auctionToken.safeTransfer(msg.sender, _amount);

        auction.remainingTokens -= _amount;

        emit DutchAuctionEvents.TokensPurchased(
            0,
            msg.sender,
            _amount,
            currentPrice
        );

        if (auction.remainingTokens == 0) {
            _finalizeAuction(auction);
        }
    }

    /**
     * @notice Finalizes an auction after its end time has been reached
     * @dev This function can be called by anyone after the auction end time
     * @param auction The storage pointer to the auction to be finalized
     */
    function finalizeAuction(Auction storage auction) external {
        if (auction.isFinalized)
            revert DutchAuctionErrors.AuctionAlreadyFinalized();
        if (block.timestamp < auction.endTime)
            revert DutchAuctionErrors.AuctionNotEnded();
        _finalizeAuction(auction);
    }

    /**
     * @notice Internal function to handle auction finalization logic
     * @dev This function distributes unsold tokens and marks the auction as finalized
     * @param auction The storage pointer to the auction to be finalized
     */
    function _finalizeAuction(Auction storage auction) internal {
        uint256 soldTokens = auction.totalTokens - auction.remainingTokens;

        if (auction.remainingTokens > 0) {
            auction.auctionToken.safeTransfer(
                auction.unsoldTokensRecipient,
                auction.remainingTokens
            );
        }

        auction.isFinalized = true;

        emit DutchAuctionEvents.AuctionFinalized(
            0,
            soldTokens,
            auction.remainingTokens
        );
    }

    function _claimKickerReward(Auction storage auction) internal {
        auction.auctionToken.safeTransfer(
            auction.auctionKicker,
            auction.kickerRewardAmount
        );

        emit DutchAuctionEvents.KickerRewardClaimed(
            0,
            auction.auctionKicker,
            auction.kickerRewardAmount
        );
    }
}
