// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {DecayFunctions} from "../src/DecayFunctions.sol";
import {DutchAuctionLibrary} from "../src/DutchAuctionLibrary.sol";
import {DutchAuctionManager} from "../src/DutchAuctionManager.sol";
import {PERCENTAGE_100, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test, console} from "forge-std/Test.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";

contract DutchAuctionDecimalTest is Test {
    using PercentageUtils for uint256;

    DutchAuctionManager public auctionManager;
    MockERC20 public auctionToken6Dec;
    MockERC20 public auctionToken18Dec;
    MockERC20 public auctionToken8Dec;
    MockERC20 public paymentToken18Dec;
    MockERC20 public paymentToken8Dec;
    MockERC20 public paymentToken6Dec;

    address public constant AUCTION_KICKER = address(1);
    address public constant BUYER = address(2);
    address public constant UNSOLD_RECIPIENT = address(3);

    uint256 public constant AUCTION_DURATION = 1 days;
    uint256 public constant START_PRICE = 100 ether;
    uint256 public constant END_PRICE = 50 ether;
    uint256 public constant TOTAL_TOKENS = 1000 ether;
    Percentage public constant KICKER_REWARD_PERCENTAGE =
        Percentage.wrap(5 * 1e18);

    function setUp() public {
        auctionManager = new DutchAuctionManager();

        // Create tokens with different decimals
        auctionToken6Dec = new MockERC20();
        auctionToken6Dec.initialize("Auction Token 6 Decimals", "AT6", 6);
        auctionToken18Dec = new MockERC20();
        auctionToken18Dec.initialize("Auction Token 18 Decimals", "AT18", 18);
        auctionToken8Dec = new MockERC20();
        auctionToken8Dec.initialize("Auction Token 8 Decimals", "AT8", 8);
        paymentToken18Dec = new MockERC20();
        paymentToken18Dec.initialize("Payment Token 18 Decimals", "PT18", 18);
        paymentToken8Dec = new MockERC20();
        paymentToken8Dec.initialize("Payment Token 8 Decimals", "PT8", 8);
        paymentToken6Dec = new MockERC20();
        paymentToken6Dec.initialize("Payment Token 6 Decimals", "PT6", 6);

        // Mint tokens for the auction
        deal(
            address(auctionToken6Dec),
            address(auctionManager),
            1000 * 10 ** 6
        );
        deal(
            address(auctionToken18Dec),
            address(auctionManager),
            1000 * 10 ** 18
        );
        deal(
            address(auctionToken8Dec),
            address(auctionManager),
            1000 * 10 ** 8
        );

        // Mint payment tokens for the buyer
        deal(address(paymentToken18Dec), BUYER, 10_000 * 10 ** 18);
        deal(address(paymentToken8Dec), BUYER, 10_000 * 10 ** 8);
        deal(address(paymentToken6Dec), BUYER, 10_000 * 10 ** 6);

        // Approve auction manager to spend buyer's payment tokens
        vm.startPrank(BUYER);
        paymentToken18Dec.approve(address(auctionManager), type(uint256).max);
        paymentToken8Dec.approve(address(auctionManager), type(uint256).max);
        paymentToken6Dec.approve(address(auctionManager), type(uint256).max);
        vm.stopPrank();
    }

    function testAuction6DecPayment18Dec() public {
        uint256 auctionId = _createAuction(
            auctionToken6Dec,
            paymentToken18Dec,
            6,
            18
        );
        _runAuctionTest(auctionId, 6, 18);
    }

    function testAuction18DecPayment8Dec() public {
        uint256 auctionId = _createAuction(
            auctionToken18Dec,
            paymentToken8Dec,
            18,
            8
        );
        _runAuctionTest(auctionId, 18, 8);
    }

    function testAuction8DecPayment6Dec() public {
        uint256 auctionId = _createAuction(
            auctionToken8Dec,
            paymentToken6Dec,
            8,
            6
        );
        _runAuctionTest(auctionId, 8, 6);
    }

    function _createAuction(
        MockERC20 _auctionToken,
        MockERC20 _paymentToken,
        uint8 _auctionDecimals,
        uint8 _paymentDecimals
    ) internal returns (uint256) {
        uint256 totalTokens = 1000 * 10 ** _auctionDecimals;
        uint256 startPrice = 100 * 10 ** _paymentDecimals;
        uint256 endPrice = 50 * 10 ** _paymentDecimals;
        console.log("total tokens         ", totalTokens);
        console.log("start price          ", startPrice);
        console.log("end price            ", endPrice);
        vm.prank(AUCTION_KICKER);
        return
            auctionManager.createAuction(
                IERC20(address(_auctionToken)),
                IERC20(address(_paymentToken)),
                AUCTION_DURATION,
                startPrice,
                endPrice,
                totalTokens,
                KICKER_REWARD_PERCENTAGE,
                UNSOLD_RECIPIENT,
                DecayFunctions.DecayType.Linear
            );
    }

    function _runAuctionTest(
        uint256 _auctionId,
        uint8 _auctionDecimals,
        uint8 _paymentDecimals
    ) internal {
        // Test initial price
        uint256 currentPrice = auctionManager.getCurrentPrice(_auctionId);
        assertEq(
            currentPrice,
            100 * 10 ** _paymentDecimals,
            "Initial price incorrect"
        );

        // Test price halfway through auction
        vm.warp(block.timestamp + AUCTION_DURATION / 2);
        currentPrice = auctionManager.getCurrentPrice(_auctionId);
        assertApproxEqAbs(
            currentPrice,
            75 * 10 ** _paymentDecimals,
            1,
            "Mid-auction price incorrect"
        );

        // Test buying tokens
        uint256 buyAmount = 100 * 10 ** _auctionDecimals;

        vm.prank(BUYER);
        uint256 cost = auctionManager.buyTokens(_auctionId, buyAmount);

        // Verify correct amount of tokens received
        (DutchAuctionLibrary.AuctionConfig memory config, ) = auctionManager
            .auctions(_auctionId);
        assertEq(
            IERC20(config.auctionToken).balanceOf(BUYER),
            buyAmount,
            "Buyer did not receive correct amount of tokens"
        );

        // Verify correct cost calculation
        uint256 expectedCost = (currentPrice * buyAmount) /
            10 ** _auctionDecimals;
        assertApproxEqAbs(cost, expectedCost, 1, "Incorrect cost calculation");

        // Test final price
        vm.warp(block.timestamp + AUCTION_DURATION / 2);
        currentPrice = auctionManager.getCurrentPrice(_auctionId);
        assertEq(
            currentPrice,
            50 * 10 ** _paymentDecimals,
            "Final price incorrect"
        );

        // Test finalization
        vm.prank(AUCTION_KICKER);
        auctionManager.finalizeAuction(_auctionId);

        // Verify unsold tokens sent to recipient
        uint256 totalTokens = 1000 * 10 ** _auctionDecimals;
        uint256 kickerReward = totalTokens.applyPercentage(
            KICKER_REWARD_PERCENTAGE
        );
        uint256 unsoldAmount = totalTokens - buyAmount - kickerReward;
        assertEq(
            IERC20(config.auctionToken).balanceOf(UNSOLD_RECIPIENT),
            unsoldAmount,
            "Unsold tokens not sent to recipient"
        );
    }
}
