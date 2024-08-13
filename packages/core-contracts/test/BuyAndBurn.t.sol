// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {BuyAndBurn} from "../src/contracts/BuyAndBurn.sol";
import {IBuyAndBurnEvents} from "../src/events/IBuyAndBurnEvents.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ProtocolAccessManager} from "../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../src/interfaces/IProtocolAccessManager.sol";
import {DutchAuctionLibrary} from "@summerfi/dutch-auction/src/DutchAuctionLibrary.sol";
import {DutchAuctionEvents} from "@summerfi/dutch-auction/src/DutchAuctionEvents.sol";
import {DecayFunctions} from "@summerfi/dutch-auction/src/DecayFunctions.sol";
import {PercentageUtils} from "@summerfi/dutch-auction/src/lib/PercentageUtils.sol";
import {Percentage} from "@summerfi/dutch-auction/src/lib/Percentage.sol";
import "../src/errors/BuyAndBurnErrors.sol";
import "../src/errors/AccessControlErrors.sol";
import "../src/types/CommonAuctionTypes.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract BuyAndBurnTest is Test, IBuyAndBurnEvents {
    using PercentageUtils for uint256;

    BuyAndBurn public buyAndBurn;
    IProtocolAccessManager public accessManager;

    address public governor = address(1);
    address public buyer = address(2);
    address public treasury = address(3);
    ERC20Mock public summerToken;
    ERC20Mock public tokenToAuction1;
    ERC20Mock public tokenToAuction2;

    uint256 constant AUCTION_AMOUNT = 100000000;

    function setUp() public {
        summerToken = new ERC20Mock();
        tokenToAuction1 = new ERC20Mock();
        tokenToAuction2 = new ERC20Mock();
        accessManager = new ProtocolAccessManager(governor);

        buyAndBurn = new BuyAndBurn(
            address(summerToken),
            treasury,
            address(accessManager)
        );

        tokenToAuction1.mint(address(buyAndBurn), AUCTION_AMOUNT);
        tokenToAuction2.mint(address(buyAndBurn), AUCTION_AMOUNT);
        summerToken.mint(buyer, 10000 ether);

        vm.label(governor, "governor");
        vm.label(buyer, "buyer");
        vm.label(treasury, "treasury");
        vm.label(address(summerToken), "summerToken");
        vm.label(address(tokenToAuction1), "tokenToAuction1");
        vm.label(address(tokenToAuction2), "tokenToAuction2");
        vm.label(address(buyAndBurn), "buyAndBurn");
        vm.label(address(accessManager), "accessManager");
    }

    function test_Constructor() public {
        BuyAndBurn newBuyAndBurn = new BuyAndBurn(
            address(summerToken),
            treasury,
            address(accessManager)
        );
        (
            uint40 duration,
            uint256 startPrice,
            uint256 endPrice,
            Percentage kickerRewardPercentage,
            DecayFunctions.DecayType decayType
        ) = newBuyAndBurn.auctionDefaultParameters();
        assertEq(duration, 7 days);
        assertEq(startPrice, 1e18);
        assertEq(endPrice, 1e17);
        assertEq(Percentage.unwrap(kickerRewardPercentage), 0);
        assertEq(uint256(decayType), uint256(DecayFunctions.DecayType.Linear));
    }

    function test_StartAuction() public {
        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit BuyAndBurnAuctionStarted(
            0,
            address(tokenToAuction1),
            AUCTION_AMOUNT
        );

        buyAndBurn.startAuction(address(tokenToAuction1));

        (
            DutchAuctionLibrary.AuctionConfig memory config,
            DutchAuctionLibrary.AuctionState memory state
        ) = buyAndBurn.auctions(0);
        assertEq(address(config.auctionToken), address(tokenToAuction1));
        assertEq(state.remainingTokens, AUCTION_AMOUNT);
    }

    function test_CannotStartDuplicateAuction() public {
        vm.startPrank(governor);
        buyAndBurn.startAuction(address(tokenToAuction1));

        vm.expectRevert(
            abi.encodeWithSelector(
                BuyAndBurnAuctionAlreadyRunning.selector,
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
        vm.startPrank(buyer);
        summerToken.approve(address(buyAndBurn), buyAmount);
        vm.expectEmit(true, true, true, true);
        emit TokensPurchased(0, buyer, buyAmount, buyAmount); // Assuming 1:1 price for simplicity
        buyAndBurn.buyTokens(0, buyAmount);
        vm.stopPrank();

        (, DutchAuctionLibrary.AuctionState memory state) = buyAndBurn.auctions(
            0
        );
        assertEq(state.remainingTokens, AUCTION_AMOUNT - buyAmount);
    }

    function test_FinalizeAuction() public {
        vm.prank(governor);
        buyAndBurn.startAuction(address(tokenToAuction1));

        uint256 buyAmount = 50000000;
        vm.startPrank(buyer);
        summerToken.approve(address(buyAndBurn), buyAmount);
        buyAndBurn.buyTokens(0, buyAmount);
        vm.stopPrank();

        vm.warp(block.timestamp + 8 days);

        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit AuctionFinalized(
            0,
            buyAmount,
            buyAmount,
            AUCTION_AMOUNT - buyAmount
        );
        buyAndBurn.finalizeAuction(0);

        (, DutchAuctionLibrary.AuctionState memory state) = buyAndBurn.auctions(
            0
        );
        assertTrue(state.isFinalized);
        assertEq(summerToken.balanceOf(address(buyAndBurn)), 0); // All SUMMER tokens should be burned
        assertEq(
            tokenToAuction1.balanceOf(treasury),
            AUCTION_AMOUNT - buyAmount
        ); // Unsold tokens should be in treasury
    }

    function test_CannotFinalizeAuctionBeforeEndTime() public {
        vm.prank(governor);
        buyAndBurn.startAuction(address(tokenToAuction1));

        vm.expectRevert(abi.encodeWithSelector(AuctionNotEnded.selector, 0));
        vm.prank(governor);
        buyAndBurn.finalizeAuction(0);
    }

    function test_UpdateAuctionDefaultParameters() public {
        AuctionDefaultParameters memory newParams = AuctionDefaultParameters({
            duration: 5 days,
            startPrice: 2e18,
            endPrice: 5e17,
            kickerRewardPercentage: PercentageUtils.fromDecimalPercentage(5),
            decayType: DecayFunctions.DecayType.Exponential
        });

        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit AuctionDefaultParametersUpdated(newParams);
        buyAndBurn.updateAuctionDefaultParameters(newParams);

        (
            uint40 duration,
            uint256 startPrice,
            uint256 endPrice,
            Percentage kickerRewardPercentage,
            DecayFunctions.DecayType decayType
        ) = buyAndBurn.auctionDefaultParameters();
        assertEq(duration, newParams.duration);
        assertEq(startPrice, newParams.startPrice);
        assertEq(endPrice, newParams.endPrice);
        assertEq(
            Percentage.unwrap(kickerRewardPercentage),
            Percentage.unwrap(newParams.kickerRewardPercentage)
        );
        assertEq(uint256(decayType), uint256(newParams.decayType));
    }

    function test_SetTreasury() public {
        address newTreasury = address(4);
        vm.prank(governor);
        buyAndBurn.setTreasury(newTreasury);
        assertEq(buyAndBurn.treasury(), newTreasury);
    }

    function test_MultipleAuctionsCycle() public {
        // First auction cycle
        vm.prank(governor);
        buyAndBurn.startAuction(address(tokenToAuction1));

        uint256 firstAuctionBuyAmount = AUCTION_AMOUNT / 2;
        vm.startPrank(buyer);
        summerToken.approve(address(buyAndBurn), firstAuctionBuyAmount);
        buyAndBurn.buyTokens(0, firstAuctionBuyAmount);
        vm.stopPrank();

        vm.warp(block.timestamp + 8 days);
        vm.prank(governor);
        buyAndBurn.finalizeAuction(0);

        // Verify first auction results
        assertEq(summerToken.balanceOf(address(buyAndBurn)), 0); // All SUMMER tokens should be burned
        assertEq(
            tokenToAuction1.balanceOf(treasury),
            AUCTION_AMOUNT - firstAuctionBuyAmount
        );

        // Second auction cycle
        tokenToAuction2.mint(address(buyAndBurn), AUCTION_AMOUNT);

        vm.prank(governor);
        buyAndBurn.startAuction(address(tokenToAuction2));

        uint256 secondAuctionBuyAmount = (AUCTION_AMOUNT * 3) / 4;
        vm.startPrank(buyer);
        summerToken.approve(address(buyAndBurn), secondAuctionBuyAmount);
        buyAndBurn.buyTokens(1, secondAuctionBuyAmount);
        vm.stopPrank();

        vm.warp(block.timestamp + 8 days);
        vm.prank(governor);
        buyAndBurn.finalizeAuction(1);

        // Verify second auction results
        assertEq(summerToken.balanceOf(address(buyAndBurn)), 0); // All SUMMER tokens should be burned
        assertEq(
            tokenToAuction2.balanceOf(treasury),
            AUCTION_AMOUNT - secondAuctionBuyAmount
        );
    }

    function test_GetAuctionInfo() public {
        vm.prank(governor);
        buyAndBurn.startAuction(address(tokenToAuction1));

        DutchAuctionLibrary.Auction memory auctionInfo = buyAndBurn
            .getAuctionInfo(0);
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

        vm.startPrank(buyer);
        summerToken.approve(address(buyAndBurn), AUCTION_AMOUNT);
        buyAndBurn.buyTokens(0, firstBuy);
        buyAndBurn.buyTokens(0, secondBuy);
        vm.stopPrank();

        (, DutchAuctionLibrary.AuctionState memory state) = buyAndBurn.auctions(
            0
        );
        assertEq(state.remainingTokens, AUCTION_AMOUNT - firstBuy - secondBuy);
    }

    function test_CannotBuyMoreThanAvailable() public {
        vm.prank(governor);
        buyAndBurn.startAuction(address(tokenToAuction1));

        vm.startPrank(buyer);
        summerToken.approve(address(buyAndBurn), AUCTION_AMOUNT + 1);
        vm.expectRevert("InsufficientTokensAvailable");
        buyAndBurn.buyTokens(0, AUCTION_AMOUNT + 1);
        vm.stopPrank();
    }

    function test_OnlyGovernorCanStartAuction() public {
        vm.expectRevert(
            abi.encodeWithSelector(CallerIsNotGovernor.selector, buyer)
        );
        vm.prank(buyer);
        buyAndBurn.startAuction(address(tokenToAuction1));
    }

    function test_OnlyGovernorCanFinalizeAuction() public {
        vm.prank(governor);
        buyAndBurn.startAuction(address(tokenToAuction1));

        vm.warp(block.timestamp + 8 days);

        vm.expectRevert(
            abi.encodeWithSelector(CallerIsNotGovernor.selector, buyer)
        );
        vm.prank(buyer);
        buyAndBurn.finalizeAuction(0);
    }

    function test_CannotStartAuctionWithNoTokens() public {
        ERC20Mock emptyToken = new ERC20Mock();
        vm.expectRevert(NoTokensToAuction.selector);
        vm.prank(governor);
        buyAndBurn.startAuction(address(emptyToken));
    }
}
