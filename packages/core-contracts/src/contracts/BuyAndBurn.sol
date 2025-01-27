// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBuyAndBurn} from "../interfaces/IBuyAndBurn.sol";
import {AuctionManagerBase, BaseAuctionParameters, DutchAuctionLibrary} from "./AuctionManagerBase.sol";
import {ConfigurationManaged} from "./ConfigurationManaged.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";

/**
 * @title BuyAndBurn
 * @notice Implements a buy-and-burn mechanism using Dutch auctions
 * @dev Inherits from IBuyAndBurn, ProtocolAccessManaged, AuctionManagerBase, and ConfigurationManaged
 */
contract BuyAndBurn is
    IBuyAndBurn,
    ProtocolAccessManaged,
    AuctionManagerBase,
    ConfigurationManaged
{
    using DutchAuctionLibrary for DutchAuctionLibrary.Auction;

    /// @notice The $SUMR token that will be burned
    ERC20Burnable public immutable summerToken;

    /// @notice Mapping of auction IDs to their respective auction data
    mapping(uint256 auctionId => DutchAuctionLibrary.Auction auction)
        public auctions;

    /// @notice Mapping of token addresses to their ongoing auction IDs (0 if no ongoing auction)
    mapping(address tokenAddress => uint256 auctionId) public ongoingAuctions;

    /// @notice Mapping of auction IDs to the amount of $SUMR tokens raised in that auction
    mapping(uint256 auctionId => uint256 amountRaised)
        public auctionSummerRaised;

    /// @notice Mapping of custom auction parameters for each token
    mapping(address tokenAddress => BaseAuctionParameters)
        public tokenAuctionParameters;

    /**
     * @notice Initializes the BuyAndBurn contract
     * @param _summer Address of the SUMMER token
     * @param _accessManager Address of the access manager
     * @param _configurationManager Address of the configuration manager
     */
    constructor(
        address _summer,
        address _accessManager,
        address _configurationManager
    )
        ProtocolAccessManaged(_accessManager)
        AuctionManagerBase()
        ConfigurationManaged(_configurationManager)
    {
        summerToken = ERC20Burnable(_summer);
    }

    /* @inheritdoc IBuyAndBurn */
    function startAuction(address tokenToAuction) external override {
        if (ongoingAuctions[tokenToAuction] != 0) {
            revert BuyAndBurnAuctionAlreadyRunning(tokenToAuction);
        }

        // Check if parameters are set by checking duration
        if (tokenAuctionParameters[tokenToAuction].duration == 0) {
            revert BuyAndBurnAuctionParametersNotSet(tokenToAuction);
        }

        IERC20 auctionToken = IERC20(tokenToAuction);
        uint256 totalTokens = auctionToken.balanceOf(address(this));

        DutchAuctionLibrary.Auction
            memory newAuction = _createAuctionWithParams(
                auctionToken,
                summerToken,
                totalTokens,
                treasury(),
                tokenAuctionParameters[tokenToAuction]
            );
        uint256 auctionId = currentAuctionId;
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
    function finalizeAuction(uint256 auctionId) external override {
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
    function setTokenAuctionParameters(
        address token,
        BaseAuctionParameters calldata parameters
    ) external onlyGovernor {
        if (parameters.duration == 0) {
            revert BuyAndBurnInvalidAuctionParameters(token);
        }
        tokenAuctionParameters[token] = parameters;
        emit TokenAuctionParametersSet(token, parameters);
    }

    /**
     * @notice Settles an auction by burning the raised SUMMER tokens and cleaning up state
     * @param auction The auction to settle
     * @dev Internal function called after an auction ends
     * @custom:effects
     * - Burns SUMMER tokens
     * - Clears ongoingAuctions mapping
     * - Deletes auctionSummerRaised entry
     * @custom:emits SummerBurned
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
