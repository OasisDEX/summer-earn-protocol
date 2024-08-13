// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {IArk} from "../src/interfaces/IArk.sol";
import {IRaftEvents} from "../src/events/IRaftEvents.sol";
import {Raft} from "../src/contracts/Raft.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ProtocolAccessManager} from "../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../src/interfaces/IProtocolAccessManager.sol";
import {DutchAuctionLibrary} from "@summerfi/dutch-auction/src/DutchAuctionLibrary.sol";
import {DutchAuctionEvents} from "@summerfi/dutch-auction/src/DutchAuctionEvents.sol";
import {DecayFunctions} from "@summerfi/dutch-auction/src/DecayFunctions.sol";
import {PercentageUtils} from "@summerfi/dutch-auction/src/lib/PercentageUtils.sol";
import {Percentage} from "@summerfi/dutch-auction/src/lib/Percentage.sol";
import "../src/errors/RaftErrors.sol";
import "../src/errors/AccessControlErrors.sol";
import "../src/types/RaftTypes.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ArkMock, ArkParams} from "./mocks/ArkMock.sol";
import {ConfigurationManager} from "../src/contracts/ConfigurationManager.sol";
import {ConfigurationManagerParams} from "../src/types/ConfigurationManagerTypes.sol";

contract RaftTest is Test, IRaftEvents {
    using PercentageUtils for uint256;

    ArkMock public mockArk;
    Raft public raft;
    IProtocolAccessManager public accessManager;

    address public governor = address(1);
    address public buyer = address(2);
    address public superKeeper = address(8);
    ERC20Mock public mockRewardToken;
    ERC20Mock public mockPaymentToken;

    uint256 constant REWARD_AMOUNT = 100000000;
    Percentage public KICKER_REWARD_PERCENTAGE =
        PercentageUtils.fromDecimalPercentage(5);

    function setUp() public {
        mockRewardToken = new ERC20Mock();
        mockPaymentToken = new ERC20Mock();
        accessManager = new ProtocolAccessManager(governor);
        vm.prank(governor);
        accessManager.grantSuperKeeperRole(superKeeper);

        raft = new Raft(address(accessManager));

        ConfigurationManager configurationManager = new ConfigurationManager(
            ConfigurationManagerParams({
                accessManager: address(accessManager),
                raft: address(raft),
                tipJar: address(0)
            })
        );

        ArkParams memory params = ArkParams({
            name: "TestArk",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: address(mockPaymentToken),
            maxAllocation: type(uint256).max
        });

        mockArk = new ArkMock(params);

        mockRewardToken.mint(address(address(mockArk)), REWARD_AMOUNT);
        mockPaymentToken.mint(address(buyer), 10000 ether);

        vm.label(governor, "governor");
        vm.label(address(address(mockArk)), "address(mockArk)");
        vm.label(address(mockPaymentToken), "mockPaymentToken");
        vm.label(superKeeper, "superKeeper");
        vm.label(address(mockRewardToken), "mockRewardToken");
        vm.label(address(mockPaymentToken), "mockPaymentToken");
        vm.label(address(raft), "raft");
        vm.label(address(accessManager), "accessManager");
    }

    function test_Constructor() public {
        Raft newRaft = new Raft(address(accessManager));
        (
            uint40 duration,
            uint256 startPrice,
            uint256 endPrice,
            Percentage kickerRewardPercentage,
            DecayFunctions.DecayType decayType
        ) = newRaft.auctionDefaultParameters();
        assertEq(duration, 1 days);
        assertEq(startPrice, 1e18);
        assertEq(endPrice, 1);
        assertEq(Percentage.unwrap(kickerRewardPercentage), 5 * 1e18);
        assertEq(uint256(decayType), uint256(DecayFunctions.DecayType.Linear));
    }

    function test_Harvest() public {
        vm.expectEmit(true, true, true, true);
        emit ArkHarvested(address(mockArk), address(mockRewardToken));

        vm.prank(superKeeper);
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
        vm.prank(superKeeper);
        vm.expectEmit(true, true, true, true);
        emit ArkHarvested(address(mockArk), address(mockRewardToken));

        vm.expectEmit(true, true, true, true);
        emit DutchAuctionEvents.AuctionCreated(
            0,
            superKeeper,
            REWARD_AMOUNT -
                REWARD_AMOUNT.applyPercentage(KICKER_REWARD_PERCENTAGE),
            REWARD_AMOUNT.applyPercentage(KICKER_REWARD_PERCENTAGE)
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
                REWARD_AMOUNT.applyPercentage(KICKER_REWARD_PERCENTAGE)
        );
    }

    function test_MultipleAuctionsCycle() public {
        // First auction cycle
        _setupAuction();

        uint256 firstAuctionAmount = REWARD_AMOUNT -
            REWARD_AMOUNT.applyPercentage(KICKER_REWARD_PERCENTAGE);

        // Buy all tokens in the first auction
        vm.startPrank(buyer);
        mockPaymentToken.approve(address(raft), 1000000 ether);
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
            firstAuctionAmount,
            "Rewards should be boarded"
        );

        // Second harvest and auction cycle
        uint256 secondHarvestAmount = 150; // Different amount for the second harvest
        mockRewardToken.mint(address(mockArk), secondHarvestAmount);

        vm.startPrank(superKeeper);
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
            1, // This should be the next auction ID
            superKeeper,
            secondHarvestAmount -
                secondHarvestAmount.applyPercentage(KICKER_REWARD_PERCENTAGE),
            secondHarvestAmount.applyPercentage(KICKER_REWARD_PERCENTAGE)
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

        assertEq(config.id, 1, "Should be the second auction ID");
        assertEq(
            config.totalTokens,
            secondHarvestAmount -
                secondHarvestAmount.applyPercentage(KICKER_REWARD_PERCENTAGE),
            "Should have the correct total tokens"
        );
        assertEq(
            newState.remainingTokens,
            secondHarvestAmount -
                secondHarvestAmount.applyPercentage(KICKER_REWARD_PERCENTAGE),
            "Should have the correct remaining tokens"
        );
        assertFalse(newState.isFinalized, "Should not be finalized");

        // Buy half of the tokens in the second auction
        uint256 secondAuctionBuyAmount = (secondHarvestAmount -
            secondHarvestAmount.applyPercentage(KICKER_REWARD_PERCENTAGE)) / 2;
        vm.startPrank(buyer);
        mockPaymentToken.approve(address(raft), 100000 ether);
        raft.buyTokens(
            address(mockArk),
            address(mockRewardToken),
            secondAuctionBuyAmount
        );
        vm.stopPrank();

        // Finalize the second auction
        vm.warp(block.timestamp + 2 days);
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
                secondHarvestAmount.applyPercentage(KICKER_REWARD_PERCENTAGE) -
                secondAuctionBuyAmount,
            "Should have the correct remaining tokens"
        );

        // Verify unsold tokens
        assertEq(
            raft.unsoldTokens(address(mockArk), address(mockRewardToken)),
            secondHarvestAmount -
                secondHarvestAmount.applyPercentage(KICKER_REWARD_PERCENTAGE) -
                secondAuctionBuyAmount,
            "Should have unsold tokens"
        );

        // Verify total rewards boarded
        assertEq(
            mockPaymentToken.balanceOf(address(mockArk)),
            firstAuctionAmount + secondAuctionBuyAmount,
            "Should have total rewards boarded"
        );
    }

    function test_MultipleAuctionsCycleWithUnsoldTokens() public {
        // First auction cycle
        _setupAuction();

        uint256 firstAuctionTotalAmount = REWARD_AMOUNT -
            REWARD_AMOUNT.applyPercentage(KICKER_REWARD_PERCENTAGE);
        uint256 firstAuctionBuyAmount = firstAuctionTotalAmount / 2; // Buy only half of the tokens

        // Buy half of the tokens in the first auction
        vm.startPrank(buyer);
        mockPaymentToken.approve(address(raft), 1000000 ether);
        raft.buyTokens(
            address(mockArk),
            address(mockRewardToken),
            firstAuctionBuyAmount
        );
        vm.stopPrank();

        // Finalize the first auction after some time
        vm.warp(block.timestamp + 2 days);
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
            firstAuctionBuyAmount,
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
        mockRewardToken.mint(address(mockArk), secondHarvestAmount);

        vm.startPrank(superKeeper);
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
            1, // This should be the next auction ID
            superKeeper,
            secondAuctionTotalAmount -
                secondAuctionTotalAmount.applyPercentage(
                    KICKER_REWARD_PERCENTAGE
                ),
            secondAuctionTotalAmount.applyPercentage(KICKER_REWARD_PERCENTAGE)
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

        assertEq(config.id, 1, "Should be the second auction ID");
        assertEq(
            config.totalTokens,
            secondAuctionTotalAmount -
                secondAuctionTotalAmount.applyPercentage(
                    KICKER_REWARD_PERCENTAGE
                ),
            "Should have the correct total tokens including unsold from first auction"
        );
        assertEq(
            newState.remainingTokens,
            secondAuctionTotalAmount -
                secondAuctionTotalAmount.applyPercentage(
                    KICKER_REWARD_PERCENTAGE
                ),
            "Should have the correct remaining tokens"
        );
        assertFalse(newState.isFinalized, "Should not be finalized");

        // Buy all tokens in the second auction
        uint256 secondAuctionBuyAmount = secondAuctionTotalAmount -
            secondAuctionTotalAmount.applyPercentage(KICKER_REWARD_PERCENTAGE);
        vm.startPrank(buyer);
        mockPaymentToken.approve(address(raft), 100000 ether);
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
            firstAuctionBuyAmount + secondAuctionBuyAmount,
            "Should have total rewards boarded from both auctions"
        );
    }

    function test_StartAuction() public {
        vm.prank(superKeeper);
        raft.harvest(
            address(mockArk),
            address(mockRewardToken),
            abi.encode(REWARD_AMOUNT)
        );

        vm.expectEmit(true, true, true, true);
        emit DutchAuctionEvents.AuctionCreated(
            0,
            superKeeper,
            REWARD_AMOUNT -
                REWARD_AMOUNT.applyPercentage(KICKER_REWARD_PERCENTAGE),
            REWARD_AMOUNT.applyPercentage(KICKER_REWARD_PERCENTAGE)
        );

        vm.prank(superKeeper);
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
                REWARD_AMOUNT.applyPercentage(KICKER_REWARD_PERCENTAGE)
        );
    }

    function test_BuyTokens() public {
        _setupAuction();

        uint256 buyAmount = 50;
        vm.startPrank(buyer);
        mockPaymentToken.approve(address(raft), buyAmount);
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
                REWARD_AMOUNT.applyPercentage(KICKER_REWARD_PERCENTAGE)
        );
    }

    function test_FinalizeAuction() public {
        _setupAuction();

        // Warp to after auction end time
        vm.warp(block.timestamp + 2 days);

        raft.finalizeAuction(address(mockArk), address(mockRewardToken));

        (, DutchAuctionLibrary.AuctionState memory state) = raft.auctions(
            address(mockArk),
            address(mockRewardToken)
        );
        assertTrue(state.isFinalized);
    }

    function test_BuyAllAndSettleAuction() public {
        _setupAuction();

        uint256 buyAmount = REWARD_AMOUNT -
            REWARD_AMOUNT.applyPercentage(KICKER_REWARD_PERCENTAGE);

        vm.startPrank(buyer);
        mockPaymentToken.approve(address(raft), buyAmount);
        vm.expectEmit(true, true, true, true);
        emit RewardBoarded(
            address(mockArk),
            address(mockRewardToken),
            address(mockPaymentToken),
            buyAmount
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
            kickerRewardPercentage: PercentageUtils.fromDecimalPercentage(10),
            decayType: DecayFunctions.DecayType.Exponential
        });

        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit AuctionDefaultParametersUpdated(newConfig);

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

        vm.prank(superKeeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                AuctionAlreadyRunning.selector,
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
        vm.prank(superKeeper);
        vm.expectRevert(NoTokensToAuction.selector);
        raft.startAuction(
            address(mockArk),
            address(mockRewardToken),
            address(mockPaymentToken)
        );
    }

    function test_CannotFinalizeAuctionBeforeEndTime() public {
        _setupAuction();

        vm.expectRevert(abi.encodeWithSignature("AuctionNotEnded()"));
        raft.finalizeAuction(address(mockArk), address(mockRewardToken));
    }

    function test_UnsoldTokensHandling() public {
        _setupAuction();

        // Buy half of the tokens
        uint256 buyAmount = (REWARD_AMOUNT -
            REWARD_AMOUNT.applyPercentage(KICKER_REWARD_PERCENTAGE)) / 2;
        vm.startPrank(buyer);
        mockPaymentToken.approve(address(raft), buyAmount);
        raft.buyTokens(address(mockArk), address(mockRewardToken), buyAmount);
        vm.stopPrank();

        // Finalize the auction
        vm.warp(block.timestamp + 2 days);
        raft.finalizeAuction(address(mockArk), address(mockRewardToken));

        // Check unsold tokens
        uint256 expectedUnsoldTokens = REWARD_AMOUNT -
            REWARD_AMOUNT.applyPercentage(KICKER_REWARD_PERCENTAGE) -
            buyAmount;
        assertEq(
            raft.unsoldTokens(address(mockArk), address(mockRewardToken)),
            expectedUnsoldTokens
        );
    }

    function _setupAuction() internal {
        vm.startPrank(superKeeper);
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
