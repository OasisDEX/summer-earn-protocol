// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {DutchAuctionLibrary} from "@summerfi/dutch-auction/src/DutchAuctionLibrary.sol";
import {DecayFunctions} from "@summerfi/dutch-auction/src/DecayFunctions.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {AuctionDefaultParameters} from "../types/CommonAuctionTypes.sol";
import {IAuctionManagerBaseEvents} from "../events/IAuctionManagerBaseEvents.sol";

abstract contract AuctionManagerBase is IAuctionManagerBaseEvents {
    using SafeERC20 for IERC20;
    using DutchAuctionLibrary for DutchAuctionLibrary.Auction;

    AuctionDefaultParameters public auctionDefaultParameters;
    uint256 public nextAuctionId;

    constructor(AuctionDefaultParameters memory _defaultParameters) {
        auctionDefaultParameters = _defaultParameters;
    }

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

    function _updateAuctionDefaultParameters(
        AuctionDefaultParameters calldata newParameters
    ) internal {
        auctionDefaultParameters = newParameters;
        emit AuctionDefaultParametersUpdated(newParameters);
    }

    function _getCurrentPrice(
        DutchAuctionLibrary.Auction storage auction
    ) internal view returns (uint256) {
        return auction.getCurrentPrice();
    }
}
