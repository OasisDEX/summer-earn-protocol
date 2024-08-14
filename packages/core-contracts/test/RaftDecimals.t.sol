// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Raft} from "../src/contracts/Raft.sol";
import {ConfigurationManager} from "../src/contracts/ConfigurationManager.sol";
import {ConfigurationManagerParams} from "../src/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "../src/contracts/ProtocolAccessManager.sol";
import {DecayFunctions} from "@summerfi/dutch-auction/src/DecayFunctions.sol";
import {PERCENTAGE_100, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {Test, console} from "forge-std/Test.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {ArkMock, ArkParams} from "./mocks/ArkMock.sol";
import {AuctionDefaultParameters} from "../src/types/CommonAuctionTypes.sol";

contract RaftDecimalsTest is Test {
    using PercentageUtils for uint256;

    Raft public raft;
    ProtocolAccessManager public accessManager;
    ConfigurationManager public configurationManager;

    ArkMock public mockArk;
    MockERC20 public rewardToken6Dec;
    MockERC20 public rewardToken8Dec;
    MockERC20 public rewardToken18Dec;
    MockERC20 public paymentToken18Dec;
    AuctionDefaultParameters newParams;

    address public governor = address(1);
    address public buyer = address(2);
    address public superKeeper = address(3);

    uint256 constant AUCTION_DURATION = 7 days;
    uint256 constant KICKER_REWARD_PERCENTAGE = 5 * 1e18;

    uint256 constant START_PRICE = 1 * 10 ** 18;
    uint256 constant END_PRICE = 1;

    function setUp() public {
        accessManager = new ProtocolAccessManager(governor);
        vm.prank(governor);
        accessManager.grantSuperKeeperRole(superKeeper);
        newParams = AuctionDefaultParameters({
            duration: uint40(AUCTION_DURATION),
            startPrice: START_PRICE,
            endPrice: END_PRICE,
            kickerRewardPercentage: Percentage.wrap(KICKER_REWARD_PERCENTAGE),
            decayType: DecayFunctions.DecayType.Linear
        });
        raft = new Raft(address(accessManager), newParams);

        configurationManager = new ConfigurationManager(
            ConfigurationManagerParams({
                accessManager: address(accessManager),
                raft: address(raft),
                tipJar: address(0)
            })
        );

        // Create reward tokens with different decimals
        rewardToken6Dec = new MockERC20();
        rewardToken6Dec.initialize("Reward Token 6 Dec", "RT6", 6);
        rewardToken8Dec = new MockERC20();
        rewardToken8Dec.initialize("Reward Token 8 Dec", "RT8", 8);
        rewardToken18Dec = new MockERC20();
        rewardToken18Dec.initialize("Reward Token 18 Dec", "RT18", 18);

        // Create payment token with 18 decimals
        paymentToken18Dec = new MockERC20();
        paymentToken18Dec.initialize("Payment Token", "PT", 18);

        // Create mock Ark
        ArkParams memory params = ArkParams({
            name: "TestArk",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: address(paymentToken18Dec),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max
        });
        mockArk = new ArkMock(params);

        // Mint reward tokens for the mock Ark
        deal(address(rewardToken6Dec), address(mockArk), 1_000_000 * 10 ** 6);
        deal(address(rewardToken8Dec), address(mockArk), 1_000_000 * 10 ** 8);
        deal(address(rewardToken18Dec), address(mockArk), 1_000_000 * 10 ** 18);

        // Mint payment tokens for the buyer
        deal(address(paymentToken18Dec), buyer, 10_000_000 * 10 ** 18);

        vm.prank(buyer);
        paymentToken18Dec.approve(address(raft), type(uint256).max);

        vm.label(governor, "governor");
        vm.label(buyer, "buyer");
        vm.label(superKeeper, "superKeeper");
        vm.label(address(rewardToken6Dec), "rewardToken6Dec");
        vm.label(address(rewardToken8Dec), "rewardToken8Dec");
        vm.label(address(rewardToken18Dec), "rewardToken18Dec");
        vm.label(address(paymentToken18Dec), "paymentToken18Dec");
        vm.label(address(raft), "raft");
        vm.label(address(accessManager), "accessManager");
        vm.label(address(mockArk), "mockArk");
    }

    function testAuction6Dec() public {
        _runAuctionTest(rewardToken6Dec, 6);
    }

    function testAuction8Dec() public {
        _runAuctionTest(rewardToken8Dec, 8);
    }

    function testAuction18Dec() public {
        _runAuctionTest(rewardToken18Dec, 18);
    }

    function _runAuctionTest(MockERC20 rewardToken, uint8 decimals) internal {
        uint256 rewardAmount = 1_000_000 * 10 ** decimals;

        // Harvest rewards
        vm.prank(superKeeper);
        raft.harvest(
            address(mockArk),
            address(rewardToken),
            abi.encode(rewardAmount)
        );

        // Start auction
        vm.prank(superKeeper);
        raft.startAuction(
            address(mockArk),
            address(rewardToken),
            address(paymentToken18Dec)
        );

        // Test initial price (assuming 1:1 ratio for simplicity)
        uint256 currentPrice = raft.getCurrentPrice(
            address(mockArk),
            address(rewardToken)
        );

        assertEq(currentPrice, 1 ether, "Initial price incorrect");

        // Test price halfway through auction
        vm.warp(block.timestamp + AUCTION_DURATION / 2);
        currentPrice = raft.getCurrentPrice(
            address(mockArk),
            address(rewardToken)
        );

        assertApproxEqAbs(
            currentPrice,
            START_PRICE / 2,
            1,
            "Mid-auction price incorrect"
        );

        // Test buying tokens
        uint256 buyAmount = 100_000 * 10 ** decimals;
        vm.prank(buyer);
        uint256 tokensPaid = raft.buyTokens(
            address(mockArk),
            address(rewardToken),
            buyAmount
        );

        // Verify correct amount of tokens received
        assertEq(
            rewardToken.balanceOf(buyer),
            buyAmount,
            "Buyer did not receive correct amount of tokens"
        );

        // Test final price
        vm.warp(block.timestamp + AUCTION_DURATION / 2);
        currentPrice = raft.getCurrentPrice(
            address(mockArk),
            address(rewardToken)
        );
        assertEq(currentPrice, END_PRICE, "Final price incorrect");

        // Finalize auction
        raft.finalizeAuction(address(mockArk), address(rewardToken));

        // Verify unsold tokens
        uint256 kickerReward = rewardAmount.applyPercentage(
            Percentage.wrap(KICKER_REWARD_PERCENTAGE)
        );
        uint256 expectedUnsoldTokens = rewardAmount - buyAmount - kickerReward;

        assertEq(
            raft.unsoldTokens(address(mockArk), address(rewardToken)),
            expectedUnsoldTokens,
            "Incorrect amount of unsold tokens"
        );

        // Verify payment tokens boarded to Ark
        uint256 expectedBoardedAmount = tokensPaid;
        assertEq(
            paymentToken18Dec.balanceOf(address(mockArk)),
            expectedBoardedAmount,
            "Incorrect amount of payment tokens boarded to Ark"
        );
    }
}
