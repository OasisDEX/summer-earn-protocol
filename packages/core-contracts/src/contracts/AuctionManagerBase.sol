// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {DutchAuctionLibrary} from "@summerfi/dutch-auction/DutchAuctionLibrary.sol";

import {IAuctionManagerBaseEvents} from "../events/IAuctionManagerBaseEvents.sol";
import {AuctionDefaultParameters} from "../types/CommonAuctionTypes.sol";

/**
 * @title AuctionManagerBase
 * @notice Base contract for managing Dutch auctions
 * @dev This abstract contract provides core functionality for creating and managing Dutch auctions
 */
abstract contract AuctionManagerBase is IAuctionManagerBaseEvents {
    using SafeERC20 for IERC20;
    using DutchAuctionLibrary for DutchAuctionLibrary.Auction;

    /// @notice Default parameters for all auctions
    AuctionDefaultParameters public auctionDefaultParameters;

    /// @notice Counter for generating unique auction IDs
    /// @dev Initialized to 0. The first auction will have ID 1 due to pre-increment in _createAuction
    uint256 public nextAuctionId;

    /**
     * @notice Initializes the AuctionManagerBase with default parameters
     * @param _defaultParameters The initial default parameters for auctions
     */
    constructor(AuctionDefaultParameters memory _defaultParameters) {
        auctionDefaultParameters = _defaultParameters;
        // nextAuctionId is implicitly initialized to 0
    }

    /**
     * @dev Creates a new Dutch auction
     * @param auctionToken The token being auctioned
     * @param paymentToken The token used for payments
     * @param totalTokens The total number of tokens to be auctioned
     * @param unsoldTokensRecipient The address to receive any unsold tokens after the auction
     * @return A new Auction struct
     * @custom:internal-logic
     * - Pre-increments nextAuctionId to generate a unique ID (first auction will have ID 1)
     * - Creates an AuctionParams struct using default parameters and provided inputs
     * - Calls the createAuction function of the DutchAuctionLibrary to initialize the auction
     * @custom:effects
     * - Increments nextAuctionId
     * - Creates and returns a new Auction struct
     * @custom:security-considerations
     * - Ensure that the provided token addresses are valid
     * - Verify that totalTokens is non-zero and matches the actual token balance
     */
    function _createAuction(
        IERC20 auctionToken,
        IERC20 paymentToken,
        uint256 totalTokens,
        address unsoldTokensRecipient
    ) internal returns (DutchAuctionLibrary.Auction memory) {
        DutchAuctionLibrary.AuctionParams memory params = DutchAuctionLibrary
            .AuctionParams({
                auctionId: ++nextAuctionId,
                auctionToken: auctionToken,
                paymentToken: paymentToken,
                duration: auctionDefaultParameters.duration,
                startPrice: auctionDefaultParameters.startPrice,
                endPrice: auctionDefaultParameters.endPrice,
                totalTokens: totalTokens,
                kickerRewardPercentage: auctionDefaultParameters
                    .kickerRewardPercentage,
                kicker: msg.sender,
                unsoldTokensRecipient: unsoldTokensRecipient,
                decayType: auctionDefaultParameters.decayType
            });

        return DutchAuctionLibrary.createAuction(params);
    }

    /**
     * @dev Updates the default parameters for future auctions
     * @param newParameters The new default parameters to set
     * @custom:internal-logic
     * - Replaces the current auctionDefaultParameters with newParameters
     * @custom:effects
     * - Updates auctionDefaultParameters
     * - Emits an AuctionDefaultParametersUpdated event
     * @custom:security-considerations
     * - Validate the new parameters to ensure they are within acceptable ranges
     * - Consider the impact on future auctions (e.g., duration, price ranges)
     * - Implement proper access control to restrict who can call this function
     */
    function _updateAuctionDefaultParameters(
        AuctionDefaultParameters calldata newParameters
    ) internal {
        auctionDefaultParameters = newParameters;
        emit AuctionDefaultParametersUpdated(newParameters);
    }

    /**
     * @dev Gets the current price of an ongoing auction
     * @param auction The storage pointer to the auction
     * @return The current price of the auction in payment token decimals
     * @custom:internal-logic
     * - Calls the getCurrentPrice function of the DutchAuctionLibrary
     * @custom:effects
     * - Does not modify any state, view function only
     * @custom:security-considerations
     * - Ensure that the auction is ongoing when calling this function
     */
    function _getCurrentPrice(
        DutchAuctionLibrary.Auction storage auction
    ) internal view returns (uint256) {
        return auction.getCurrentPrice();
    }
}
