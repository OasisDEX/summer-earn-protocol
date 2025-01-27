// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "./DecayFunctions.sol";
import "./DutchAuctionErrors.sol";
import "./DutchAuctionEvents.sol";
import "./lib/TokenLibrary.sol";

import "./DutchAuctionMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

/**
 * @title Dutch Auction Library
 * @author halaprix
 * @notice This library implements core functionality for running Dutch auctions
 * @dev This library is designed to be used by a contract managing multiple auctions
 *
 * @dev Auction Mechanics:
 *
 * 1. Auction Lifecycle:
 *    - Creation: An auction is created with specified parameters (tokens, duration, prices, etc.).
 *    - Active Period: The auction is active from its start time until its end time or until all tokens are sold.
 *    - Finalization: The auction is finalized either when all tokens are sold or after the end time is reached.
 *
 * 2. Price Movement:
 *    - The price is calculated on-demand based on the current timestamp using a specified decay function.
 *    - It's not updated per block, but rather computed when `getCurrentPrice` is called, using current timestamp.
 *    - This ensures smooth price decay over time, independent of block creation.
 *
 * 3. Buying Limits:
 *    - Users can buy any amount of tokens up to the remaining amount in the auction.
 *    - There's no minimum purchase amount enforced by the contract.
 *
 * 4. Price Calculation and Rounding:
 *    - The current price is calculated using the specified decay function (linear or quadratic).
 *    - Rounding is done towards zero (floor) to ensure the contract never overcharges.
 *    - For utmost precision, all calculations use the PRBMath library for fixed-point arithmetic.
 *
 * 5. Token Handling:
 *    - The auctioning contract must be pre-approved to spend the tokens used for payment.
 *    - Tokens should be transferred to the auctioning contract before or during auction creation.
 *    - The contract holds the tokens and transfers them to buyers upon successful purchases.
 *
 * 6. Kicker Reward:
 *    - A portion of the auctioned tokens is set aside as a reward for the auction initiator (kicker).
 *    - This reward is transferred to the kicker immediately upon auction creation.
 *
 * 7. Unsold Tokens:
 *    - Any unsold tokens at the end of the auction are transferred to a specified recipient address.
 *    - This transfer occurs during the finalization of the auction.
 */
