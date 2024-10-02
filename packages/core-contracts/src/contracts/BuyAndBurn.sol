// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IBuyAndBurn} from "../interfaces/IBuyAndBurn.sol";

import {IConfigurationManager} from "../interfaces/IConfigurationManager.sol";
import {AuctionDefaultParameters, AuctionManagerBase, DutchAuctionLibrary} from "./AuctionManagerBase.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title BuyAndBurn
 * @notice This contract manages auctions for tokens, accepting SUMMER tokens as payment and burning them.
 * @dev Inherits from IBuyAndBurn, ProtocolAccessManaged, and AuctionManagerBase to handle auctions and access control.
 */
contract BuyAndBurn is IBuyAndBurn, ProtocolAccessManaged, AuctionManagerBase {
    using DutchAuctionLibrary for DutchAuctionLibrary.Auction;

    ERC20Burnable public immutable summerToken;
    IConfigurationManager public manager;

    /// @notice Mapping of auction IDs to their respective auction data
    mapping(uint256 auctionId => DutchAuctionLibrary.Auction auction)
        public auctions;

    /// @notice Mapping of token addresses to their ongoing auction IDs (0 if no ongoing auction)
    mapping(address tokenAddress => uint256 auctionId) public ongoingAuctions;

    /// @notice Mapping of auction IDs to the amount of SUMMER tokens raised in that auction
    mapping(uint256 auctionId => uint256 amountRaised)
        public auctionSummerRaised;

    constructor(
        address _summer,
        address _accessManager,
        address _configurationManager,
        AuctionDefaultParameters memory _defaultParameters
    )
        ProtocolAccessManaged(_accessManager)
        AuctionManagerBase(_defaultParameters)
    {
        summerToken = ERC20Burnable(_summer);
        manager = IConfigurationManager(_configurationManager);
    }

    /* @inheritdoc IBuyAndBurn */
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
            manager.treasury()
        );
        uint256 auctionId = nextAuctionId;
        auctions[auctionId] = newAuction;
        ongoingAuctions[tokenToAuction] = auctionId;
        auctionSummerRaised[auctionId] = 0;

        emit BuyAndBurnAuctionStarted(auctionId, tokenToAuction, totalTokens);
    }

    /* @inheritdoc IBuyAndBurn */
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

    /* @inheritdoc IBuyAndBurn */
    function finalizeAuction(uint256 auctionId) external override onlyGovernor {
        DutchAuctionLibrary.Auction storage auction = auctions[auctionId];
        auction.finalizeAuction();
        _settleAuction(auction);
    }
    /* @inheritdoc IBuyAndBurn */

    function getAuctionInfo(
        uint256 auctionId
    ) external view override returns (DutchAuctionLibrary.Auction memory) {
        return auctions[auctionId];
    }
    /* @inheritdoc IBuyAndBurn */

    function getCurrentPrice(
        uint256 auctionId
    ) external view returns (uint256) {
        return _getCurrentPrice(auctions[auctionId]);
    }
    /* @inheritdoc IBuyAndBurn */

    function updateAuctionDefaultParameters(
        AuctionDefaultParameters calldata newParameters
    ) external override onlyGovernor {
        _updateAuctionDefaultParameters(newParameters);
    }

    /**
     * @notice Settles an auction by burning the raised SUMMER tokens and cleaning up state
     * @param auction The auction to settle
     */
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
