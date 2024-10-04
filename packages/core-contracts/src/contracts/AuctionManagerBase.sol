// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {DutchAuctionLibrary} from "@summerfi/dutch-auction/src/DutchAuctionLibrary.sol";

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

    /// @notice Counter for generating unique auction IDs - starts with 1
    uint256 public nextAuctionId;

    /**
     * @notice Initializes the AuctionManagerBase with default parameters
     * @param _defaultParameters The initial default parameters for auctions
     */
    constructor(AuctionDefaultParameters memory _defaultParameters) {
        auctionDefaultParameters = _defaultParameters;
    }

    /**
     * @notice Creates a new Dutch auction
     * @dev This function is internal and should be called by derived contracts
     * @param auctionToken The token being auctioned
     * @param paymentToken The token used for payments
     * @param totalTokens The total number of tokens to be auctioned
     * @param unsoldTokensRecipient The address to receive any unsold tokens after the auction
     * @return A new Auction struct
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
     * @notice Updates the default parameters for future auctions
     * @dev This function is internal and should be called by derived contracts
     * @param newParameters The new default parameters to set
     */
    function _updateAuctionDefaultParameters(
        AuctionDefaultParameters calldata newParameters
    ) internal {
        auctionDefaultParameters = newParameters;
        emit AuctionDefaultParametersUpdated(newParameters);
    }

    /**
     * @notice Gets the current price of an ongoing auction
     * @dev This function is internal and should be called by derived contracts
     * @param auction The storage pointer to the auction
     * @return The current price of the auction in payment token decimals
     */
    function _getCurrentPrice(
        DutchAuctionLibrary.Auction storage auction
    ) internal view returns (uint256) {
        return auction.getCurrentPrice();
    }
}