library DutchAuctionLibrary {
    using SafeERC20 for IERC20;
    using PercentageUtils for uint256;
    using TokenLibrary for IERC20;

    /**
     * @notice Struct representing the configuration of a Dutch auction
     * @dev This struct contains all the fixed parameters set at auction creation
     */
    struct AuctionConfig {
        IERC20 auctionToken; // The token being auctioned
        IERC20 paymentToken; // The token used for payment
        uint40 startTime; // The start time of the auction
        uint40 endTime; // The end time of the auction
        uint8 auctionTokenDecimals; // The number of decimals for the auction token
        uint8 paymentTokenDecimals; // The number of decimals for the payment token
        address auctionKicker; // The address that initiated the auction
        address unsoldTokensRecipient; // The address to receive any unsold tokens
        uint40 id; // The unique identifier of the auction
        DecayFunctions.DecayType decayType; // The type of price decay for the auction
        uint256 startPrice; // The starting price of the auctioned token
        uint256 endPrice; // The ending price of the auctioned token
        uint256 totalTokens; // The total number of tokens being auctioned
        uint256 kickerRewardAmount; // The amount of tokens reserved as kicker reward
    }

    /**
     * @notice Struct representing the dynamic state of a Dutch auction
     * @dev This struct contains all the variables that change during the auction's lifecycle
     */
    struct AuctionState {
        uint256 remainingTokens; // The number of tokens remaining to be sold
        bool isFinalized; // Whether the auction has been finalized
    }

    /**
     * @notice Struct representing a complete Dutch auction
     * @dev This struct combines the fixed configuration and dynamic state of an auction
     */
    struct Auction {
        AuctionConfig config;
        AuctionState state;
    }

    /**
     * @notice Struct containing parameters for creating a new auction
     * @dev This struct is used as an input to the createAuction function
     */
    struct AuctionParams {
        uint256 auctionId; // The unique identifier for the new auction
        IERC20 auctionToken; // The token being auctioned
        IERC20 paymentToken; // The token used for payment
        uint40 duration; // The duration of the auction in seconds
        uint256 startPrice; // The starting price of the auctioned token
        uint256 endPrice; // The ending price of the auctioned token
        uint256 totalTokens; // The total number of tokens to be auctioned
        Percentage kickerRewardPercentage; // The percentage of tokens to be given as kicker reward
        address kicker; // The address of the auction initiator
        address unsoldTokensRecipient; // The address to receive any unsold tokens
        DecayFunctions.DecayType decayType; // The type of price decay for the auction
    }

    /**
     * @notice Creates a new Dutch auction
     * @dev This function initializes a new auction with the given parameters
     * @param params The parameters for the new auction
     * @return auction The created Auction struct
     */
    function createAuction(
        AuctionParams memory params
    ) external returns (Auction memory auction) {
        if (params.duration == 0) revert DutchAuctionErrors.InvalidDuration();
        if (params.startPrice <= params.endPrice) {
            revert DutchAuctionErrors.InvalidPrices();
        }
        if (params.totalTokens == 0) {
            revert DutchAuctionErrors.InvalidTokenAmount();
        }

        if (
            !PercentageUtils.isPercentageInRange(params.kickerRewardPercentage)
        ) {
            revert DutchAuctionErrors.InvalidKickerRewardPercentage();
        }
        if (address(params.auctionToken) == address(0)) {
            revert DutchAuctionErrors.InvalidAuctionToken();
        }
        if (address(params.paymentToken) == address(0)) {
            revert DutchAuctionErrors.InvalidPaymentToken();
        }

        uint256 kickerRewardAmount = params.totalTokens.applyPercentage(
            params.kickerRewardPercentage
        );
        uint256 auctionedTokens = params.totalTokens - kickerRewardAmount;

        // Set up AuctionConfig
        auction.config = AuctionConfig({
            id: uint40(params.auctionId),
            auctionToken: params.auctionToken,
            paymentToken: params.paymentToken,
            auctionTokenDecimals: params.auctionToken.getDecimals(),
            paymentTokenDecimals: params.paymentToken.getDecimals(),
            startTime: uint40(block.timestamp),
            endTime: uint40(block.timestamp + params.duration),
            startPrice: params.startPrice,
            endPrice: params.endPrice,
            totalTokens: auctionedTokens,
            auctionKicker: params.kicker,
            kickerRewardAmount: kickerRewardAmount,
            unsoldTokensRecipient: params.unsoldTokensRecipient,
            decayType: params.decayType
        });

        // Set up AuctionState
        auction.state = AuctionState({
            remainingTokens: auctionedTokens,
            isFinalized: false
        });

        _claimKickerReward(auction);

        emit DutchAuctionEvents.AuctionCreated(
            params.auctionId,
            msg.sender,
            auctionedTokens,
            kickerRewardAmount
        );
    }

    /**
     * @notice Calculates the current price of tokens in an ongoing auction
     * @dev This function computes the price based on the elapsed time and decay function
     * @param auction The Auction struct
     * @return The current price of tokens in the auction
     */
    function getCurrentPrice(
        Auction memory auction
    ) public view returns (uint256) {
        uint256 timeElapsed = block.timestamp - auction.config.startTime;
        uint256 totalDuration = auction.config.endTime -
            auction.config.startTime;

        return
            DecayFunctions.calculateDecay(
                auction.config.decayType,
                auction.config.startPrice,
                auction.config.endPrice,
                timeElapsed,
                totalDuration,
                auction.config.paymentTokenDecimals,
                auction.config.paymentTokenDecimals
            );
    }

    /**
     * @notice Allows a user to purchase tokens from an ongoing auction
     * @dev This function handles the token purchase, including price calculation and token transfers
     * @param auction The storage pointer to the auction
     * @param _amount The number of tokens to purchase
     */
    function buyTokens(
        Auction storage auction,
        uint256 _amount
    ) internal returns (uint256 totalCost) {
        if (auction.config.auctionToken == IERC20(address(0))) {
            revert DutchAuctionErrors.AuctionNotFound();
        }
        if (auction.state.isFinalized) {
            revert DutchAuctionErrors.AuctionAlreadyFinalized(
                auction.config.id
            );
        }
        if (block.timestamp >= auction.config.endTime) {
            revert DutchAuctionErrors.AuctionNotActive(auction.config.id);
        }
        if (_amount > auction.state.remainingTokens) {
            revert DutchAuctionErrors.InsufficientTokensAvailable();
        }

        uint256 currentPrice = getCurrentPrice(auction);

        totalCost = DutchAuctionMath.calculateTotalCost(
            currentPrice,
            _amount,
            auction.config.paymentTokenDecimals,
            auction.config.auctionTokenDecimals,
            auction.config.paymentTokenDecimals
        );

        auction.state.remainingTokens -= _amount;

        auction.config.paymentToken.safeTransferFrom(
            msg.sender,
            address(this),
            totalCost
        );
        auction.config.auctionToken.safeTransfer(msg.sender, _amount);

        emit DutchAuctionEvents.TokensPurchased(
            auction.config.id,
            msg.sender,
            _amount,
            currentPrice
        );

        if (auction.state.remainingTokens == 0) {
            _finalizeAuction(auction);
        }
    }

    /**
     * @notice Finalizes an auction after its end time has been reached
     * @dev This function can be called by anyone after the auction end time
     * @param auction The storage pointer to the auction to be finalized
     */
    function finalizeAuction(Auction storage auction) internal {
        if (auction.config.auctionToken == IERC20(address(0))) {
            revert DutchAuctionErrors.AuctionNotFound();
        }
        if (auction.state.isFinalized) {
            revert DutchAuctionErrors.AuctionAlreadyFinalized(
                auction.config.id
            );
        }
        if (block.timestamp < auction.config.endTime) {
            revert DutchAuctionErrors.AuctionNotEnded(auction.config.id);
        }
        _finalizeAuction(auction);
    }

    /**
     * @notice Internal function to handle auction finalization logic
     * @dev This function distributes unsold tokens and marks the auction as finalized
     * @param auction The storage pointer to the auction to be finalized
     */
    function _finalizeAuction(Auction storage auction) internal {
        uint256 soldTokens = auction.config.totalTokens -
            auction.state.remainingTokens;

        auction.state.isFinalized = true;

        if (auction.state.remainingTokens > 0) {
            auction.config.auctionToken.safeTransfer(
                auction.config.unsoldTokensRecipient,
                auction.state.remainingTokens
            );
        }

        emit DutchAuctionEvents.AuctionFinalized(
            auction.config.id,
            soldTokens,
            auction.state.remainingTokens
        );
    }

    /**
     * @notice Claims the kicker reward for the auction
     * @dev Transfers the kicker reward to the kicker's address immediately upon auction creation
     * @param auction The auction to claim the kicker reward from
     */
    function _claimKickerReward(Auction memory auction) internal {
        if (auction.config.kickerRewardAmount == 0) {
            return;
        }
        auction.config.auctionToken.safeTransfer(
            auction.config.auctionKicker,
            auction.config.kickerRewardAmount
        );

        emit DutchAuctionEvents.KickerRewardClaimed(
            auction.config.id,
            auction.config.auctionKicker,
            auction.config.kickerRewardAmount
        );
    }
}
