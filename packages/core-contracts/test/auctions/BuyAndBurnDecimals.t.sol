// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BuyAndBurn} from "../../src/contracts/BuyAndBurn.sol";

import {MockSummerToken} from "@summerfi/gov-contracts/test/mocks/MockSummerToken.sol";
import "./AuctionTestBase.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ISummerToken} from "@summerfi/earn-gov-contracts/interfaces/ISummerToken.sol";

contract BuyAndBurnDecimalsTest is AuctionTestBase {
    using PercentageUtils for uint256;

    BuyAndBurn public buyAndBurn;
    ISummerToken public summerToken;
    ERC20Mock public tokenToAuction6Dec;
    ERC20Mock public tokenToAuction8Dec;
    ERC20Mock public tokenToAuction18Dec;

    address public summerGovernor = address(0x9);

    uint256 constant INITIAL_SUPPLY = 1000000000;

    function setUp() public override {
        super.setUp();
        vm.label(summerGovernor, "Summer Governor");

        summerToken = new MockSummerToken("SummerToken", "SUMMER");

        buyAndBurn = new BuyAndBurn(
            address(summerToken),
            address(accessManager),
            address(configurationManager)
        );

        tokenToAuction6Dec = createMockToken("Auction Token 6 Dec", "AT6", 6);
        tokenToAuction8Dec = createMockToken("Auction Token 8 Dec", "AT8", 8);
        tokenToAuction18Dec = createMockToken(
            "Auction Token 18 Dec",
            "AT18",
            18
        );
        vm.startPrank(governor);
        buyAndBurn.setTokenAuctionParameters(
            address(tokenToAuction6Dec),
            defaultParams
        );
        buyAndBurn.setTokenAuctionParameters(
            address(tokenToAuction8Dec),
            defaultParams
        );
        buyAndBurn.setTokenAuctionParameters(
            address(tokenToAuction18Dec),
            defaultParams
        );
        vm.stopPrank();
        mintTokens(
            address(tokenToAuction6Dec),
            address(buyAndBurn),
            1000000 * 10 ** 6
        );
        mintTokens(
            address(tokenToAuction8Dec),
            address(buyAndBurn),
            1000000 * 10 ** 8
        );
        mintTokens(
            address(tokenToAuction18Dec),
            address(buyAndBurn),
            1000000 * 10 ** 18
        );
        mintTokens(address(summerToken), buyer, 10000000 * 10 ** 18);

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
        ERC20Mock tokenToAuction,
        uint8 decimals
    ) internal {
        uint256 initialSummerTokenSupply = summerToken.totalSupply();
        uint256 totalTokens = 1000000 * 10 ** decimals;

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
        uint256 buyAmount = 100000 * 10 ** decimals;
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
