// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BuyAndBurn} from "../../src/contracts/BuyAndBurn.sol";

import "../../src/errors/IBuyAndBurnErrors.sol";
import "@summerfi/access-contracts/interfaces/IAccessControlErrors.sol";

import {IAuctionManagerBaseEvents} from "../../src/events/IAuctionManagerBaseEvents.sol";
import {IBuyAndBurnEvents} from "../../src/events/IBuyAndBurnEvents.sol";
import {MockSummerToken} from "@summerfi/gov-contracts/test/mocks/MockSummerToken.sol";
import "./AuctionTestBase.sol";
import {ISummerToken} from "@summerfi/earn-gov-contracts/interfaces/ISummerToken.sol";

import {DutchAuctionErrors} from "@summerfi/dutch-auction/DutchAuctionErrors.sol";
import {DutchAuctionEvents} from "@summerfi/dutch-auction/DutchAuctionEvents.sol";
import {DutchAuctionLibrary} from "@summerfi/dutch-auction/DutchAuctionLibrary.sol";

contract BuyAndBurnTest is AuctionTestBase, IBuyAndBurnEvents {
    BuyAndBurn public buyAndBurn;
    ISummerToken public summerToken;
    ERC20Mock public tokenToAuction1;
    ERC20Mock public tokenToAuction2;

    address public summerGovernor = address(0x9);

    uint256 constant AUCTION_AMOUNT = 100000000;
    uint256 constant INITIAL_SUPPLY = 1000000;

    function setUp() public override {
        super.setUp();

        defaultParams.kickerRewardPercentage = Percentage.wrap(
            KICKER_REWARD_PERCENTAGE
        );

        summerToken = new MockSummerToken("SummerToken", "SUMMER");
        buyAndBurn = new BuyAndBurn(
            address(summerToken),
            address(accessManager),
            address(configurationManager)
        );

        tokenToAuction1 = createMockToken("Token1", "TKN1", 18);
        tokenToAuction2 = createMockToken("Token2", "TKN2", 18);

        vm.startPrank(governor);
        buyAndBurn.setTokenAuctionParameters(
            address(tokenToAuction1),
            defaultParams
        );
        buyAndBurn.setTokenAuctionParameters(
            address(tokenToAuction2),
            defaultParams
        );
        vm.stopPrank();

        mintTokens(
            address(tokenToAuction1),
            address(buyAndBurn),
            AUCTION_AMOUNT
        );
        mintTokens(
            address(tokenToAuction2),
            address(buyAndBurn),
            AUCTION_AMOUNT
        );
        mintTokens(address(summerToken), buyer, 10000 ether);

        vm.label(address(summerToken), "summerToken");
        vm.label(address(tokenToAuction1), "tokenToAuction1");
        vm.label(address(tokenToAuction2), "tokenToAuction2");
        vm.label(address(buyAndBurn), "buyAndBurn");
    }

    function test_Constructor() public {
        BuyAndBurn newBuyAndBurn = new BuyAndBurn(
            address(summerToken),
            address(accessManager),
            address(configurationManager)
        );
        vm.startPrank(governor);
        newBuyAndBurn.setTokenAuctionParameters(
            address(tokenToAuction1),
            defaultParams
        );
        vm.stopPrank();
        (
            uint40 duration,
            uint256 startPrice,
            uint256 endPrice,
            Percentage kickerRewardPercentage,
            DecayFunctions.DecayType decayType
        ) = newBuyAndBurn.tokenAuctionParameters(address(tokenToAuction1));
        assertEq(duration, AUCTION_DURATION);
        assertEq(startPrice, START_PRICE);
        assertEq(endPrice, END_PRICE);
        assertEq(
            Percentage.unwrap(kickerRewardPercentage),
            KICKER_REWARD_PERCENTAGE
        );
        assertEq(uint256(decayType), uint256(DecayFunctions.DecayType.Linear));
    }

    function test_StartAuction() public {
        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit BuyAndBurnAuctionStarted(
            1,
            address(tokenToAuction1),
            AUCTION_AMOUNT
        );

        buyAndBurn.startAuction(address(tokenToAuction1));

        (
            DutchAuctionLibrary.AuctionConfig memory config,
            DutchAuctionLibrary.AuctionState memory state
        ) = buyAndBurn.auctions(1);
        assertEq(address(config.auctionToken), address(tokenToAuction1));
        assertEq(state.remainingTokens, AUCTION_AMOUNT);
    }

    function test_CannotStartDuplicateAuction() public {
        vm.startPrank(governor);
        buyAndBurn.startAuction(address(tokenToAuction1));

        vm.expectRevert(
            abi.encodeWithSignature(
                "BuyAndBurnAuctionAlreadyRunning(address)",
                address(tokenToAuction1)
            )
        );
        buyAndBurn.startAuction(address(tokenToAuction1));
        vm.stopPrank();
    }

    function test_BuyTokens() public {
        vm.prank(governor);
        buyAndBurn.startAuction(address(tokenToAuction1));

        uint256 buyAmount = 50000000;
        uint256 price = buyAndBurn.getCurrentPrice(1);
        vm.startPrank(buyer);
        summerToken.approve(address(buyAndBurn), 10000 ether);
        vm.expectEmit(true, true, true, true);
        emit DutchAuctionEvents.TokensPurchased(1, buyer, buyAmount, price);
        buyAndBurn.buyTokens(1, buyAmount);
        vm.stopPrank();

        (, DutchAuctionLibrary.AuctionState memory state) = buyAndBurn.auctions(
            1
        );
        assertEq(state.remainingTokens, AUCTION_AMOUNT - buyAmount);
    }

    function test_FinalizeAuction() public {
        vm.prank(governor);
        buyAndBurn.startAuction(address(tokenToAuction1));

        uint256 buyAmount = 50000000;
        vm.startPrank(buyer);
        summerToken.approve(address(buyAndBurn), 10000 ether);
        uint256 summerSpent = buyAndBurn.buyTokens(1, buyAmount);
        vm.stopPrank();

        vm.warp(block.timestamp + 8 days);

        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit SummerBurned(summerSpent);
        buyAndBurn.finalizeAuction(1);

        (, DutchAuctionLibrary.AuctionState memory state) = buyAndBurn.auctions(
            1
        );
        assertTrue(state.isFinalized);
        assertEq(
            summerToken.balanceOf(address(buyAndBurn)),
            0,
            "All summerToken tokens should be burned"
        );
        assertEq(
            tokenToAuction1.balanceOf(treasury),
            AUCTION_AMOUNT - buyAmount,
            "Unsold tokens should be in treasury"
        );
    }

    function test_CannotFinalizeAuctionBeforeEndTime() public {
        vm.prank(governor);
        buyAndBurn.startAuction(address(tokenToAuction1));

        vm.expectRevert(
            abi.encodeWithSelector(
                DutchAuctionErrors.AuctionNotEnded.selector,
                1
            )
        );
        vm.prank(governor);
        buyAndBurn.finalizeAuction(1);
    }

    function test_UpdateAuctionDefaultParameters() public {
        defaultParams = BaseAuctionParameters({
            duration: 5 days,
            startPrice: 2e18,
            endPrice: 5e17,
            kickerRewardPercentage: PercentageUtils.fromIntegerPercentage(5),
            decayType: DecayFunctions.DecayType.Quadratic
        });

        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit IBuyAndBurnEvents.TokenAuctionParametersSet(
            address(tokenToAuction1),
            defaultParams
        );
        buyAndBurn.setTokenAuctionParameters(
            address(tokenToAuction1),
            defaultParams
        );

        (
            uint40 duration,
            uint256 startPrice,
            uint256 endPrice,
            Percentage kickerRewardPercentage,
            DecayFunctions.DecayType decayType
        ) = buyAndBurn.tokenAuctionParameters(address(tokenToAuction1));
        assertEq(duration, defaultParams.duration);
        assertEq(startPrice, defaultParams.startPrice);
        assertEq(endPrice, defaultParams.endPrice);
        assertEq(
            Percentage.unwrap(kickerRewardPercentage),
            Percentage.unwrap(defaultParams.kickerRewardPercentage)
        );
        assertEq(uint256(decayType), uint256(defaultParams.decayType));
    }

    function test_MultipleAuctionsCycle() public {
        // First auction cycle
        vm.prank(governor);
        buyAndBurn.startAuction(address(tokenToAuction1));

        uint256 firstAuctionBuyAmount = AUCTION_AMOUNT / 2;
        vm.startPrank(buyer);
        summerToken.approve(address(buyAndBurn), 10000 ether);
        buyAndBurn.buyTokens(1, firstAuctionBuyAmount);
        vm.stopPrank();

        vm.warp(block.timestamp + 8 days);
        vm.prank(governor);
        buyAndBurn.finalizeAuction(1);

        // Verify first auction results
        assertEq(
            summerToken.balanceOf(address(buyAndBurn)),
            0,
            "All summerToken tokens should be burned"
        );
        assertEq(
            tokenToAuction1.balanceOf(treasury),
            AUCTION_AMOUNT - firstAuctionBuyAmount,
            "Unsold tokens should be in treasury"
        );

        // Second auction cycle

        vm.prank(governor);
        buyAndBurn.startAuction(address(tokenToAuction2));

        uint256 secondAuctionBuyAmount = (AUCTION_AMOUNT * 3) / 4;

        vm.startPrank(buyer);
        summerToken.approve(address(buyAndBurn), 10000 ether);
        buyAndBurn.buyTokens(2, secondAuctionBuyAmount);
        vm.stopPrank();

        vm.warp(block.timestamp + 8 days);
        vm.prank(governor);
        buyAndBurn.finalizeAuction(2);

        // Verify second auction results
        assertEq(
            summerToken.balanceOf(address(buyAndBurn)),
            0,
            "All summerToken tokens should be burned"
        );
        assertEq(
            tokenToAuction2.balanceOf(treasury),
            AUCTION_AMOUNT - secondAuctionBuyAmount,
            "Unsold tokens should be in treasury"
        );
    }

    function test_BuyAllTokensAndAutoSettle() public {
        // Start the auction
        vm.prank(governor);
        buyAndBurn.startAuction(address(tokenToAuction1));

        // Get the current price
        uint256 currentPrice = buyAndBurn.getCurrentPrice(1);

        // Calculate the total cost to buy all tokens
        uint256 totalCost = (currentPrice * AUCTION_AMOUNT) / 1e18;

        // Approve and buy all tokens
        vm.startPrank(buyer);
        summerToken.approve(address(buyAndBurn), totalCost);

        // Expect the SummerBurned event to be emitted
        vm.expectEmit(true, true, true, true);
        emit SummerBurned(totalCost);

        // Buy all tokens
        buyAndBurn.buyTokens(1, AUCTION_AMOUNT);
        vm.stopPrank();

        // Check that the auction is finalized
        (, DutchAuctionLibrary.AuctionState memory state) = buyAndBurn.auctions(
            1
        );
        assertTrue(state.isFinalized, "Auction should be finalized");
        assertEq(state.remainingTokens, 0, "All tokens should be sold");

        // Check that SUMMER tokens were burned
        assertEq(
            summerToken.balanceOf(address(buyAndBurn)),
            0,
            "All SUMMER tokens should be burned"
        );

        // Check that auctioned tokens were transferred to the buyer
        assertEq(
            tokenToAuction1.balanceOf(buyer),
            AUCTION_AMOUNT,
            "All auctioned tokens should be transferred to the buyer"
        );

        // Check that the auction is removed from ongoingAuctions
        assertEq(
            buyAndBurn.ongoingAuctions(address(tokenToAuction1)),
            0,
            "Auction should be removed from ongoingAuctions"
        );

        // Check that auctionSummerRaised is reset
        assertEq(
            buyAndBurn.auctionSummerRaised(1),
            0,
            "auctionSummerRaised should be reset"
        );
    }

    function test_GetAuctionInfo() public {
        vm.prank(governor);
        buyAndBurn.startAuction(address(tokenToAuction1));

        DutchAuctionLibrary.Auction memory auctionInfo = buyAndBurn
            .getAuctionInfo(1);
        assertEq(
            address(auctionInfo.config.auctionToken),
            address(tokenToAuction1)
        );
        assertEq(auctionInfo.config.totalTokens, AUCTION_AMOUNT);
        assertEq(auctionInfo.state.remainingTokens, AUCTION_AMOUNT);
        assertFalse(auctionInfo.state.isFinalized);
    }

    function test_BuyTokensMultipleTimes() public {
        vm.prank(governor);
        buyAndBurn.startAuction(address(tokenToAuction1));

        uint256 firstBuy = AUCTION_AMOUNT / 4;
        uint256 secondBuy = AUCTION_AMOUNT / 4;

        uint256 currentPrice = buyAndBurn.getCurrentPrice(1);

        vm.startPrank(buyer);
        summerToken.approve(address(buyAndBurn), currentPrice * AUCTION_AMOUNT);
        buyAndBurn.buyTokens(1, firstBuy);
        buyAndBurn.buyTokens(1, secondBuy);
        vm.stopPrank();

        (, DutchAuctionLibrary.AuctionState memory state) = buyAndBurn.auctions(
            1
        );
        assertEq(state.remainingTokens, AUCTION_AMOUNT - firstBuy - secondBuy);
    }

    function test_CannotBuyMoreThanAvailable() public {
        vm.prank(governor);
        buyAndBurn.startAuction(address(tokenToAuction1));

        vm.startPrank(buyer);
        summerToken.approve(address(buyAndBurn), 10000 ether);
        vm.expectRevert(
            abi.encodeWithSignature("InsufficientTokensAvailable()")
        );
        buyAndBurn.buyTokens(1, AUCTION_AMOUNT + 1);
        vm.stopPrank();
    }
}
