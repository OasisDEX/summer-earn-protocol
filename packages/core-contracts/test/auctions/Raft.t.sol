// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";
import {Raft} from "../../src/contracts/Raft.sol";
import "../../src/errors/IRaftErrors.sol";

import {IAuctionManagerBaseEvents} from "../../src/events/IAuctionManagerBaseEvents.sol";
import {IRaftEvents} from "../../src/events/IRaftEvents.sol";
import {IArk} from "../../src/interfaces/IArk.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ArkMock, ArkParams} from "../mocks/ArkMock.sol";
import "./AuctionTestBase.sol";

import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {DutchAuctionErrors} from "@summerfi/dutch-auction/DutchAuctionErrors.sol";

import {DutchAuctionEvents} from "@summerfi/dutch-auction/DutchAuctionEvents.sol";
import {DutchAuctionLibrary} from "@summerfi/dutch-auction/DutchAuctionLibrary.sol";

import {console} from "forge-std/console.sol";

contract RaftTest is AuctionTestBase, IRaftEvents {
    using PercentageUtils for uint256;

    Raft public raftContract;
    ERC20Mock public mockRewardToken;
    ERC20Mock public mockRewardToken2;
    ERC20Mock public mockPaymentToken;

    uint256 constant REWARD_AMOUNT = 100000000;

    function setUp() public override {
        super.setUp();

        KICKER_REWARD_PERCENTAGE = 5 * 10 ** 18;
        defaultParams.kickerRewardPercentage = Percentage.wrap(
            KICKER_REWARD_PERCENTAGE
        );
        raftContract = new Raft(address(accessManager));

        vm.startPrank(governor);
        configurationManager.setRaft(address(raftContract));
        accessManager.grantSuperKeeperRole(address(governor));
        vm.stopPrank();

        mockRewardToken = createMockToken("Reward Token", "RWD", 18);
        mockRewardToken2 = createMockToken("Reward Token 2", "RWD2", 18);
        mockPaymentToken = mockToken;

        vm.startPrank(governor);
        raftContract.setArkAuctionParameters(
            address(mockArk1),
            address(mockRewardToken),
            defaultParams
        );
        raftContract.setArkAuctionParameters(
            address(mockArk1),
            address(mockRewardToken2),
            defaultParams
        );
        vm.stopPrank();

        mintTokens(address(mockRewardToken), address(mockArk1), REWARD_AMOUNT);
        mintTokens(
            address(mockRewardToken2),
            address(mockArk1),
            REWARD_AMOUNT * 2
        );
        mintTokens(address(mockPaymentToken), buyer, 10000000000 ether);

        vm.label(address(mockArk1), "mockArk1");
        vm.label(address(mockRewardToken), "mockRewardToken");
        vm.label(address(mockRewardToken2), "mockRewardToken2");
        vm.label(address(mockPaymentToken), "mockPaymentToken");
        vm.label(address(raftContract), "raftContract");
    }

    function test_Constructor() public {
        Raft newRaft = new Raft(address(accessManager));
        vm.startPrank(governor);
        newRaft.setArkAuctionParameters(
            address(mockArk1),
            address(mockRewardToken),
            defaultParams
        );
        vm.stopPrank();
        (
            uint40 duration,
            uint256 startPrice,
            uint256 endPrice,
            Percentage kickerRewardPercentage,
            DecayFunctions.DecayType decayType
        ) = newRaft.arkAuctionParameters(
                address(mockArk1),
                address(mockRewardToken)
            );

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
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = address(mockRewardToken);
        uint256[] memory rewardAmounts = new uint256[](1);
        rewardAmounts[0] = REWARD_AMOUNT;

        emit ArkHarvested(address(mockArk1), rewardTokens, rewardAmounts);

        vm.prank(governor);
        raftContract.harvest(
            address(mockArk1),
            _getEncodedRewardData(rewardTokens, rewardAmounts)
        );

        assertEq(
            raftContract.obtainedTokens(
                address(mockArk1),
                address(mockRewardToken)
            ),
            REWARD_AMOUNT
        );
    }

    function test_HarvestAndStartAuction() public {
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = address(mockRewardToken);
        uint256[] memory rewardAmounts = new uint256[](1);
        rewardAmounts[0] = REWARD_AMOUNT;

        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit ArkHarvested(address(mockArk1), rewardTokens, rewardAmounts);
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

        raftContract.harvestAndStartAuction(
            address(mockArk1),
            _getEncodedRewardData(rewardTokens, rewardAmounts)
        );

        (, DutchAuctionLibrary.AuctionState memory state) = raftContract
            .auctions(address(mockArk1), address(mockRewardToken));
        assertEq(
            state.remainingTokens,
            REWARD_AMOUNT -
                REWARD_AMOUNT.applyPercentage(
                    Percentage.wrap(KICKER_REWARD_PERCENTAGE)
                )
        );
    }

    function test_HarvestMultipleTokensAndStartAuction() public {
        address[] memory rewardTokens = new address[](2);
        rewardTokens[0] = address(mockRewardToken);
        rewardTokens[1] = address(mockRewardToken2);
        uint256[] memory rewardAmounts = new uint256[](2);
        rewardAmounts[0] = REWARD_AMOUNT;
        rewardAmounts[1] = REWARD_AMOUNT * 2;

        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit ArkHarvested(address(mockArk1), rewardTokens, rewardAmounts);
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
        emit DutchAuctionEvents.AuctionCreated(
            2,
            governor,
            2 *
                REWARD_AMOUNT -
                2 *
                REWARD_AMOUNT.applyPercentage(
                    Percentage.wrap(KICKER_REWARD_PERCENTAGE)
                ),
            2 *
                REWARD_AMOUNT.applyPercentage(
                    Percentage.wrap(KICKER_REWARD_PERCENTAGE)
                )
        );

        raftContract.harvestAndStartAuction(
            address(mockArk1),
            _getEncodedRewardData(rewardTokens, rewardAmounts)
        );

        (, DutchAuctionLibrary.AuctionState memory state) = raftContract
            .auctions(address(mockArk1), address(mockRewardToken));
        assertEq(
            state.remainingTokens,
            REWARD_AMOUNT -
                REWARD_AMOUNT.applyPercentage(
                    Percentage.wrap(KICKER_REWARD_PERCENTAGE)
                )
        );

        (, DutchAuctionLibrary.AuctionState memory state2) = raftContract
            .auctions(address(mockArk1), address(mockRewardToken2));

        assertEq(
            state2.remainingTokens,
            2 *
                REWARD_AMOUNT -
                2 *
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
        uint256 currentPrice = raftContract.getCurrentPrice(
            address(mockArk1),
            address(mockRewardToken)
        );
        uint256 firstAuctionAmountToSpend = (firstAuctionAmount *
            currentPrice) / 1e18;
        // Buy all tokens in the first auction
        vm.startPrank(buyer);
        mockPaymentToken.approve(
            address(raftContract),
            firstAuctionAmountToSpend
        );
        raftContract.buyTokens(
            address(mockArk1),
            address(mockRewardToken),
            firstAuctionAmount
        );

        vm.stopPrank();

        // Verify first auction is finalized
        (, DutchAuctionLibrary.AuctionState memory state) = raftContract
            .auctions(address(mockArk1), address(mockRewardToken));
        assertTrue(state.isFinalized, "First auction should be finalized");
        assertEq(
            state.remainingTokens,
            0,
            "First auction should have no remaining tokens"
        );

        // Verify rewards were boarded
        assertEq(
            mockPaymentToken.balanceOf(address(mockArk1)),
            firstAuctionAmountToSpend,
            "Rewards should be boarded"
        );

        // Second harvest and auction cycle
        uint256 secondHarvestAmount = 150; // Different amount for the second harvest
        deal(address(mockRewardToken), address(mockArk1), secondHarvestAmount);

        vm.startPrank(governor);
        vm.expectEmit(true, true, true, true);
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = address(mockRewardToken);
        uint256[] memory rewardAmounts = new uint256[](1);
        rewardAmounts[0] = secondHarvestAmount;

        emit ArkHarvested(address(mockArk1), rewardTokens, rewardAmounts);

        raftContract.harvest(
            address(mockArk1),
            _getEncodedRewardData(rewardTokens, rewardAmounts)
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

        raftContract.startAuction(address(mockArk1), address(mockRewardToken));
        vm.stopPrank();

        // Verify second auction setup
        (
            DutchAuctionLibrary.AuctionConfig memory config,
            DutchAuctionLibrary.AuctionState memory newState
        ) = raftContract.auctions(address(mockArk1), address(mockRewardToken));

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
        currentPrice = raftContract.getCurrentPrice(
            address(mockArk1),
            address(mockRewardToken)
        );
        uint256 secondAuctionAmountToSpend = (secondAuctionBuyAmount *
            currentPrice) / 1e18;
        vm.startPrank(buyer);
        mockPaymentToken.approve(
            address(raftContract),
            secondAuctionAmountToSpend
        );
        raftContract.buyTokens(
            address(mockArk1),
            address(mockRewardToken),
            secondAuctionBuyAmount
        );
        vm.stopPrank();

        // Finalize the second auction
        vm.warp(block.timestamp + 8 days);
        raftContract.finalizeAuction(
            address(mockArk1),
            address(mockRewardToken)
        );

        // Verify final state
        (, DutchAuctionLibrary.AuctionState memory finalState) = raftContract
            .auctions(address(mockArk1), address(mockRewardToken));
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
            raftContract.unsoldTokens(
                address(mockArk1),
                address(mockRewardToken)
            ),
            secondHarvestAmount -
                secondHarvestAmount.applyPercentage(
                    Percentage.wrap(KICKER_REWARD_PERCENTAGE)
                ) -
                secondAuctionBuyAmount,
            "Should have unsold tokens"
        );

        // Verify total rewards boarded
        assertEq(
            mockPaymentToken.balanceOf(address(mockArk1)),
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
        uint256 currentPrice = raftContract.getCurrentPrice(
            address(mockArk1),
            address(mockRewardToken)
        );
        uint256 firstAuctionBuyAmountToSpend = (firstAuctionBuyAmount *
            currentPrice) / 1e18;

        // Buy half of the tokens in the first auction
        vm.startPrank(buyer);
        mockPaymentToken.approve(
            address(raftContract),
            firstAuctionBuyAmountToSpend
        );
        raftContract.buyTokens(
            address(mockArk1),
            address(mockRewardToken),
            firstAuctionBuyAmount
        );
        vm.stopPrank();

        // Finalize the first auction after some time
        vm.warp(block.timestamp + 8 days);
        raftContract.finalizeAuction(
            address(mockArk1),
            address(mockRewardToken)
        );

        // Verify first auction is finalized with unsold tokens
        (, DutchAuctionLibrary.AuctionState memory state) = raftContract
            .auctions(address(mockArk1), address(mockRewardToken));
        assertTrue(state.isFinalized, "First auction should be finalized");
        assertEq(
            state.remainingTokens,
            firstAuctionTotalAmount - firstAuctionBuyAmount,
            "First auction should have remaining tokens"
        );

        // Verify rewards were boarded and unsold tokens are recorded
        assertEq(
            mockPaymentToken.balanceOf(address(mockArk1)),
            firstAuctionBuyAmountToSpend,
            "Partial rewards should be boarded"
        );
        assertEq(
            mockRewardToken.balanceOf(address(mockArk1)),
            0,
            "All rewards should be harvested"
        );
        assertEq(
            mockRewardToken.balanceOf(address(raftContract)),
            firstAuctionTotalAmount - firstAuctionBuyAmount,
            "Half of rewards should be auctioned"
        );
        assertEq(
            raftContract.unsoldTokens(
                address(mockArk1),
                address(mockRewardToken)
            ),
            firstAuctionTotalAmount - firstAuctionBuyAmount,
            "Unsold tokens should be recorded"
        );

        // Second harvest and auction cycle
        uint256 secondHarvestAmount = 1500000000; // Different amount for the second harvest
        deal(address(mockRewardToken), address(mockArk1), secondHarvestAmount);

        vm.startPrank(governor);
        vm.expectEmit(true, true, true, true);
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = address(mockRewardToken);
        uint256[] memory rewardAmounts = new uint256[](1);
        rewardAmounts[0] = secondHarvestAmount;

        emit ArkHarvested(address(mockArk1), rewardTokens, rewardAmounts);

        raftContract.harvest(
            address(mockArk1),
            _getEncodedRewardData(rewardTokens, rewardAmounts)
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

        raftContract.startAuction(address(mockArk1), address(mockRewardToken));
        vm.stopPrank();

        // Verify second auction setup
        (
            DutchAuctionLibrary.AuctionConfig memory config,
            DutchAuctionLibrary.AuctionState memory newState
        ) = raftContract.auctions(address(mockArk1), address(mockRewardToken));

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
        currentPrice = raftContract.getCurrentPrice(
            address(mockArk1),
            address(mockRewardToken)
        );
        uint256 secondAuctionBuyAmountToSpend = (secondAuctionBuyAmount *
            currentPrice) / 1e18;
        vm.startPrank(buyer);
        mockPaymentToken.approve(
            address(raftContract),
            secondAuctionBuyAmountToSpend
        );
        raftContract.buyTokens(
            address(mockArk1),
            address(mockRewardToken),
            secondAuctionBuyAmount
        );
        vm.stopPrank();

        // Verify final state
        (, DutchAuctionLibrary.AuctionState memory finalState) = raftContract
            .auctions(address(mockArk1), address(mockRewardToken));
        assertTrue(finalState.isFinalized, "Should be finalized");
        assertEq(
            finalState.remainingTokens,
            0,
            "Should have no remaining tokens"
        );

        // Verify unsold tokens
        assertEq(
            raftContract.unsoldTokens(
                address(mockArk1),
                address(mockRewardToken)
            ),
            0,
            "Should have no unsold tokens"
        );

        // Verify total rewards boarded
        assertEq(
            mockPaymentToken.balanceOf(address(mockArk1)),
            firstAuctionBuyAmountToSpend + secondAuctionBuyAmountToSpend,
            "Should have total rewards boarded from both auctions"
        );
    }

    function test_StartAuction() public {
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = address(mockRewardToken);
        uint256[] memory rewardAmounts = new uint256[](1);
        rewardAmounts[0] = REWARD_AMOUNT;

        vm.prank(governor);
        raftContract.harvest(
            address(mockArk1),
            _getEncodedRewardData(rewardTokens, rewardAmounts)
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
        raftContract.startAuction(address(mockArk1), address(mockRewardToken));

        (, DutchAuctionLibrary.AuctionState memory state) = raftContract
            .auctions(address(mockArk1), address(mockRewardToken));
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
        uint256 currentPrice = raftContract.getCurrentPrice(
            address(mockArk1),
            address(mockRewardToken)
        );
        uint256 amountToSpend = (buyAmount * currentPrice) / 1e18;
        vm.startPrank(buyer);
        mockPaymentToken.approve(address(raftContract), amountToSpend);
        raftContract.buyTokens(
            address(mockArk1),
            address(mockRewardToken),
            buyAmount
        );
        vm.stopPrank();

        (, DutchAuctionLibrary.AuctionState memory state) = raftContract
            .auctions(address(mockArk1), address(mockRewardToken));
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

        raftContract.finalizeAuction(
            address(mockArk1),
            address(mockRewardToken)
        );

        (, DutchAuctionLibrary.AuctionState memory state) = raftContract
            .auctions(address(mockArk1), address(mockRewardToken));
        assertTrue(state.isFinalized);
    }

    function test_BuyAllAndSettleAuction() public {
        _setupAuction();
        uint256 currentPrice = raftContract.getCurrentPrice(
            address(mockArk1),
            address(mockRewardToken)
        );
        uint256 buyAmount = REWARD_AMOUNT -
            REWARD_AMOUNT.applyPercentage(
                Percentage.wrap(KICKER_REWARD_PERCENTAGE)
            );
        uint256 amountToSpend = (buyAmount * currentPrice) / 1e18;

        vm.startPrank(buyer);
        mockPaymentToken.approve(address(raftContract), amountToSpend);
        vm.expectEmit(true, true, true, true);
        emit RewardBoarded(
            address(mockArk1),
            address(mockRewardToken),
            address(mockPaymentToken),
            amountToSpend
        );
        raftContract.buyTokens(
            address(mockArk1),
            address(mockRewardToken),
            buyAmount
        );
        vm.stopPrank();

        (, DutchAuctionLibrary.AuctionState memory state) = raftContract
            .auctions(address(mockArk1), address(mockRewardToken));
        assertTrue(state.isFinalized);
    }

    function test_UpdateAuctionConfig() public {
        BaseAuctionParameters memory newConfig = BaseAuctionParameters({
            duration: 2 days,
            startPrice: 2e18,
            endPrice: 2,
            kickerRewardPercentage: PercentageUtils.fromIntegerPercentage(10),
            decayType: DecayFunctions.DecayType.Quadratic
        });

        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit IRaftEvents.ArkAuctionParametersSet(
            address(mockArk1),
            address(mockRewardToken),
            newConfig
        );

        raftContract.setArkAuctionParameters(
            address(mockArk1),
            address(mockRewardToken),
            newConfig
        );

        (
            uint40 duration,
            uint256 startPrice,
            uint256 endPrice,
            Percentage kickerRewardPercentage,
            DecayFunctions.DecayType decayType
        ) = raftContract.arkAuctionParameters(
                address(mockArk1),
                address(mockRewardToken)
            );
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
            abi.encodeWithSignature(
                "RaftAuctionAlreadyRunning(address,address)",
                address(mockArk1),
                address(mockRewardToken)
            )
        );
        raftContract.startAuction(address(mockArk1), address(mockRewardToken));
    }

    function test_CannotStartAuctionWithNoTokens() public {
        vm.prank(governor);
        vm.expectRevert(DutchAuctionErrors.InvalidTokenAmount.selector);
        raftContract.startAuction(address(mockArk1), address(mockRewardToken));
    }

    function test_CannotFinalizeAuctionBeforeEndTime() public {
        _setupAuction();

        vm.expectRevert(abi.encodeWithSignature("AuctionNotEnded(uint256)", 1));
        raftContract.finalizeAuction(
            address(mockArk1),
            address(mockRewardToken)
        );
    }

    function test_UnsoldTokensHandling() public {
        _setupAuction();

        // Buy half of the tokens
        uint256 buyAmount = (REWARD_AMOUNT -
            REWARD_AMOUNT.applyPercentage(
                Percentage.wrap(KICKER_REWARD_PERCENTAGE)
            )) / 2;
        uint256 currentPrice = raftContract.getCurrentPrice(
            address(mockArk1),
            address(mockRewardToken)
        );
        uint256 buyAmountToSpend = (buyAmount * currentPrice) / 1e18;
        vm.startPrank(buyer);
        mockPaymentToken.approve(address(raftContract), buyAmountToSpend);
        raftContract.buyTokens(
            address(mockArk1),
            address(mockRewardToken),
            buyAmount
        );
        vm.stopPrank();

        // Finalize the auction
        vm.warp(block.timestamp + 8 days);
        raftContract.finalizeAuction(
            address(mockArk1),
            address(mockRewardToken)
        );

        // Check unsold tokens
        uint256 expectedUnsoldTokens = REWARD_AMOUNT -
            REWARD_AMOUNT.applyPercentage(
                Percentage.wrap(KICKER_REWARD_PERCENTAGE)
            ) -
            buyAmount;
        assertEq(
            raftContract.unsoldTokens(
                address(mockArk1),
                address(mockRewardToken)
            ),
            expectedUnsoldTokens
        );
    }

    function test_auctions() public {
        // Setup the auction
        _setupAuction();

        // Get the auction info
        (
            DutchAuctionLibrary.AuctionConfig memory config,
            DutchAuctionLibrary.AuctionState memory state
        ) = raftContract.auctions(address(mockArk1), address(mockRewardToken));

        // Verify the auction config
        assertEq(config.id, 1, "Auction ID should be 1");
        assertEq(
            address(config.auctionToken),
            address(mockRewardToken),
            "Auction token should be mockRewardToken"
        );
        assertEq(
            address(config.paymentToken),
            address(mockPaymentToken),
            "Payment token should be mockPaymentToken"
        );
        assertEq(
            config.totalTokens,
            REWARD_AMOUNT -
                REWARD_AMOUNT.applyPercentage(
                    Percentage.wrap(KICKER_REWARD_PERCENTAGE)
                ),
            "Total tokens should be correct"
        );
        assertEq(
            config.startTime,
            block.timestamp,
            "Start time should be current block timestamp"
        );
        assertEq(
            config.endTime,
            block.timestamp + AUCTION_DURATION,
            "End time should be start time + duration"
        );
        assertEq(
            config.startPrice,
            START_PRICE,
            "Start price should be correct"
        );
        assertEq(config.endPrice, END_PRICE, "End price should be correct");
        assertEq(
            uint8(config.decayType),
            uint8(DecayFunctions.DecayType.Linear),
            "Decay type should be Linear"
        );

        // Verify the auction state
        assertEq(
            state.remainingTokens,
            REWARD_AMOUNT -
                REWARD_AMOUNT.applyPercentage(
                    Percentage.wrap(KICKER_REWARD_PERCENTAGE)
                ),
            "Remaining tokens should be total tokens"
        );
        assertFalse(state.isFinalized, "Auction should not be finalized");

        // Buy some tokens
        uint256 buyAmount = 1000;
        uint256 currentPrice = raftContract.getCurrentPrice(
            address(mockArk1),
            address(mockRewardToken)
        );
        uint256 amountToSpend = (buyAmount * currentPrice) / 1e18;

        vm.startPrank(buyer);
        mockPaymentToken.approve(address(raftContract), amountToSpend);
        raftContract.buyTokens(
            address(mockArk1),
            address(mockRewardToken),
            buyAmount
        );
        vm.stopPrank();

        // Get the updated auction info
        (config, state) = raftContract.auctions(
            address(mockArk1),
            address(mockRewardToken)
        );

        // Verify the updated state
        assertEq(
            state.remainingTokens,
            REWARD_AMOUNT -
                REWARD_AMOUNT.applyPercentage(
                    Percentage.wrap(KICKER_REWARD_PERCENTAGE)
                ) -
                buyAmount,
            "Remaining tokens should be updated"
        );
        assertFalse(state.isFinalized, "Auction should still not be finalized");

        // Finalize the auction
        vm.warp(block.timestamp + AUCTION_DURATION + 1);
        raftContract.finalizeAuction(
            address(mockArk1),
            address(mockRewardToken)
        );

        // Get the final auction info
        (config, state) = raftContract.auctions(
            address(mockArk1),
            address(mockRewardToken)
        );

        // Verify the final state
        assertTrue(state.isFinalized, "Auction should be finalized");
    }

    function _setupAuction() internal {
        vm.startPrank(governor);
        raftContract.harvest(
            address(mockArk1),
            _getEncodedRewardDataSingleToken(
                address(mockRewardToken),
                REWARD_AMOUNT
            )
        );
        raftContract.startAuction(address(mockArk1), address(mockRewardToken));
        vm.stopPrank();
    }

    function test_Sweep() public {
        // Setup: Create mock tokens and mint them to the Ark
        ERC20Mock mockToken1 = new ERC20Mock();
        ERC20Mock mockToken2 = new ERC20Mock();

        uint256 amount1 = 1000 * 10 ** 18;
        uint256 amount2 = 500 * 10 ** 18;
        deal(address(mockPaymentToken), address(mockArk1), amount1);
        deal(address(mockToken1), address(mockArk1), amount1);
        deal(address(mockToken2), address(mockArk1), amount2);

        // Prepare the tokens array for sweeping
        address[] memory tokensToSweep = new address[](2);
        tokensToSweep[0] = address(mockToken1);
        tokensToSweep[1] = address(mockToken2);

        // Execute the sweep function
        vm.prank(address(raftContract));
        (address[] memory sweptTokens, uint256[] memory sweptAmounts) = mockArk1
            .sweep(tokensToSweep);

        // Verify the swept tokens and amounts
        assertEq(sweptTokens.length, 2, "Should have swept 2 tokens");
        assertEq(
            sweptTokens[0],
            address(mockToken1),
            "First swept token should be mockToken1"
        );
        assertEq(
            sweptTokens[1],
            address(mockToken2),
            "Second swept token should be mockToken2"
        );
        assertEq(
            sweptAmounts[0],
            amount1,
            "Swept amount of mockToken1 should match"
        );
        assertEq(
            sweptAmounts[1],
            amount2,
            "Swept amount of mockToken2 should match"
        );

        // Verify the tokens were transferred to the BufferArk
        assertEq(
            mockToken1.balanceOf(address(raftContract)),
            amount1,
            "Raft should have received all mockToken1"
        );
        assertEq(
            mockToken2.balanceOf(address(raftContract)),
            amount2,
            "Raft should have received all mockToken2"
        );
        assertEq(
            mockPaymentToken.balanceOf(address(bufferArk)),
            amount1,
            "Buffer Ark should have received all mockToken1"
        );

        // Verify the Ark's balances are now zero
        assertEq(
            mockToken1.balanceOf(address(mockArk1)),
            0,
            "Ark should have no mockToken1 left"
        );
        assertEq(
            mockToken2.balanceOf(address(mockArk1)),
            0,
            "Ark should have no mockToken2 left"
        );
    }

    function test_SweepWithNoTokens() public {
        // Prepare an empty array for sweeping
        address[] memory tokensToSweep = new address[](0);

        // Execute the sweep function
        vm.prank(address(raftContract));
        (address[] memory sweptTokens, uint256[] memory sweptAmounts) = mockArk1
            .sweep(tokensToSweep);

        // Verify that no tokens were swept
        assertEq(sweptTokens.length, 0, "Should have swept no tokens");
        assertEq(sweptAmounts.length, 0, "Should have swept no amounts");
    }

    function test_SweepOnlyRaft() public {
        address[] memory tokensToSweep = new address[](1);
        tokensToSweep[0] = address(0); // Dummy address

        // Try to sweep from a non-Raft address
        vm.prank(address(0xdead));
        vm.expectRevert(
            abi.encodeWithSignature("CallerIsNotRaft(address)", address(0xdead))
        );
        mockArk1.sweep(tokensToSweep);
    }

    function test_SweepAndStartAuction() public {
        // Setup: mint tokens to the mock Ark
        uint256 amount1 = 1000 * 10 ** 18;
        uint256 amount2 = 500 * 10 ** 18;
        deal(address(mockRewardToken), address(mockArk1), amount1);
        deal(address(mockRewardToken2), address(mockArk1), amount2);

        address[] memory tokensToSweep = new address[](2);
        tokensToSweep[0] = address(mockRewardToken);
        tokensToSweep[1] = address(mockRewardToken2);

        vm.startPrank(governor); // governor is also curator for that fleet
        raftContract.setSweepableToken(
            address(mockArk1),
            address(mockRewardToken2),
            true
        );
        raftContract.setSweepableToken(
            address(mockArk1),
            address(mockRewardToken),
            true
        );

        vm.expectEmit(true, true, true, true);
        emit DutchAuctionEvents.AuctionCreated(
            1,
            governor,
            amount1 -
                amount1.applyPercentage(
                    Percentage.wrap(KICKER_REWARD_PERCENTAGE)
                ),
            amount1.applyPercentage(Percentage.wrap(KICKER_REWARD_PERCENTAGE))
        );
        vm.expectEmit(true, true, true, true);
        emit DutchAuctionEvents.AuctionCreated(
            2,
            governor,
            amount2 -
                amount2.applyPercentage(
                    Percentage.wrap(KICKER_REWARD_PERCENTAGE)
                ),
            amount2.applyPercentage(Percentage.wrap(KICKER_REWARD_PERCENTAGE))
        );

        raftContract.sweepAndStartAuction(address(mockArk1), tokensToSweep);
        vm.stopPrank();
        (, DutchAuctionLibrary.AuctionState memory state) = raftContract
            .auctions(address(mockArk1), address(mockRewardToken));
        assertEq(
            state.remainingTokens,
            amount1 -
                amount1.applyPercentage(
                    Percentage.wrap(KICKER_REWARD_PERCENTAGE)
                )
        );

        (, DutchAuctionLibrary.AuctionState memory state2) = raftContract
            .auctions(address(mockArk1), address(mockRewardToken2));
        assertEq(
            state2.remainingTokens,
            amount2 -
                amount2.applyPercentage(
                    Percentage.wrap(KICKER_REWARD_PERCENTAGE)
                )
        );

        // Verify that obtainedTokens are reset after starting the auction
        assertEq(
            raftContract.obtainedTokens(
                address(mockArk1),
                address(mockRewardToken)
            ),
            0
        );
        assertEq(
            raftContract.obtainedTokens(
                address(mockArk1),
                address(mockRewardToken2)
            ),
            0
        );
    }

    function test_SetSweepableToken() public {
        vm.startPrank(governor);

        // Set token as sweepable
        vm.expectEmit(true, true, true, true);
        emit SweepableTokenSet(
            address(mockArk1),
            address(mockRewardToken),
            true
        );
        raftContract.setSweepableToken(
            address(mockArk1),
            address(mockRewardToken),
            true
        );

        // Verify token is sweepable
        assertTrue(
            raftContract.sweepableTokens(
                address(mockArk1),
                address(mockRewardToken)
            ),
            "Token should be sweepable"
        );

        // Set token as not sweepable
        vm.expectEmit(true, true, true, true);
        emit SweepableTokenSet(
            address(mockArk1),
            address(mockRewardToken),
            false
        );
        raftContract.setSweepableToken(
            address(mockArk1),
            address(mockRewardToken),
            false
        );

        // Verify token is not sweepable
        assertFalse(
            raftContract.sweepableTokens(
                address(mockArk1),
                address(mockRewardToken)
            ),
            "Token should not be sweepable"
        );

        vm.stopPrank();
    }

    function test_SweepNotSweepableToken() public {
        // Try to sweep token that hasn't been marked as sweepable
        address[] memory tokensToSweep = new address[](1);
        tokensToSweep[0] = address(mockRewardToken);

        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSignature(
                "RaftTokenNotSweepable(address,address)",
                address(mockArk1),
                address(mockRewardToken)
            )
        );
        raftContract.sweep(address(mockArk1), tokensToSweep);
    }

    function test_SweepMultipleTokens_MixedSweepable() public {
        // Setup: mark first token as sweepable, leave second token as not sweepable
        vm.startPrank(governor);
        raftContract.setSweepableToken(
            address(mockArk1),
            address(mockRewardToken),
            true
        );
        vm.stopPrank();

        // Try to sweep both tokens
        address[] memory tokensToSweep = new address[](2);
        tokensToSweep[0] = address(mockRewardToken);
        tokensToSweep[1] = address(mockRewardToken2);

        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSignature(
                "RaftTokenNotSweepable(address,address)",
                address(mockArk1),
                address(mockRewardToken2)
            )
        );
        raftContract.sweep(address(mockArk1), tokensToSweep);
    }

    function test_SweepAndStartAuction_OnlySweepableTokens() public {
        // Setup: mint tokens and mark first token as sweepable
        uint256 amount1 = 1000 * 10 ** 18;
        uint256 amount2 = 500 * 10 ** 18;
        deal(address(mockRewardToken), address(mockArk1), amount1);
        deal(address(mockRewardToken2), address(mockArk1), amount2);

        vm.startPrank(governor);
        raftContract.setSweepableToken(
            address(mockArk1),
            address(mockRewardToken),
            true
        );

        // Try to sweep and start auction with mix of sweepable and non-sweepable tokens
        address[] memory tokensToSweep = new address[](2);
        tokensToSweep[0] = address(mockRewardToken);
        tokensToSweep[1] = address(mockRewardToken2);

        vm.expectRevert(
            abi.encodeWithSignature(
                "RaftTokenNotSweepable(address,address)",
                address(mockArk1),
                address(mockRewardToken2)
            )
        );
        raftContract.sweepAndStartAuction(address(mockArk1), tokensToSweep);
        vm.stopPrank();
    }

    function test_NonGovernorCannotSetSweepableToken() public {
        vm.prank(address(0xdead));
        vm.expectRevert(
            abi.encodeWithSignature(
                "CallerIsNotCurator(address)",
                address(0xdead)
            )
        );
        raftContract.setSweepableToken(
            address(mockArk1),
            address(mockRewardToken),
            true
        );
    }

    function test_uninitilizedRewardToken() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "RaftAuctionParametersNotSet(address,address)",
                address(mockArk1),
                address(789)
            )
        );
        vm.prank(governor);
        raftContract.startAuction(address(mockArk1), address(789));
    }
}
