// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import {DutchAuctionManager} from "../src/DutchAuctionManger.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DutchAuctionLibraryTest is Test {
    DutchAuctionManager public auctionManager;
    ERC20Mock public auctionToken1;
    ERC20Mock public auctionToken2;
    ERC20Mock public paymentToken;

    address public constant AUCTION_KICKER = address(1);
    address public constant BUYER1 = address(2);
    address public constant BUYER2 = address(3);
    address public constant BUYER3 = address(4);
    address public constant UNSOLD_RECIPIENT = address(5);

    uint256 public constant AUCTION_DURATION = 1 days;
    uint256 public constant START_PRICE = 100 ether;
    uint256 public constant END_PRICE = 50 ether;
    uint256 public constant TOTAL_TOKENS = 1000 ether;
    uint256 public constant KICKER_REWARD_PERCENTAGE = 5;

    function setUp() public {
        auctionManager = new DutchAuctionManager();
        auctionToken1 = new ERC20Mock();
        auctionToken2 = new ERC20Mock();
        paymentToken = new ERC20Mock();

        auctionToken1.mint(address(auctionManager), TOTAL_TOKENS);
        auctionToken2.mint(address(auctionManager), TOTAL_TOKENS);
        paymentToken.mint(
            BUYER1,
            7500000000000000000000000000000000000000 ether
        );
        paymentToken.mint(
            BUYER2,
            7500000000000000000000000000000000000000 ether
        );
        paymentToken.mint(
            BUYER3,
            7500000000000000000000000000000000000000 ether
        );

        vm.prank(BUYER1);
        paymentToken.approve(address(auctionManager), type(uint256).max);
        vm.prank(BUYER2);
        paymentToken.approve(address(auctionManager), type(uint256).max);
        vm.prank(BUYER3);
        paymentToken.approve(address(auctionManager), type(uint256).max);
    }

    function testCreateAuctionGuards() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidDuration()"));
        vm.prank(AUCTION_KICKER);
        auctionManager.createAuction(
            IERC20(address(auctionToken1)),
            IERC20(address(paymentToken)),
            0, // Invalid duration
            START_PRICE,
            END_PRICE,
            TOTAL_TOKENS,
            5,
            UNSOLD_RECIPIENT,
            true
        );

        vm.expectRevert(abi.encodeWithSignature("InvalidPrices()"));
        vm.prank(AUCTION_KICKER);
        auctionManager.createAuction(
            IERC20(address(auctionToken1)),
            IERC20(address(paymentToken)),
            AUCTION_DURATION,
            END_PRICE, // Start price <= end price
            END_PRICE,
            TOTAL_TOKENS,
            5,
            UNSOLD_RECIPIENT,
            true
        );

        vm.expectRevert(abi.encodeWithSignature("InvalidTokenAmount()"));
        vm.prank(AUCTION_KICKER);
        auctionManager.createAuction(
            IERC20(address(auctionToken1)),
            IERC20(address(paymentToken)),
            AUCTION_DURATION,
            START_PRICE,
            END_PRICE,
            0, // Invalid token amount
            5,
            UNSOLD_RECIPIENT,
            true
        );

        vm.expectRevert(
            abi.encodeWithSignature("InvalidKickerRewardPercentage()")
        );
        vm.prank(AUCTION_KICKER);
        auctionManager.createAuction(
            IERC20(address(auctionToken1)),
            IERC20(address(paymentToken)),
            AUCTION_DURATION,
            START_PRICE,
            END_PRICE,
            TOTAL_TOKENS,
            100, // Invalid percentage
            UNSOLD_RECIPIENT,
            true
        );
    }

    function testAuctionLifecycle_Linear() public {
        uint256 auctionId = _createAuction(auctionToken1, true);
        _testAuctionLifecycle(auctionId, true);
    }

    function testAuctionLifecycle_Exponential() public {
        uint256 auctionId = _createAuction(auctionToken1, false);
        _testAuctionLifecycle(auctionId, false);
    }

    function testClaimedRewards() public {
        uint256 kickerRewardAmount = (TOTAL_TOKENS * KICKER_REWARD_PERCENTAGE) /
            100;
        uint256 creatorBalanceBefore = auctionToken1.balanceOf(AUCTION_KICKER);

        _createAuction(auctionToken1, true);

        uint256 creatorBalanceAfter = auctionToken1.balanceOf(AUCTION_KICKER);

        assertEq(
            creatorBalanceAfter - creatorBalanceBefore,
            kickerRewardAmount,
            "Kicker reward not claimed correctly"
        );
    }

    function testMultipleAuctions() public {
        uint256 auctionId1 = _createAuction(auctionToken1, true);
        uint256 auctionId2 = _createAuction(auctionToken2, false);

        vm.warp(block.timestamp + AUCTION_DURATION / 2);

        uint256 buyAmount = 100 ether;
        vm.startPrank(BUYER1);
        auctionManager.buyTokens(auctionId1, buyAmount);
        auctionManager.buyTokens(auctionId2, buyAmount);
        vm.stopPrank();

        assertEq(
            auctionToken1.balanceOf(BUYER1),
            buyAmount,
            "Buyer should have received tokens from auction 1"
        );
        assertEq(
            auctionToken2.balanceOf(BUYER1),
            buyAmount,
            "Buyer should have received tokens from auction 2"
        );
    }

    function testMultipleBuyersSameBlock() public {
        uint256 auctionId = _createAuction(auctionToken1, true);

        vm.warp(block.timestamp + AUCTION_DURATION / 2);

        uint256 buyAmount = 100 ether;
        vm.prank(BUYER1);
        auctionManager.buyTokens(auctionId, buyAmount);

        vm.prank(BUYER2);
        auctionManager.buyTokens(auctionId, buyAmount);

        vm.prank(BUYER3);
        auctionManager.buyTokens(auctionId, buyAmount);

        assertEq(
            auctionToken1.balanceOf(BUYER1),
            buyAmount,
            "Buyer1 should have received tokens"
        );
        assertEq(
            auctionToken1.balanceOf(BUYER2),
            buyAmount,
            "Buyer2 should have received tokens"
        );
        assertEq(
            auctionToken1.balanceOf(BUYER3),
            buyAmount,
            "Buyer3 should have received tokens"
        );
    }

    function testMultipleBuyersDifferentBlocks() public {
        uint256 auctionId = _createAuction(auctionToken1, true);

        uint256 buyAmount = 100 ether;

        // First purchase
        vm.warp(block.timestamp + AUCTION_DURATION / 4);
        vm.prank(BUYER1);
        auctionManager.buyTokens(auctionId, buyAmount);

        // Second purchase, 100 blocks and 1 hour later
        vm.roll(block.number + 100);
        vm.warp(block.timestamp + 1 hours);
        vm.prank(BUYER2);
        auctionManager.buyTokens(auctionId, buyAmount);

        // Third purchase, another 100 blocks and 1 hour later
        vm.roll(block.number + 100);
        vm.warp(block.timestamp + 1 hours);
        vm.prank(BUYER3);
        auctionManager.buyTokens(auctionId, buyAmount);

        assertEq(
            auctionToken1.balanceOf(BUYER1),
            buyAmount,
            "Buyer1 should have received tokens"
        );
        assertEq(
            auctionToken1.balanceOf(BUYER2),
            buyAmount,
            "Buyer2 should have received tokens"
        );
        assertEq(
            auctionToken1.balanceOf(BUYER3),
            buyAmount,
            "Buyer3 should have received tokens"
        );
    }

    function testPriceDecreaseOverTime() public {
        uint256 auctionId = _createAuction(auctionToken1, true);

        uint256 initialPrice = auctionManager.getCurrentPrice(auctionId);

        vm.warp(block.timestamp + AUCTION_DURATION / 4);
        uint256 quarterPrice = auctionManager.getCurrentPrice(auctionId);

        vm.warp(block.timestamp + AUCTION_DURATION / 4);
        uint256 halfPrice = auctionManager.getCurrentPrice(auctionId);

        vm.warp(block.timestamp + AUCTION_DURATION / 4);
        uint256 threeQuarterPrice = auctionManager.getCurrentPrice(auctionId);

        vm.warp(block.timestamp + AUCTION_DURATION / 4);
        uint256 finalPrice = auctionManager.getCurrentPrice(auctionId);

        assertGt(initialPrice, quarterPrice, "Price should decrease over time");
        assertGt(quarterPrice, halfPrice, "Price should decrease over time");
        assertGt(
            halfPrice,
            threeQuarterPrice,
            "Price should decrease over time"
        );
        assertGt(
            threeQuarterPrice,
            finalPrice,
            "Price should decrease over time"
        );
        assertEq(finalPrice, END_PRICE, "Final price should match END_PRICE");
    }

    function testBuyingAllTokens() public {
        uint256 auctionId = _createAuction(auctionToken1, true);

        uint256 kickerReward = (TOTAL_TOKENS * KICKER_REWARD_PERCENTAGE) / 100;
        uint256 availableTokens = TOTAL_TOKENS - kickerReward;

        vm.warp(block.timestamp + AUCTION_DURATION / 2);

        vm.prank(BUYER1);
        auctionManager.buyTokens(auctionId, availableTokens / 2);

        vm.prank(BUYER2);
        auctionManager.buyTokens(auctionId, availableTokens / 4);

        vm.prank(BUYER3);
        auctionManager.buyTokens(auctionId, availableTokens / 4);

        // Try to buy more tokens, should revert
        vm.expectRevert(abi.encodeWithSignature("AuctionAlreadyFinalized()"));
        vm.prank(BUYER1);
        auctionManager.buyTokens(auctionId, 1);

        // Finalize the auction, should revert since it was finalized on the last buy
        vm.expectRevert(abi.encodeWithSignature("AuctionAlreadyFinalized()"));
        vm.prank(AUCTION_KICKER);
        auctionManager.finalizeAuction(auctionId);

        // Check balances
        assertEq(
            auctionToken1.balanceOf(BUYER1),
            availableTokens / 2,
            "Buyer1 balance incorrect"
        );
        assertEq(
            auctionToken1.balanceOf(BUYER2),
            availableTokens / 4,
            "Buyer2 balance incorrect"
        );
        assertEq(
            auctionToken1.balanceOf(BUYER3),
            availableTokens / 4,
            "Buyer3 balance incorrect"
        );
        assertEq(
            auctionToken1.balanceOf(AUCTION_KICKER),
            kickerReward,
            "Auction creator should have received kicker reward"
        );
        assertEq(
            auctionToken1.balanceOf(UNSOLD_RECIPIENT),
            0,
            "Unsold recipient should have no tokens"
        );
    }

    function testBuyingAllTokensAndFinalizing() public {
        uint256 auctionId = _createAuction(auctionToken1, true);

        uint256 kickerReward = (TOTAL_TOKENS * KICKER_REWARD_PERCENTAGE) / 100;
        uint256 availableTokens = TOTAL_TOKENS - kickerReward;

        vm.warp(block.timestamp + AUCTION_DURATION / 2);

        vm.prank(BUYER1);
        auctionManager.buyTokens(auctionId, availableTokens / 2);

        vm.prank(BUYER2);
        auctionManager.buyTokens(auctionId, availableTokens / 4);

        vm.prank(BUYER3);
        auctionManager.buyTokens(auctionId, (availableTokens / 4) - 1);

        vm.warp(block.timestamp + AUCTION_DURATION / 2);

        // Finalize the auction, should
        vm.prank(AUCTION_KICKER);
        auctionManager.finalizeAuction(auctionId);

        // Check balances
        assertEq(
            auctionToken1.balanceOf(BUYER1),
            availableTokens / 2,
            "Buyer1 balance incorrect"
        );
        assertEq(
            auctionToken1.balanceOf(BUYER2),
            availableTokens / 4,
            "Buyer2 balance incorrect"
        );
        assertEq(
            auctionToken1.balanceOf(BUYER3),
            (availableTokens / 4) - 1,
            "Buyer3 balance incorrect"
        );
        assertEq(
            auctionToken1.balanceOf(AUCTION_KICKER),
            kickerReward,
            "Auction creator should have received kicker reward"
        );
        assertEq(
            auctionToken1.balanceOf(UNSOLD_RECIPIENT),
            1,
            "Unsold recipient should have no tokens"
        );
    }
    function testInvalidKickerRewardPercentage() public {
        vm.expectRevert(
            abi.encodeWithSignature("InvalidKickerRewardPercentage()")
        );
        vm.prank(AUCTION_KICKER);
        auctionManager.createAuction(
            IERC20(address(auctionToken1)),
            IERC20(address(paymentToken)),
            AUCTION_DURATION,
            START_PRICE,
            END_PRICE,
            TOTAL_TOKENS,
            101, // Invalid percentage (> 100)
            UNSOLD_RECIPIENT,
            true
        );
    }

    function testAuctionNotActive() public {
        uint256 auctionId = _createAuction(auctionToken1, true);

        // Try to buy tokens after auction ends
        vm.warp(block.timestamp + AUCTION_DURATION + 1);
        vm.expectRevert(abi.encodeWithSignature("AuctionNotActive()"));
        vm.prank(BUYER1);
        auctionManager.buyTokens(auctionId, 1 ether);
    }

    function testInsufficientTokensAvailable() public {
        uint256 auctionId = _createAuction(auctionToken1, true);

        uint256 kickerReward = (TOTAL_TOKENS * KICKER_REWARD_PERCENTAGE) / 100;
        uint256 availableTokens = TOTAL_TOKENS - kickerReward;

        vm.warp(block.timestamp + AUCTION_DURATION / 2);

        vm.expectRevert(
            abi.encodeWithSignature("InsufficientTokensAvailable()")
        );
        vm.prank(BUYER1);
        auctionManager.buyTokens(auctionId, availableTokens + 1);
    }

    function testAuctionNotEnded() public {
        uint256 auctionId = _createAuction(auctionToken1, true);

        vm.warp(block.timestamp + AUCTION_DURATION / 2);

        vm.expectRevert(abi.encodeWithSignature("AuctionNotEnded()"));
        vm.prank(AUCTION_KICKER);
        auctionManager.finalizeAuction(auctionId);
    }

    function testImmediateAuctionStart() public {
        uint256 auctionId = _createAuction(auctionToken1, true);

        // Try to buy tokens immediately after creation
        vm.prank(BUYER1);
        auctionManager.buyTokens(auctionId, 1 ether);

        // Assert that the purchase was successful
        assertEq(
            auctionToken1.balanceOf(BUYER1),
            1 ether,
            "Buyer should have received tokens immediately after auction creation"
        );
    }
    function _createAuction(
        ERC20Mock _auctionToken,
        bool _isLinearDecay
    ) internal returns (uint256) {
        vm.prank(AUCTION_KICKER);
        return
            auctionManager.createAuction(
                IERC20(address(_auctionToken)),
                IERC20(address(paymentToken)),
                AUCTION_DURATION,
                START_PRICE,
                END_PRICE,
                TOTAL_TOKENS,
                KICKER_REWARD_PERCENTAGE,
                UNSOLD_RECIPIENT,
                _isLinearDecay
            );
    }

    function _testAuctionLifecycle(
        uint256 _auctionId,
        bool _isLinearDecay
    ) internal {
        // Test initial state
        uint256 currentPrice = auctionManager.getCurrentPrice(_auctionId);
        assertEq(
            currentPrice,
            START_PRICE,
            "Initial price should be start price"
        );

        // Test price halfway through auction
        vm.warp(block.timestamp + AUCTION_DURATION / 2);
        currentPrice = auctionManager.getCurrentPrice(_auctionId);
        uint256 expectedMidPrice = _isLinearDecay
            ? (START_PRICE + END_PRICE) / 2
            : END_PRICE + ((START_PRICE - END_PRICE) * 1 ** 2) / 4;
        assertApproxEqAbs(
            currentPrice,
            expectedMidPrice,
            1 ether,
            "Mid-auction price incorrect"
        );

        // Test buying tokens
        uint256 buyAmount = 100 ether;
        vm.prank(BUYER1);
        auctionManager.buyTokens(_auctionId, buyAmount);
        assertEq(
            auctionToken1.balanceOf(BUYER1),
            buyAmount,
            "Buyer should have received tokens"
        );

        // Test final price
        vm.warp(block.timestamp + AUCTION_DURATION / 2);
        currentPrice = auctionManager.getCurrentPrice(_auctionId);
        assertEq(currentPrice, END_PRICE, "Final price should be end price");

        // Test finalization
        vm.prank(AUCTION_KICKER);
        auctionManager.finalizeAuction(_auctionId);

        // Verify unsold tokens sent to recipient
        uint256 unsoldAmount = TOTAL_TOKENS -
            buyAmount -
            ((TOTAL_TOKENS * KICKER_REWARD_PERCENTAGE) / 100);
        assertEq(
            auctionToken1.balanceOf(UNSOLD_RECIPIENT),
            unsoldAmount,
            "Unsold tokens not sent to recipient"
        );
    }
}
