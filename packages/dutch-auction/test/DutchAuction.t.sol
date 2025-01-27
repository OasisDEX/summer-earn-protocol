// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {DecayFunctions} from "../src/DecayFunctions.sol";

import {DutchAuctionLibrary} from "../src/DutchAuctionLibrary.sol";
import {DutchAuctionManager} from "../src/DutchAuctionManager.sol";
import {PERCENTAGE_100, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "forge-std/StdJson.sol";
import "forge-std/Test.sol";

contract DutchAuctionLibraryTest is Test {
    using stdJson for string;
    using PercentageUtils for uint256;

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
    Percentage public constant KICKER_REWARD_PERCENTAGE =
        Percentage.wrap(5 * 1e18);
    uint256 public constant KICKER_REWARD_AMOUNT = 50 ether;

    // JSON data for expected prices
    string constant EXPECTED_PRICES_PATH = "./utils/expected_prices.json";

    function setUp() public {
        auctionManager = new DutchAuctionManager();
        auctionToken1 = new ERC20Mock();
        auctionToken2 = new ERC20Mock();
        paymentToken = new ERC20Mock();

        auctionToken1.mint(address(auctionManager), TOTAL_TOKENS);
        auctionToken2.mint(address(auctionManager), TOTAL_TOKENS);
        paymentToken.mint(
            BUYER1,
            7_500_000_000_000_000_000_000_000_000_000_000_000_000 ether
        );
        paymentToken.mint(
            BUYER2,
            7_500_000_000_000_000_000_000_000_000_000_000_000_000 ether
        );
        paymentToken.mint(
            BUYER3,
            7_500_000_000_000_000_000_000_000_000_000_000_000_000 ether
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
            KICKER_REWARD_PERCENTAGE,
            UNSOLD_RECIPIENT,
            DecayFunctions.DecayType.Linear
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
            KICKER_REWARD_PERCENTAGE,
            UNSOLD_RECIPIENT,
            DecayFunctions.DecayType.Linear
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
            KICKER_REWARD_PERCENTAGE,
            UNSOLD_RECIPIENT,
            DecayFunctions.DecayType.Linear
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
            PERCENTAGE_100 + Percentage.wrap(1),
            UNSOLD_RECIPIENT,
            DecayFunctions.DecayType.Linear
        );

        vm.expectRevert(abi.encodeWithSignature("InvalidAuctionToken()"));
        vm.prank(AUCTION_KICKER);
        auctionManager.createAuction(
            IERC20(address(0)),
            IERC20(address(paymentToken)),
            AUCTION_DURATION,
            START_PRICE,
            END_PRICE,
            TOTAL_TOKENS,
            KICKER_REWARD_PERCENTAGE,
            UNSOLD_RECIPIENT,
            DecayFunctions.DecayType.Linear
        );
        vm.expectRevert(abi.encodeWithSignature("InvalidPaymentToken()"));
        vm.prank(AUCTION_KICKER);
        auctionManager.createAuction(
            IERC20(address(auctionToken1)),
            IERC20(address(0)),
            AUCTION_DURATION,
            START_PRICE,
            END_PRICE,
            TOTAL_TOKENS,
            KICKER_REWARD_PERCENTAGE,
            UNSOLD_RECIPIENT,
            DecayFunctions.DecayType.Linear
        );

        // success
        vm.prank(AUCTION_KICKER);
        uint256 gas = gasleft();
        uint256 auctionId = auctionManager.createAuction(
            IERC20(address(auctionToken1)),
            IERC20(address(paymentToken)),
            AUCTION_DURATION,
            START_PRICE,
            END_PRICE,
            TOTAL_TOKENS,
            KICKER_REWARD_PERCENTAGE,
            UNSOLD_RECIPIENT,
            DecayFunctions.DecayType.Linear
        );
        console.log("used gas", gas - gasleft());
        (
            DutchAuctionLibrary.AuctionConfig memory config,
            DutchAuctionLibrary.AuctionState memory state
        ) = auctionManager.auctions(auctionId);
        assertEq(config.id, auctionId, "Auction ID not set correctly");
        assertEq(
            address(config.auctionToken),
            address(auctionToken1),
            "Auction token not set correctly"
        );
        assertEq(
            address(config.paymentToken),
            address(paymentToken),
            "Payment token not set correctly"
        );

        assertEq(
            config.startPrice,
            START_PRICE,
            "Start price not set correctly"
        );
        assertEq(config.endPrice, END_PRICE, "End price not set correctly");
        assertEq(
            config.totalTokens,
            TOTAL_TOKENS - KICKER_REWARD_AMOUNT,
            "Total tokens not set correctly"
        );
        assertEq(
            config.kickerRewardAmount,
            TOTAL_TOKENS.applyPercentage(KICKER_REWARD_PERCENTAGE),
            "Kicker reward percentage not set correctly"
        );
        assertEq(
            address(config.unsoldTokensRecipient),
            UNSOLD_RECIPIENT,
            "Unsold tokens recipient not set correctly"
        );
        assertEq(
            config.startTime,
            block.timestamp,
            "Start time not set correctly"
        );
        assertEq(
            config.endTime,
            block.timestamp + AUCTION_DURATION,
            "End time not set correctly"
        );
        assertEq(
            state.remainingTokens,
            TOTAL_TOKENS - KICKER_REWARD_AMOUNT,
            "Remaining tokens not set correctly"
        );
        assertEq(state.isFinalized, false, "Auction should not be finalized");

        auctionToken1.mint(address(this), 100 ether);

        DutchAuctionLibrary.Auction memory auction = DutchAuctionLibrary
            .createAuction(
                DutchAuctionLibrary.AuctionParams(
                    0,
                    IERC20(address(auctionToken1)),
                    IERC20(address(paymentToken)),
                    uint40(AUCTION_DURATION),
                    START_PRICE,
                    END_PRICE,
                    TOTAL_TOKENS,
                    KICKER_REWARD_PERCENTAGE,
                    AUCTION_KICKER,
                    UNSOLD_RECIPIENT,
                    DecayFunctions.DecayType.Linear
                )
            );

        assertEq(auction.config.id, auctionId, "Auction ID not set correctly");
        assertEq(
            address(auction.config.auctionToken),
            address(auctionToken1),
            "Auction token not set correctly"
        );
        assertEq(
            address(auction.config.paymentToken),
            address(paymentToken),
            "Payment token not set correctly"
        );
        assertEq(
            auction.config.startPrice,
            START_PRICE,
            "Start price not set correctly"
        );
        assertEq(
            auction.config.endPrice,
            END_PRICE,
            "End price not set correctly"
        );
        assertEq(
            auction.config.totalTokens,
            TOTAL_TOKENS - KICKER_REWARD_AMOUNT,
            "Total tokens not set correctly"
        );
        assertEq(
            auction.config.kickerRewardAmount,
            TOTAL_TOKENS.applyPercentage(KICKER_REWARD_PERCENTAGE),
            "Kicker reward percentage not set correctly"
        );
        assertEq(
            address(auction.config.unsoldTokensRecipient),
            UNSOLD_RECIPIENT,
            "Unsold tokens recipient not set correctly"
        );
        assertEq(
            auction.config.startTime,
            block.timestamp,
            "Start time not set correctly"
        );
        assertEq(
            auction.config.endTime,
            block.timestamp + AUCTION_DURATION,
            "End time not set correctly"
        );
        assertEq(
            auction.state.remainingTokens,
            TOTAL_TOKENS - KICKER_REWARD_AMOUNT,
            "Remaining tokens not set correctly"
        );
        assertEq(
            auction.state.isFinalized,
            false,
            "Auction should not be finalized"
        );
    }

    function testPriceDecayLinear() public {
        uint256 auctionId = _createAuction(
            auctionToken1,
            DecayFunctions.DecayType.Linear
        );
        // Load expected prices from JSON
        string memory json = vm.readFile(EXPECTED_PRICES_PATH);

        string[] memory keys = vm.parseJsonKeys(json, ".linear");

        uint256 initialBlockTimestamp = block.timestamp;
        uint256[] memory timeIntervals = getIntervals(keys);
        uint256[] memory expectedPrices = getExpectedPrices(
            json,
            keys,
            "linear"
        );
        for (uint256 i = 0; i < keys.length; i++) {
            vm.warp(initialBlockTimestamp + timeIntervals[i]);

            uint256 currentPrice = auctionManager.getCurrentPrice(auctionId);
            assertEq(
                currentPrice,
                expectedPrices[i],
                "Linear price incorrect at interval"
            );
        }
    }

    function testPriceDecayQuadratic() public {
        uint256 auctionId = _createAuction(
            auctionToken1,
            DecayFunctions.DecayType.Quadratic
        );
        string memory json = vm.readFile(EXPECTED_PRICES_PATH);

        string[] memory keys = vm.parseJsonKeys(json, ".quadratic");

        uint256 initialBlockTimestamp = block.timestamp;
        uint256[] memory timeIntervals = getIntervals(keys);
        uint256[] memory expectedPrices = getExpectedPrices(
            json,
            keys,
            "quadratic"
        );
        for (uint256 i = 0; i < keys.length; i++) {
            vm.warp(initialBlockTimestamp + timeIntervals[i]);

            uint256 currentPrice = auctionManager.getCurrentPrice(auctionId);
            assertEq(
                currentPrice,
                expectedPrices[i],
                "Quadratic price incorrect at interval"
            );
        }
    }

    function testAuctionLifecycle_Linear() public {
        uint256 auctionId = _createAuction(
            auctionToken1,
            DecayFunctions.DecayType.Linear
        );
        _testAuctionLifecycle(auctionId, true);
    }

    function testAuctionLifecycle_Quadratic() public {
        uint256 auctionId = _createAuction(
            auctionToken1,
            DecayFunctions.DecayType.Quadratic
        );
        _testAuctionLifecycle(auctionId, false);
    }

    function testClaimedRewards() public {
        uint256 kickerRewardAmount = TOTAL_TOKENS.applyPercentage(
            KICKER_REWARD_PERCENTAGE
        );
        uint256 creatorBalanceBefore = auctionToken1.balanceOf(AUCTION_KICKER);

        _createAuction(auctionToken1, DecayFunctions.DecayType.Linear);

        uint256 creatorBalanceAfter = auctionToken1.balanceOf(AUCTION_KICKER);

        assertEq(
            creatorBalanceAfter - creatorBalanceBefore,
            kickerRewardAmount,
            "Kicker reward not claimed correctly"
        );
    }

    function testMultipleAuctions() public {
        uint256 auctionId1 = _createAuction(
            auctionToken1,
            DecayFunctions.DecayType.Linear
        );
        uint256 auctionId2 = _createAuction(
            auctionToken2,
            DecayFunctions.DecayType.Quadratic
        );

        vm.warp(block.timestamp + AUCTION_DURATION / 2);

        uint256 buyAmount = 100 ether;
        vm.startPrank(BUYER1);
        auctionManager.buyTokens(auctionId1, buyAmount);
        auctionManager.buyTokens(auctionId2, buyAmount);
        vm.stopPrank();
        assertEq(
            auctionId2,
            auctionId1 + 1,
            "Auction IDs should be sequential"
        );
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
        uint256 auctionId = _createAuction(
            auctionToken1,
            DecayFunctions.DecayType.Linear
        );

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
        uint256 auctionId = _createAuction(
            auctionToken1,
            DecayFunctions.DecayType.Linear
        );

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
        uint256 auctionId = _createAuction(
            auctionToken1,
            DecayFunctions.DecayType.Linear
        );

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
        uint256 auctionId = _createAuction(
            auctionToken1,
            DecayFunctions.DecayType.Linear
        );

        uint256 kickerReward = TOTAL_TOKENS.applyPercentage(
            KICKER_REWARD_PERCENTAGE
        );
        uint256 availableTokens = TOTAL_TOKENS - kickerReward;

        vm.warp(block.timestamp + AUCTION_DURATION / 2);

        vm.prank(BUYER1);
        auctionManager.buyTokens(auctionId, availableTokens / 2);

        vm.prank(BUYER2);
        auctionManager.buyTokens(auctionId, availableTokens / 4);

        vm.prank(BUYER3);
        auctionManager.buyTokens(auctionId, availableTokens / 4);

        // Try to buy more tokens, should revert
        vm.expectRevert(
            abi.encodeWithSignature("AuctionAlreadyFinalized(uint256)", 0)
        );
        vm.prank(BUYER1);
        auctionManager.buyTokens(auctionId, 1);

        // Finalize the auction, should revert since it was finalized on the last buy
        vm.expectRevert(
            abi.encodeWithSignature("AuctionAlreadyFinalized(uint256)", 0)
        );
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

    function test_BuyTokens_AuctionNotFound() public {
        vm.expectRevert(abi.encodeWithSignature("AuctionNotFound()"));
        auctionManager.buyTokens(999, 0);
    }
    function test_FinalizeAuction_AuctionNotFound() public {
        vm.expectRevert(abi.encodeWithSignature("AuctionNotFound()"));
        auctionManager.finalizeAuction(999);
    }
    function testBuyingAllTokensAndFinalizing() public {
        uint256 auctionId = _createAuction(
            auctionToken1,
            DecayFunctions.DecayType.Linear
        );

        uint256 kickerReward = TOTAL_TOKENS.applyPercentage(
            KICKER_REWARD_PERCENTAGE
        );
        uint256 availableTokens = TOTAL_TOKENS - kickerReward;

        vm.warp(block.timestamp + AUCTION_DURATION / 2);

        vm.prank(BUYER1);
        auctionManager.buyTokens(auctionId, availableTokens / 2);

        vm.prank(BUYER2);
        auctionManager.buyTokens(auctionId, availableTokens / 4);

        vm.prank(BUYER3);
        auctionManager.buyTokens(auctionId, (availableTokens / 4) - 1);

        vm.warp(block.timestamp + AUCTION_DURATION * 3);

        uint256 price = auctionManager.getCurrentPrice(auctionId);
        assertEq(price, END_PRICE, "Price should be end price");

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

    function testAuctionNotActive() public {
        uint256 auctionId = _createAuction(
            auctionToken1,
            DecayFunctions.DecayType.Linear
        );

        // Try to buy tokens after auction ends
        vm.warp(block.timestamp + AUCTION_DURATION + 1);
        vm.expectRevert(
            abi.encodeWithSignature("AuctionNotActive(uint256)", 0)
        );
        vm.prank(BUYER1);
        auctionManager.buyTokens(auctionId, 1 ether);
    }

    function testInsufficientTokensAvailable() public {
        uint256 auctionId = _createAuction(
            auctionToken1,
            DecayFunctions.DecayType.Linear
        );

        uint256 kickerReward = TOTAL_TOKENS.applyPercentage(
            KICKER_REWARD_PERCENTAGE
        );
        uint256 availableTokens = TOTAL_TOKENS - kickerReward;

        vm.warp(block.timestamp + AUCTION_DURATION / 2);

        vm.expectRevert(
            abi.encodeWithSignature("InsufficientTokensAvailable()")
        );
        vm.prank(BUYER1);
        auctionManager.buyTokens(auctionId, availableTokens + 1);
    }

    function testAuctionNotEnded() public {
        uint256 auctionId = _createAuction(
            auctionToken1,
            DecayFunctions.DecayType.Linear
        );

        vm.warp(block.timestamp + AUCTION_DURATION / 2);

        vm.expectRevert(abi.encodeWithSignature("AuctionNotEnded(uint256)", 0));
        vm.prank(AUCTION_KICKER);
        auctionManager.finalizeAuction(auctionId);
    }

    function testImmediateAuctionStart() public {
        uint256 auctionId = _createAuction(
            auctionToken1,
            DecayFunctions.DecayType.Linear
        );

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
        DecayFunctions.DecayType _decayType
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
                _decayType
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
            TOTAL_TOKENS.applyPercentage(KICKER_REWARD_PERCENTAGE);
        assertEq(
            auctionToken1.balanceOf(UNSOLD_RECIPIENT),
            unsoldAmount,
            "Unsold tokens not sent to recipient"
        );
    }

    /**
     * @dev Calculates the expected prices based on the provided JSON data, keys, and decay value.
     * @param _json The JSON data containing the prices.
     * @param keys The keys to extract the prices from the JSON data.
     * @param decay The decay value to be used in the price calculation.
     * @return An array of uint256 values representing the expected prices.
     */
    function getExpectedPrices(
        string memory _json,
        string[] memory keys,
        string memory decay
    ) internal pure returns (uint256[] memory) {
        uint256[] memory prices = new uint256[](keys.length);

        for (uint256 i = 0; i < keys.length; i++) {
            prices[i] = _readUintFromJson(_json, decay, keys[i]);
        }
        return prices;
    }

    /**
     * @dev Reads a uint256 value from the provided JSON data based on the decay, and key.
     * @param _json The JSON data containing the value.
     * @param decay The decay value to be used in the value extraction.
     * @param key The key to extract the value from the JSON data.
     * @return The extracted uint256 value.
     */
    function _readUintFromJson(
        string memory _json,
        string memory decay,
        string memory key
    ) internal pure returns (uint256) {
        string memory path = string(abi.encodePacked(".", decay, ".", key));
        return _json.readUint(path);
    }

    /**
     * @dev Converts an array of string values to an array of uint256 values.
     * @param keys The string values to be converted.
     * @return An array of uint256 values representing the converted string values.
     */
    function getIntervals(
        string[] memory keys
    ) internal pure returns (uint256[] memory) {
        uint256[] memory intervals = new uint256[](keys.length);

        for (uint256 i = 0; i < keys.length; i++) {
            intervals[i] = vm.parseUint(keys[i]);
        }
        return intervals;
    }
}
