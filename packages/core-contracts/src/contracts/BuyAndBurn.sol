// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IBuyAndBurnEvents} from "../events/IBuyAndBurnEvents.sol";
import {IBuyAndBurn} from "../interfaces/IBuyAndBurn.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {AuctionManagerBase, DutchAuctionLibrary, AuctionDefaultParameters} from "./AuctionManagerBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../errors/BuyAndBurnErrors.sol";

contract BuyAndBurn is IBuyAndBurn, ProtocolAccessManaged, AuctionManagerBase {
    using DutchAuctionLibrary for DutchAuctionLibrary.Auction;

    ERC20Burnable public immutable summerToken;
    address public treasury;

    mapping(uint256 => DutchAuctionLibrary.Auction) public auctions;
    mapping(address => uint256) public ongoingAuctions;
    mapping(uint256 => uint256) public auctionSummerRaised;

    constructor(
        address _summer,
        address _treasury,
        address _accessManager,
        AuctionDefaultParameters memory _defaultParameters
    )
        ProtocolAccessManaged(_accessManager)
        AuctionManagerBase(_defaultParameters)
    {
        summerToken = ERC20Burnable(_summer);
        treasury = _treasury;
    }

    function startAuction(
        address tokenToAuction
    ) external override onlyGovernor {
        if (ongoingAuctions[tokenToAuction] != 0) {
            revert BuyAndBurnAuctionAlreadyRunning(tokenToAuction);
        }

        IERC20 auctionToken = IERC20(tokenToAuction);
        uint256 totalTokens = auctionToken.balanceOf(address(this));

        DutchAuctionLibrary.Auction memory newAuction = _createAuction(
            auctionToken,
            summerToken,
            totalTokens,
            treasury
        );
        uint256 auctionId = nextAuctionId;
        auctions[auctionId] = newAuction;
        ongoingAuctions[tokenToAuction] = auctionId;
        auctionSummerRaised[auctionId] = 0;

        emit BuyAndBurnAuctionStarted(auctionId, tokenToAuction, totalTokens);
    }

    function buyTokens(
        uint256 auctionId,
        uint256 amount
    ) external override returns (uint256 summerAmount) {
        DutchAuctionLibrary.Auction storage auction = auctions[auctionId];

        summerAmount = auction.buyTokens(amount);

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

    function getAuctionInfo(
        uint256 auctionId
    ) external view override returns (DutchAuctionLibrary.Auction memory) {
        return auctions[auctionId];
    }

    function getCurrentPrice(
        uint256 auctionId
    ) external view returns (uint256) {
        return _getCurrentPrice(auctions[auctionId]);
    }

    function updateAuctionDefaultParameters(
        AuctionDefaultParameters calldata newParameters
    ) external override onlyGovernor {
        _updateAuctionDefaultParameters(newParameters);
    }

    function setTreasury(address newTreasury) external override onlyGovernor {
        treasury = newTreasury;
    }

    function _settleAuction(
        DutchAuctionLibrary.Auction memory auction
    ) internal {
        uint256 burnedSummer = auctionSummerRaised[auction.config.id];

        summerToken.burn(burnedSummer);
        emit SummerBurned(burnedSummer);

        address auctionTokenAddress = address(auction.config.auctionToken);
        ongoingAuctions[auctionTokenAddress] = 0;
        delete auctionSummerRaised[auction.config.id];
    }
}
