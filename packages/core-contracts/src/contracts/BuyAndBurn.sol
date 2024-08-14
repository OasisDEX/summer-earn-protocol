// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IBuyAndBurnEvents} from "../events/IBuyAndBurnEvents.sol";
import {IBuyAndBurn} from "../interfaces/IBuyAndBurn.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@summerfi/dutch-auction/src/DutchAuctionLibrary.sol";

import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

import "../errors/BuyAndBurnErrors.sol";
import {AuctionDefaultParameters} from "../types/CommonAuctionTypes.sol";

contract BuyAndBurn is IBuyAndBurn, ProtocolAccessManaged {
    using SafeERC20 for ERC20Burnable;
    using DutchAuctionLibrary for DutchAuctionLibrary.Auction;

    ERC20Burnable public immutable SUMMER;
    address public treasury;
    uint256 public nextAuctionId;

    mapping(uint256 => DutchAuctionLibrary.Auction) public auctions;
    mapping(address => uint256) public ongoingAuctions;
    mapping(uint256 => uint256) public auctionSummerRaised;

    AuctionDefaultParameters public auctionDefaultParameters;

    constructor(
        address _summer,
        address _treasury,
        address _accessManager
    ) ProtocolAccessManaged(_accessManager) {
        SUMMER = ERC20Burnable(_summer);
        treasury = _treasury;
        auctionDefaultParameters = AuctionDefaultParameters({
            duration: 7 days,
            startPrice: 1e18,
            endPrice: 1e17,
            kickerRewardPercentage: PercentageUtils.fromIntegerPercentage(0),
            decayType: DecayFunctions.DecayType.Linear
        });
    }

    function startAuction(
        address tokenToAuction
    ) external override onlyGovernor {
        if (ongoingAuctions[tokenToAuction] != 0) {
            revert BuyAndBurnAuctionAlreadyRunning(tokenToAuction);
        }

        IERC20 auctionToken = IERC20(tokenToAuction);
        uint256 totalTokens = auctionToken.balanceOf(address(this));

        uint256 auctionId = ++nextAuctionId;
        DutchAuctionLibrary.AuctionParams memory params = DutchAuctionLibrary
            .AuctionParams({
                auctionId: auctionId,
                auctionToken: auctionToken,
                paymentToken: SUMMER,
                duration: auctionDefaultParameters.duration,
                startPrice: auctionDefaultParameters.startPrice,
                endPrice: auctionDefaultParameters.endPrice,
                totalTokens: totalTokens,
                kickerRewardPercentage: auctionDefaultParameters
                    .kickerRewardPercentage,
                kicker: address(this),
                unsoldTokensRecipient: treasury,
                decayType: auctionDefaultParameters.decayType
            });

        auctions[auctionId] = DutchAuctionLibrary.createAuction(params);
        ongoingAuctions[tokenToAuction] = auctionId;
        auctionSummerRaised[auctionId] = 0;

        emit BuyAndBurnAuctionStarted(auctionId, tokenToAuction, totalTokens);
    }

    function buyTokens(uint256 auctionId, uint256 amount) external override {
        DutchAuctionLibrary.Auction storage auction = auctions[auctionId];

        uint256 summerAmount = auction.buyTokens(amount);

        auctionSummerRaised[auctionId] += summerAmount;

        if (auction.state.remainingTokens == 0) {
            _settleAuction(auction);
        }
    }

    function finalizeAuction(uint256 auctionId) external override onlyGovernor {
        DutchAuctionLibrary.Auction storage auction = auctions[auctionId];
        auction.finalizeAuction();
        _settleAuction(auction);
    }

    function _settleAuction(
        DutchAuctionLibrary.Auction memory auction
    ) internal {
        uint256 burnedSummer = auctionSummerRaised[auction.config.id];

        SUMMER.burn(burnedSummer);
        emit SummerBurned(burnedSummer);

        address auctionTokenAddress = address(auction.config.auctionToken);
        ongoingAuctions[auctionTokenAddress] = 0;
        delete auctionSummerRaised[auction.config.id];
    }

    function getAuctionInfo(
        uint256 auctionId
    )
        external
        view
        override
        returns (DutchAuctionLibrary.Auction memory auction)
    {
        auction = auctions[auctionId];
    }

    function getCurrentPrice(
        uint256 auctionId
    ) external view override returns (uint256) {
        return auctions[auctionId].getCurrentPrice();
    }

    function updateAuctionDefaultParameters(
        AuctionDefaultParameters calldata newParameters
    ) external override onlyGovernor {
        auctionDefaultParameters = newParameters;
        emit AuctionDefaultParametersUpdated(newParameters);
    }

    function setTreasury(address newTreasury) external override onlyGovernor {
        treasury = newTreasury;
    }
}
