// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@summerfi/dutch-auction/src/DutchAuctionLibrary.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {PercentageUtils} from "@summerfi/dutch-auction/src/lib/PercentageUtils.sol";
import {ICommonAuctionEvents} from "../events/ICommonAuctionEvents.sol";

import {AuctionDefaultParameters} from "../types/CommonAuctionTypes.sol";
import "../errors/CommonAuctionErrors.sol";

contract BuyAndBurn is ProtocolAccessManaged, ICommonAuctionEvents {
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
            kickerRewardPercentage: PercentageUtils.fromDecimalPercentage(0),
            decayType: DecayFunctions.DecayType.Linear
        });
    }

    function startAuction(address tokenToAuction) external onlyGovernor {
        if (ongoingAuctions[tokenToAuction] != 0) {
            revert AuctionAlreadyRunning(tokenToAuction);
        }

        IERC20 auctionToken = IERC20(tokenToAuction);
        uint256 balance = auctionToken.balanceOf(address(this));
        if (balance == 0) {
            revert NoTokensToAuction();
        }

        uint256 auctionId = nextAuctionId++;
        DutchAuctionLibrary.AuctionParams memory params = DutchAuctionLibrary
            .AuctionParams({
                auctionId: auctionId,
                auctionToken: auctionToken,
                paymentToken: SUMMER,
                duration: auctionDefaultParameters.duration,
                startPrice: auctionDefaultParameters.startPrice,
                endPrice: auctionDefaultParameters.endPrice,
                totalTokens: balance,
                kickerRewardPercentage: auctionDefaultParameters
                    .kickerRewardPercentage,
                kicker: address(this),
                unsoldTokensRecipient: treasury,
                decayType: auctionDefaultParameters.decayType
            });

        auctions[auctionId] = DutchAuctionLibrary.createAuction(params);
        ongoingAuctions[tokenToAuction] = auctionId;
        auctionSummerRaised[auctionId] = 0;

        emit AuctionStarted(auctionId, tokenToAuction, balance);
    }

    function buyTokens(uint256 auctionId, uint256 amount) external {
        DutchAuctionLibrary.Auction storage auction = auctions[auctionId];
        if (auction.config.auctionToken == IERC20(address(0))) {
            revert AuctionNotFound(auctionId);
        }

        uint256 summerAmount = DutchAuctionMath.calculateTotalCost(
            auction.getCurrentPrice(),
            amount
        );

        SUMMER.safeTransferFrom(msg.sender, address(this), summerAmount);
        auction.buyTokens(amount);

        auctionSummerRaised[auctionId] += summerAmount;

        emit TokensPurchased(auctionId, msg.sender, amount, summerAmount);
    }

    function finalizeAuction(uint256 auctionId) external onlyGovernor {
        DutchAuctionLibrary.Auction storage auction = auctions[auctionId];
        if (auction.config.auctionToken == IERC20(address(0))) {
            revert AuctionNotFound(auctionId);
        }
        if (block.timestamp < auction.config.endTime) {
            revert AuctionNotEnded(auctionId);
        }

        auction.finalizeAuction();

        uint256 soldTokens = auction.config.totalTokens -
            auction.state.remainingTokens;
        uint256 burnedSummer = auctionSummerRaised[auctionId];
        SUMMER.burn(burnedSummer);

        address auctionTokenAddress = address(auction.config.auctionToken);
        ongoingAuctions[auctionTokenAddress] = 0;
        delete auctionSummerRaised[auctionId];

        emit AuctionFinalized(
            auctionId,
            soldTokens,
            burnedSummer,
            auction.state.remainingTokens
        );
    }

    function getAuctionInfo(
        uint256 auctionId
    )
        external
        view
        returns (
            address auctionToken,
            uint256 startTime,
            uint256 endTime,
            uint256 currentPrice,
            uint256 remainingTokens,
            bool isFinalized,
            uint256 summerRaised
        )
    {
        DutchAuctionLibrary.Auction storage auction = auctions[auctionId];
        return (
            address(auction.config.auctionToken),
            auction.config.startTime,
            auction.config.endTime,
            auction.getCurrentPrice(),
            auction.state.remainingTokens,
            auction.state.isFinalized,
            auctionSummerRaised[auctionId]
        );
    }

    function updateAuctionDefaultParameters(
        AuctionDefaultParameters calldata newParameters
    ) external onlyGovernor {
        auctionDefaultParameters = newParameters;
        emit AuctionDefaultParametersUpdated(newParameters);
    }

    function setTreasury(address newTreasury) external onlyGovernor {
        treasury = newTreasury;
    }
}
