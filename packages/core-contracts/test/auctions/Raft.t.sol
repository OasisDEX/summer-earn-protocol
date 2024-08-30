// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";
import {Raft} from "../../src/contracts/Raft.sol";
import "../../src/errors/RaftErrors.sol";

import {IAuctionManagerBaseEvents} from "../../src/events/IAuctionManagerBaseEvents.sol";
import {IRaftEvents} from "../../src/events/IRaftEvents.sol";
import {IArk} from "../../src/interfaces/IArk.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ArkMock, ArkParams} from "../mocks/ArkMock.sol";
import "./AuctionTestBase.sol";

import {DutchAuctionErrors} from "@summerfi/dutch-auction/src/DutchAuctionErrors.sol";
import {DutchAuctionEvents} from "@summerfi/dutch-auction/src/DutchAuctionEvents.sol";
import {DutchAuctionLibrary} from "@summerfi/dutch-auction/src/DutchAuctionLibrary.sol";

contract RaftTest is AuctionTestBase, IRaftEvents {
    using PercentageUtils for uint256;

    Raft public raft;
    ArkMock public mockArk;
    MockERC20 public mockRewardToken;
    MockERC20 public mockPaymentToken;
    ConfigurationManager public configurationManager;

    uint256 constant REWARD_AMOUNT = 100000000;

    function setUp() public override {
        super.setUp();
        KICKER_REWARD_PERCENTAGE = 5 * 10 ** 18;
        defaultParams.kickerRewardPercentage = Percentage.wrap(
            KICKER_REWARD_PERCENTAGE
        );
        raft = new Raft(address(accessManager), defaultParams);

        configurationManager = new ConfigurationManager(
            ConfigurationManagerParams({
                accessManager: address(accessManager),
                raft: address(raft),
                tipJar: address(0)
            })
        );

        mockRewardToken = createMockToken("Reward Token", "RWD", 18);
        mockPaymentToken = createMockToken("Payment Token", "PAY", 18);

        ArkParams memory params = ArkParams({
            name: "TestArk",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: address(mockPaymentToken),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max
        });

        mockArk = new ArkMock(params);

        mintTokens(address(mockRewardToken), address(mockArk), REWARD_AMOUNT);
        mintTokens(address(mockPaymentToken), buyer, 10000000000 ether);

        vm.label(address(mockArk), "mockArk");
        vm.label(address(mockRewardToken), "mockRewardToken");
        vm.label(address(mockPaymentToken), "mockPaymentToken");
        vm.label(address(raft), "raft");
    }

    function test_Constructor() public {
        Raft newRaft = new Raft(address(accessManager), defaultParams);
        (
            uint40 duration,
            uint256 startPrice,
            uint256 endPrice,
            Percentage kickerRewardPercentage,
            DecayFunctions.DecayType decayType
        ) = newRaft.auctionDefaultParameters();
        assertEq(duration, AUCTION_DURATION);
        assertEq(startPrice, START_PRICE);
        assertEq(endPrice, END_PRICE);
        assertEq(
            Percentage.unwrap(kickerRewardPercentage),
            Percentage.unwrap(Percentage.wrap(KICKER_REWARD_PERCENTAGE))
        );
        assertEq(uint256(decayType), uint256(DecayFunctions.DecayType.Linear));
    }

    function test_Harvest() public {
        vm.expectEmit(true, true, true, true);
        emit ArkHarvested(address(mockArk), address(mockRewardToken));

        vm.prank(governor);
        raft.harvest(
            address(mockArk),
            address(mockRewardToken),
            abi.encode(REWARD_AMOUNT)
        );

        assertEq(
            raft.getHarvestedRewards(
                address(mockArk),
                address(mockRewardToken)
            ),
            REWARD_AMOUNT
        );
    }

    function test_HarvestAndStartAuction() public {
        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit ArkHarvested(address(mockArk), address(mockRewardToken));

        vm.expectEmit(true, true, true, true);
        emit DutchAuctionEvents.AuctionCreated(
            1,
            governor,
            REWARD_AMOUNT -
                REWARD_AMOUNT.applyPercentage(
                    Percentage.wrap(KICKER_REWARD_PERCENTAGE)
                ),
            REWARD_AMOUNT.applyPercentage(
                Percentage.wrap(KICKER_REWARD_PERCENTAGE)
            )
        );

        raft.harvestAndStartAuction(
            address(mockArk),
            address(mockRewardToken),
            address(mockPaymentToken),
            abi.encode(REWARD_AMOUNT)
        );

        (, DutchAuctionLibrary.AuctionState memory state) = raft.auctions(
            address(mockArk),
            address(mockRewardToken)
        );
        assertEq(
            state.remainingTokens,
            REWARD_AMOUNT -
                REWARD_AMOUNT.applyPercentage(
                    Percentage.wrap(KICKER_REWARD_PERCENTAGE)
                )
        );
    }

    function test_MultipleAuctionsCycle() public {
        // First auction cycle
        _setupAuction();

        uint256 firstAuctionAmount = REWARD_AMOUNT -
            REWARD_AMOUNT.applyPercentage(
                Percentage.wrap(KICKER_REWARD_PERCENTAGE)
            );
        uint256 currentPrice = raft.getCurrentPrice(
            address(mockArk),
            address(mockRewardToken)
        );
        uint256 firstAuctionAmountToSpend = (firstAuctionAmount *
            currentPrice) / 1e18;
        // Buy all tokens in the first auction
        vm.startPrank(buyer);
        mockPaymentToken.approve(address(raft), firstAuctionAmountToSpend);
        raft.buyTokens(
            address(mockArk),
            address(mockRewardToken),
            firstAuctionAmount
        );
        vm.stopPrank();

        // Verify first auction is finalized
        (, DutchAuctionLibrary.AuctionState memory state) = raft.auctions(
            address(mockArk),
            address(mockRewardToken)
        );
        assertTrue(state.isFinalized, "First auction should be finalized");
        assertEq(
            state.remainingTokens,
            0,
            "First auction should have no remaining tokens"
        );

        // Verify rewards were boarded
        assertEq(
            mockPaymentToken.balanceOf(address(mockArk)),
            firstAuctionAmountToSpend,
            "Rewards should be boarded"
        );

        // Second harvest and auction cycle
        uint256 secondHarvestAmount = 150; // Different amount for the second harvest
        deal(address(mockRewardToken), address(mockArk), secondHarvestAmount);

        vm.startPrank(governor);
        vm.expectEmit(true, true, true, true);
        emit ArkHarvested(address(mockArk), address(mockRewardToken));

        raft.harvest(
            address(mockArk),
            address(mockRewardToken),
            abi.encode(secondHarvestAmount)
        );

        // Start second auction
        vm.expectEmit(true, true, true, true);
        emit DutchAuctionEvents.AuctionCreated(
            2, // This should be the next auction ID
            governor,
            secondHarvestAmount -
                secondHarvestAmount.applyPercentage(
                    Percentage.wrap(KICKER_REWARD_PERCENTAGE)
                ),
            secondHarvestAmount.applyPercentage(
                Percentage.wrap(KICKER_REWARD_PERCENTAGE)
            )
        );

        raft.startAuction(
            address(mockArk),
            address(mockRewardToken),
            address(mockPaymentToken)
        );
        vm.stopPrank();

        // Verify second auction setup
        (
            DutchAuctionLibrary.AuctionConfig memory config,
            DutchAuctionLibrary.AuctionState memory newState
        ) = raft.auctions(address(mockArk), address(mockRewardToken));

        assertEq(config.id, 2, "Should be the second auction ID");
        assertEq(
            config.totalTokens,
            secondHarvestAmount -
                secondHarvestAmount.applyPercentage(
                    Percentage.wrap(KICKER_REWARD_PERCENTAGE)
                ),
            "Should have the correct total tokens"
        );
        assertEq(
            newState.remainingTokens,
            secondHarvestAmount -
                secondHarvestAmount.applyPercentage(
                    Percentage.wrap(KICKER_REWARD_PERCENTAGE)
                ),
            "Should have the correct remaining tokens"
        );
        assertFalse(newState.isFinalized, "Should not be finalized");

        // Buy half of the tokens in the second auction
        uint256 secondAuctionBuyAmount = (secondHarvestAmount -
            secondHarvestAmount.applyPercentage(
                Percentage.wrap(KICKER_REWARD_PERCENTAGE)
            )) / 2;
        currentPrice = raft.getCurrentPrice(
            address(mockArk),
            address(mockRewardToken)
        );
        uint256 secondAuctionAmountToSpend = (secondAuctionBuyAmount *
            currentPrice) / 1e18;
        vm.startPrank(buyer);
        mockPaymentToken.approve(address(raft), secondAuctionAmountToSpend);
        raft.buyTokens(
            address(mockArk),
            address(mockRewardToken),
            secondAuctionBuyAmount
        );
        vm.stopPrank();

        // Finalize the second auction
        vm.warp(block.timestamp + 8 days);
        raft.finalizeAuction(address(mockArk), address(mockRewardToken));

        // Verify final state
        (, DutchAuctionLibrary.AuctionState memory finalState) = raft.auctions(
            address(mockArk),
            address(mockRewardToken)
        );
        assertTrue(finalState.isFinalized, "Should be finalized");

        assertEq(
            finalState.remainingTokens,
            secondHarvestAmount -
                secondHarvestAmount.applyPercentage(
                    Percentage.wrap(KICKER_REWARD_PERCENTAGE)
                ) -
                secondAuctionBuyAmount,
            "Should have the correct remaining tokens"
        );

        // Verify unsold tokens
        assertEq(
            raft.unsoldTokens(address(mockArk), address(mockRewardToken)),
            secondHarvestAmount -
                secondHarvestAmount.applyPercentage(
                    Percentage.wrap(KICKER_REWARD_PERCENTAGE)
                ) -
                secondAuctionBuyAmount,
            "Should have unsold tokens"
        );

        // Verify total rewards boarded
        assertEq(
            mockPaymentToken.balanceOf(address(mockArk)),
            firstAuctionAmountToSpend + secondAuctionAmountToSpend,
            "Should have total rewards boarded"
        );
    }

    function test_MultipleAuctionsCycleWithUnsoldTokens() public {
        // First auction cycle
        _setupAuction();

        uint256 firstAuctionTotalAmount = REWARD_AMOUNT -
            REWARD_AMOUNT.applyPercentage(
                Percentage.wrap(KICKER_REWARD_PERCENTAGE)
            );
        uint256 firstAuctionBuyAmount = firstAuctionTotalAmount / 2; // Buy only half of the tokens
        uint256 currentPrice = raft.getCurrentPrice(
            address(mockArk),
            address(mockRewardToken)
        );
        uint256 firstAuctionBuyAmountToSpend = (firstAuctionBuyAmount *
            currentPrice) / 1e18;

        // Buy half of the tokens in the first auction
        vm.startPrank(buyer);
        mockPaymentToken.approve(address(raft), firstAuctionBuyAmountToSpend);
        raft.buyTokens(
            address(mockArk),
            address(mockRewardToken),
            firstAuctionBuyAmount
        );
        vm.stopPrank();

        // Finalize the first auction after some time
        vm.warp(block.timestamp + 8 days);
        raft.finalizeAuction(address(mockArk), address(mockRewardToken));

        // Verify first auction is finalized with unsold tokens
        (, DutchAuctionLibrary.AuctionState memory state) = raft.auctions(
            address(mockArk),
            address(mockRewardToken)
        );
        assertTrue(state.isFinalized, "First auction should be finalized");
        assertEq(
            state.remainingTokens,
            firstAuctionTotalAmount - firstAuctionBuyAmount,
            "First auction should have remaining tokens"
        );

        // Verify rewards were boarded and unsold tokens are recorded
        assertEq(
            mockPaymentToken.balanceOf(address(mockArk)),
            firstAuctionBuyAmountToSpend,
            "Partial rewards should be boarded"
        );
        assertEq(
            mockRewardToken.balanceOf(address(mockArk)),
            0,
            "All rewards should be harvested"
        );
        assertEq(
            mockRewardToken.balanceOf(address(raft)),
            firstAuctionTotalAmount - firstAuctionBuyAmount,
            "Half of rewards should be auctioned"
        );
        assertEq(
            raft.unsoldTokens(address(mockArk), address(mockRewardToken)),
            firstAuctionTotalAmount - firstAuctionBuyAmount,
            "Unsold tokens should be recorded"
        );

        // Second harvest and auction cycle
        uint256 secondHarvestAmount = 1500000000; // Different amount for the second harvest
        deal(address(mockRewardToken), address(mockArk), secondHarvestAmount);

        vm.startPrank(governor);
        vm.expectEmit(true, true, true, true);
        emit ArkHarvested(address(mockArk), address(mockRewardToken));

        raft.harvest(
            address(mockArk),
            address(mockRewardToken),
            abi.encode(secondHarvestAmount)
        );

        // Calculate total tokens for second auction (new harvest + unsold tokens from first auction)
        uint256 secondAuctionTotalAmount = secondHarvestAmount +
            (firstAuctionTotalAmount - firstAuctionBuyAmount);

        // Start second auction
        vm.expectEmit(true, true, true, true);
        emit DutchAuctionEvents.AuctionCreated(
            2, // This should be the next auction ID
            governor,
            secondAuctionTotalAmount -
                secondAuctionTotalAmount.applyPercentage(
                    Percentage.wrap(KICKER_REWARD_PERCENTAGE)
                ),
            secondAuctionTotalAmount.applyPercentage(
                Percentage.wrap(KICKER_REWARD_PERCENTAGE)
            )
        );

        raft.startAuction(
            address(mockArk),
            address(mockRewardToken),
            address(mockPaymentToken)
        );
        vm.stopPrank();

        // Verify second auction setup
        (
            DutchAuctionLibrary.AuctionConfig memory config,
            DutchAuctionLibrary.AuctionState memory newState
        ) = raft.auctions(address(mockArk), address(mockRewardToken));

        assertEq(config.id, 2, "Should be the second auction ID");
        assertEq(
            config.totalTokens,
            secondAuctionTotalAmount -
                secondAuctionTotalAmount.applyPercentage(
                    Percentage.wrap(KICKER_REWARD_PERCENTAGE)
                ),
            "Should have the correct total tokens including unsold from first auction"
        );
        assertEq(
            newState.remainingTokens,
            secondAuctionTotalAmount -
                secondAuctionTotalAmount.applyPercentage(
                    Percentage.wrap(KICKER_REWARD_PERCENTAGE)
                ),
            "Should have the correct remaining tokens"
        );
        assertFalse(newState.isFinalized, "Should not be finalized");

        // Buy all tokens in the second auction
        uint256 secondAuctionBuyAmount = secondAuctionTotalAmount -
            secondAuctionTotalAmount.applyPercentage(
                Percentage.wrap(KICKER_REWARD_PERCENTAGE)
            );
        currentPrice = raft.getCurrentPrice(
            address(mockArk),
            address(mockRewardToken)
        );
        uint256 secondAuctionBuyAmountToSpend = (secondAuctionBuyAmount *
            currentPrice) / 1e18;
        vm.startPrank(buyer);
        mockPaymentToken.approve(address(raft), secondAuctionBuyAmountToSpend);
        raft.buyTokens(
            address(mockArk),
            address(mockRewardToken),
            secondAuctionBuyAmount
        );
        vm.stopPrank();

        // Verify final state
        (, DutchAuctionLibrary.AuctionState memory finalState) = raft.auctions(
            address(mockArk),
            address(mockRewardToken)
        );
        assertTrue(finalState.isFinalized, "Should be finalized");
        assertEq(
            finalState.remainingTokens,
            0,
            "Should have no remaining tokens"
        );

        // Verify unsold tokens
        assertEq(
            raft.unsoldTokens(address(mockArk), address(mockRewardToken)),
            0,
            "Should have no unsold tokens"
        );

        // Verify total rewards boarded
        assertEq(
            mockPaymentToken.balanceOf(address(mockArk)),
            firstAuctionBuyAmountToSpend + secondAuctionBuyAmountToSpend,
            "Should have total rewards boarded from both auctions"
        );
    }

    function test_StartAuction() public {
        vm.prank(governor);
        raft.harvest(
            address(mockArk),
            address(mockRewardToken),
            abi.encode(REWARD_AMOUNT)
        );

        vm.expectEmit(true, true, true, true);
        emit DutchAuctionEvents.AuctionCreated(
            1,
            governor,
            REWARD_AMOUNT -
                REWARD_AMOUNT.applyPercentage(
                    Percentage.wrap(KICKER_REWARD_PERCENTAGE)
                ),
            REWARD_AMOUNT.applyPercentage(
                Percentage.wrap(KICKER_REWARD_PERCENTAGE)
            )
        );

        vm.prank(governor);
        raft.startAuction(
            address(mockArk),
            address(mockRewardToken),
            address(mockPaymentToken)
        );

        (, DutchAuctionLibrary.AuctionState memory state) = raft.auctions(
            address(mockArk),
            address(mockRewardToken)
        );
        assertEq(
            state.remainingTokens,
            REWARD_AMOUNT -
                REWARD_AMOUNT.applyPercentage(
                    Percentage.wrap(KICKER_REWARD_PERCENTAGE)
                )
        );
    }

    function test_BuyTokens() public {
        _setupAuction();

        uint256 buyAmount = 50;
        uint256 currentPrice = raft.getCurrentPrice(
            address(mockArk),
            address(mockRewardToken)
        );
        uint256 amountToSpend = (buyAmount * currentPrice) / 1e18;
        vm.startPrank(buyer);
        mockPaymentToken.approve(address(raft), amountToSpend);
        raft.buyTokens(address(mockArk), address(mockRewardToken), buyAmount);
        vm.stopPrank();

        (, DutchAuctionLibrary.AuctionState memory state) = raft.auctions(
            address(mockArk),
            address(mockRewardToken)
        );
        assertEq(
            state.remainingTokens,
            REWARD_AMOUNT -
                buyAmount -
                REWARD_AMOUNT.applyPercentage(
                    Percentage.wrap(KICKER_REWARD_PERCENTAGE)
                )
        );
    }

    function test_FinalizeAuction() public {
        _setupAuction();

        // Warp to after auction end time
        vm.warp(block.timestamp + 8 days);

        raft.finalizeAuction(address(mockArk), address(mockRewardToken));

        (, DutchAuctionLibrary.AuctionState memory state) = raft.auctions(
            address(mockArk),
            address(mockRewardToken)
        );
        assertTrue(state.isFinalized);
    }

    function test_BuyAllAndSettleAuction() public {
        _setupAuction();
        uint256 currentPrice = raft.getCurrentPrice(
            address(mockArk),
            address(mockRewardToken)
        );
        uint256 buyAmount = REWARD_AMOUNT -
            REWARD_AMOUNT.applyPercentage(
                Percentage.wrap(KICKER_REWARD_PERCENTAGE)
            );
        uint256 amountToSpend = (buyAmount * currentPrice) / 1e18;

        vm.startPrank(buyer);
        mockPaymentToken.approve(address(raft), amountToSpend);
        vm.expectEmit(true, true, true, true);
        emit RewardBoarded(
            address(mockArk),
            address(mockRewardToken),
            address(mockPaymentToken),
            amountToSpend
        );
        raft.buyTokens(address(mockArk), address(mockRewardToken), buyAmount);
        vm.stopPrank();

        (, DutchAuctionLibrary.AuctionState memory state) = raft.auctions(
            address(mockArk),
            address(mockRewardToken)
        );
        assertTrue(state.isFinalized);
    }

    function test_UpdateAuctionConfig() public {
        AuctionDefaultParameters memory newConfig = AuctionDefaultParameters({
            duration: 2 days,
            startPrice: 2e18,
            endPrice: 2,
            kickerRewardPercentage: PercentageUtils.fromIntegerPercentage(10),
            decayType: DecayFunctions.DecayType.Exponential
        });

        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit IAuctionManagerBaseEvents.AuctionDefaultParametersUpdated(
            newConfig
        );

        raft.updateAuctionDefaultParameters(newConfig);

        (
            uint40 duration,
            uint256 startPrice,
            uint256 endPrice,
            Percentage kickerRewardPercentage,
            DecayFunctions.DecayType decayType
        ) = raft.auctionDefaultParameters();
        assertEq(duration, newConfig.duration);
        assertEq(startPrice, newConfig.startPrice);
        assertEq(endPrice, newConfig.endPrice);
        assertEq(
            Percentage.unwrap(kickerRewardPercentage),
            Percentage.unwrap(newConfig.kickerRewardPercentage)
        );
        assertEq(uint256(decayType), uint256(newConfig.decayType));
    }

    function test_CannotStartAuctionTwice() public {
        _setupAuction();

        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                RaftAuctionAlreadyRunning.selector,
                address(mockArk),
                address(mockRewardToken)
            )
        );
        raft.startAuction(
            address(mockArk),
            address(mockRewardToken),
            address(mockPaymentToken)
        );
    }

    function test_CannotStartAuctionWithNoTokens() public {
        vm.prank(governor);
        vm.expectRevert(DutchAuctionErrors.InvalidTokenAmount.selector);
        raft.startAuction(
            address(mockArk),
            address(mockRewardToken),
            address(mockPaymentToken)
        );
    }

    function test_CannotFinalizeAuctionBeforeEndTime() public {
        _setupAuction();

        vm.expectRevert(abi.encodeWithSignature("AuctionNotEnded(uint256)", 1));
        raft.finalizeAuction(address(mockArk), address(mockRewardToken));
    }

    function test_UnsoldTokensHandling() public {
        _setupAuction();

        // Buy half of the tokens
        uint256 buyAmount = (REWARD_AMOUNT -
            REWARD_AMOUNT.applyPercentage(
                Percentage.wrap(KICKER_REWARD_PERCENTAGE)
            )) / 2;
        uint256 currentPrice = raft.getCurrentPrice(
            address(mockArk),
            address(mockRewardToken)
        );
        uint256 buyAmountToSpend = (buyAmount * currentPrice) / 1e18;
        vm.startPrank(buyer);
        mockPaymentToken.approve(address(raft), buyAmountToSpend);
        raft.buyTokens(address(mockArk), address(mockRewardToken), buyAmount);
        vm.stopPrank();

        // Finalize the auction
        vm.warp(block.timestamp + 8 days);
        raft.finalizeAuction(address(mockArk), address(mockRewardToken));

        // Check unsold tokens
        uint256 expectedUnsoldTokens = REWARD_AMOUNT -
            REWARD_AMOUNT.applyPercentage(
                Percentage.wrap(KICKER_REWARD_PERCENTAGE)
            ) -
            buyAmount;
        assertEq(
            raft.unsoldTokens(address(mockArk), address(mockRewardToken)),
            expectedUnsoldTokens
        );
    }

    function test_GetAuctionInfo() public {
        // Setup the auction
        _setupAuction();

        // Get the auction info
        DutchAuctionLibrary.Auction memory auctionInfo = raft.getAuctionInfo(
            address(mockArk),
            address(mockRewardToken)
        );

        // Verify the auction config
        assertEq(auctionInfo.config.id, 1, "Auction ID should be 1");
        assertEq(
            address(auctionInfo.config.auctionToken),
            address(mockRewardToken),
            "Auction token should be mockRewardToken"
        );
        assertEq(
            address(auctionInfo.config.paymentToken),
            address(mockPaymentToken),
            "Payment token should be mockPaymentToken"
        );
        assertEq(
            auctionInfo.config.totalTokens,
            REWARD_AMOUNT -
                REWARD_AMOUNT.applyPercentage(
                    Percentage.wrap(KICKER_REWARD_PERCENTAGE)
                ),
            "Total tokens should be correct"
        );
        assertEq(
            auctionInfo.config.startTime,
            block.timestamp,
            "Start time should be current block timestamp"
        );
        assertEq(
            auctionInfo.config.endTime,
            block.timestamp + AUCTION_DURATION,
            "End time should be start time + duration"
        );
        assertEq(
            auctionInfo.config.startPrice,
            START_PRICE,
            "Start price should be correct"
        );
        assertEq(
            auctionInfo.config.endPrice,
            END_PRICE,
            "End price should be correct"
        );
        assertEq(
            uint8(auctionInfo.config.decayType),
            uint8(DecayFunctions.DecayType.Linear),
            "Decay type should be Linear"
        );

        // Verify the auction state
        assertEq(
            auctionInfo.state.remainingTokens,
            REWARD_AMOUNT -
                REWARD_AMOUNT.applyPercentage(
                    Percentage.wrap(KICKER_REWARD_PERCENTAGE)
                ),
            "Remaining tokens should be total tokens"
        );
        assertFalse(
            auctionInfo.state.isFinalized,
            "Auction should not be finalized"
        );

        // Buy some tokens
        uint256 buyAmount = 1000;
        uint256 currentPrice = raft.getCurrentPrice(
            address(mockArk),
            address(mockRewardToken)
        );
        uint256 amountToSpend = (buyAmount * currentPrice) / 1e18;

        vm.startPrank(buyer);
        mockPaymentToken.approve(address(raft), amountToSpend);
        raft.buyTokens(address(mockArk), address(mockRewardToken), buyAmount);
        vm.stopPrank();

        // Get the updated auction info
        auctionInfo = raft.getAuctionInfo(
            address(mockArk),
            address(mockRewardToken)
        );

        // Verify the updated state
        assertEq(
            auctionInfo.state.remainingTokens,
            REWARD_AMOUNT -
                REWARD_AMOUNT.applyPercentage(
                    Percentage.wrap(KICKER_REWARD_PERCENTAGE)
                ) -
                buyAmount,
            "Remaining tokens should be updated"
        );
        assertFalse(
            auctionInfo.state.isFinalized,
            "Auction should still not be finalized"
        );

        // Finalize the auction
        vm.warp(block.timestamp + AUCTION_DURATION + 1);
        raft.finalizeAuction(address(mockArk), address(mockRewardToken));

        // Get the final auction info
        auctionInfo = raft.getAuctionInfo(
            address(mockArk),
            address(mockRewardToken)
        );

        // Verify the final state
        assertTrue(
            auctionInfo.state.isFinalized,
            "Auction should be finalized"
        );
    }

    function _setupAuction() internal {
        vm.startPrank(governor);
        raft.harvest(
            address(mockArk),
            address(mockRewardToken),
            abi.encode(REWARD_AMOUNT)
        );
        raft.startAuction(
            address(mockArk),
            address(mockRewardToken),
            address(mockPaymentToken)
        );
        vm.stopPrank();
    }
}
