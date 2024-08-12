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

    uint256 constant REWARD_AMOUNT = 100;
    uint256 constant BALANCE_AFTER_AUCTION = 200;
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
        AuctionConfig memory newConfig = AuctionConfig({
            duration: 2 days,
            startPrice: 2e18,
            endPrice: 2,
            kickerRewardPercentage: PercentageUtils.fromDecimalPercentage(10),
            decayType: DecayFunctions.DecayType.Exponential
        });

        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit AuctionConfigUpdated(newConfig);

        raft.updateAuctionConfig(newConfig);

        (
            uint40 duration,
            uint256 startPrice,
            uint256 endPrice,
            Percentage kickerRewardPercentage,
            DecayFunctions.DecayType decayType
        ) = raft.auctionConfig();
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
