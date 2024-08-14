// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./AuctionTestBase.sol";
import {BuyAndBurn} from "../../src/contracts/BuyAndBurn.sol";
import {SummerToken} from "../../src/contracts/SummerToken.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";

contract BuyAndBurnDecimalsTest is AuctionTestBase {
    using PercentageUtils for uint256;
    BuyAndBurn public buyAndBurn;
    SummerToken public summerToken;
    MockERC20 public tokenToAuction6Dec;
    MockERC20 public tokenToAuction8Dec;
    MockERC20 public tokenToAuction18Dec;

    function setUp() public override {
        super.setUp();

        summerToken = new SummerToken();
        buyAndBurn = new BuyAndBurn(
            address(summerToken),
            treasury,
            address(accessManager),
            defaultParams
        );

        tokenToAuction6Dec = createMockToken("Auction Token 6 Dec", "AT6", 6);
        tokenToAuction8Dec = createMockToken("Auction Token 8 Dec", "AT8", 8);
        tokenToAuction18Dec = createMockToken(
            "Auction Token 18 Dec",
            "AT18",
            18
        );

        mintTokens(
            address(tokenToAuction6Dec),
            address(buyAndBurn),
            1_000_000 * 10 ** 6
        );
        mintTokens(
            address(tokenToAuction8Dec),
            address(buyAndBurn),
            1_000_000 * 10 ** 8
        );
        mintTokens(
            address(tokenToAuction18Dec),
            address(buyAndBurn),
            1_000_000 * 10 ** 18
        );
        mintTokens(address(summerToken), buyer, 10_000_000 * 10 ** 18);

        vm.prank(buyer);
        summerToken.approve(address(buyAndBurn), type(uint256).max);

        vm.label(address(summerToken), "summerToken");
        vm.label(address(tokenToAuction6Dec), "tokenToAuction6Dec");
        vm.label(address(tokenToAuction8Dec), "tokenToAuction8Dec");
        vm.label(address(tokenToAuction18Dec), "tokenToAuction18Dec");
        vm.label(address(buyAndBurn), "buyAndBurn");
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
