// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BuyAndBurn} from "../src/contracts/BuyAndBurn.sol";
import {SummerToken} from "../src/contracts/SummerToken.sol";
import {ProtocolAccessManager} from "../src/contracts/ProtocolAccessManager.sol";
import {DecayFunctions} from "@summerfi/dutch-auction/src/DecayFunctions.sol";
import {PERCENTAGE_100, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {Test, console} from "forge-std/Test.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {AuctionDefaultParameters} from "../src/types/CommonAuctionTypes.sol";

contract BuyAndBurnDecimalsTest is Test {
    using PercentageUtils for uint256;

    BuyAndBurn public buyAndBurn;
    ProtocolAccessManager public accessManager;

    SummerToken public summerToken;
    MockERC20 public tokenToAuction6Dec;
    MockERC20 public tokenToAuction8Dec;
    MockERC20 public tokenToAuction18Dec;
    AuctionDefaultParameters newParams;

    address public governor = address(1);
    address public buyer = address(2);
    address public treasury = address(3);

    uint256 constant AUCTION_DURATION = 7 days;
    uint256 constant KICKER_REWARD_PERCENTAGE = 0;
    uint8 constant SUMMER_DECIMALS = 18;

    uint256 constant START_PRICE = 100 * 10 ** SUMMER_DECIMALS;
    uint256 constant END_PRICE = (0.1 * 10) ** SUMMER_DECIMALS;

    function setUp() public {
        accessManager = new ProtocolAccessManager(governor);

        // Create SUMMER token with 18 decimals
        summerToken = new SummerToken();

        // Create tokens to auction with different decimals
        tokenToAuction6Dec = new MockERC20();
        tokenToAuction6Dec.initialize("Auction Token 6 Dec", "AT6", 6);
        tokenToAuction8Dec = new MockERC20();
        tokenToAuction8Dec.initialize("Auction Token 8 Dec", "AT8", 8);
        tokenToAuction18Dec = new MockERC20();
        tokenToAuction18Dec.initialize("Auction Token 18 Dec", "AT18", 18);
        newParams = AuctionDefaultParameters({
            duration: uint40(AUCTION_DURATION),
            startPrice: START_PRICE,
            endPrice: END_PRICE,
            kickerRewardPercentage: PercentageUtils.fromIntegerPercentage(0),
            decayType: DecayFunctions.DecayType.Linear
        });
        buyAndBurn = new BuyAndBurn(
            address(summerToken),
            treasury,
            address(accessManager),
            newParams
        );

        // Mint tokens for auctions
        deal(
            address(tokenToAuction6Dec),
            address(buyAndBurn),
            1_000_000 * 10 ** 6
        );
        deal(
            address(tokenToAuction8Dec),
            address(buyAndBurn),
            1_000_000 * 10 ** 8
        );
        deal(
            address(tokenToAuction18Dec),
            address(buyAndBurn),
            1_000_000 * 10 ** 18
        );

        // Mint SUMMER tokens for the buyer
        deal(address(summerToken), buyer, 10_000_000 * 10 ** 18);

        vm.prank(buyer);
        summerToken.approve(address(buyAndBurn), type(uint256).max);

        vm.label(governor, "governor");
        vm.label(buyer, "buyer");
        vm.label(treasury, "treasury");
        vm.label(address(summerToken), "summerToken");
        vm.label(address(tokenToAuction6Dec), "tokenToAuction6Dec");
        vm.label(address(tokenToAuction8Dec), "tokenToAuction8Dec");
        vm.label(address(tokenToAuction18Dec), "tokenToAuction18Dec");
        vm.label(address(buyAndBurn), "buyAndBurn");
        vm.label(address(accessManager), "accessManager");
    }

    function testAuction6Dec() public {
        _runAuctionTest(tokenToAuction6Dec, 6);
    }

    function testAuction8Dec() public {
        _runAuctionTest(tokenToAuction8Dec, 8);
    }

    function testAuction18Dec() public {
        _runAuctionTest(tokenToAuction18Dec, 18);
    }

    function _runAuctionTest(
        MockERC20 tokenToAuction,
        uint8 decimals
    ) internal {
        uint256 initialSummerTokenSupply = summerToken.totalSupply();
        uint256 totalTokens = 1_000_000 * 10 ** decimals;

        vm.prank(governor);
        buyAndBurn.startAuction(address(tokenToAuction));

        // Test initial price
        uint256 currentPrice = buyAndBurn.getCurrentPrice(1);
        assertEq(currentPrice, START_PRICE, "Initial price incorrect");

        // Test price halfway through auction
        vm.warp(block.timestamp + AUCTION_DURATION / 2);
        currentPrice = buyAndBurn.getCurrentPrice(1);
        assertApproxEqAbs(
            currentPrice,
            START_PRICE / 2,
            1,
            "Mid-auction price incorrect"
        );

        // Test buying tokens
        uint256 buyAmount = 100_000 * 10 ** decimals;
        vm.prank(buyer);
        uint256 summerTokensSpent = buyAndBurn.buyTokens(1, buyAmount);

        // Verify correct amount of tokens received
        assertEq(
            tokenToAuction.balanceOf(buyer),
            buyAmount,
            "Buyer did not receive correct amount of tokens"
        );

        // Test final price
        vm.warp(block.timestamp + AUCTION_DURATION / 2);
        currentPrice = buyAndBurn.getCurrentPrice(1);
        assertEq(currentPrice, END_PRICE, "Final price incorrect");

        // Test finalization
        vm.prank(governor);
        buyAndBurn.finalizeAuction(1);

        // Verify unsold tokens sent to treasury
        uint256 kickerReward = totalTokens.applyPercentage(
            Percentage.wrap(KICKER_REWARD_PERCENTAGE)
        );
        uint256 unsoldAmount = totalTokens - buyAmount - kickerReward;
        assertEq(
            tokenToAuction.balanceOf(treasury),
            unsoldAmount,
            "Unsold tokens not sent to treasury"
        );

        // Verify SUMMER tokens burned
        uint256 expectedBurnedAmount = summerTokensSpent;
        assertEq(
            summerToken.totalSupply(),
            initialSummerTokenSupply - expectedBurnedAmount,
            "Incorrect amount of SUMMER tokens burned"
        );
    }
}
