// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/MorphoArk.sol";
import {Test, console} from "forge-std/Test.sol";

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";
import "../../src/events/IArkEvents.sol";

import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";

import {MockUniversalRewardsDistributor} from "../mocks/MockUniversalRewardsDistributor.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {IMorpho, IMorphoBase, Id, MarketParams} from "morpho-blue/interfaces/IMorpho.sol";

contract MorphoArkTestFork is Test, IArkEvents, ArkTestBase {
    MorphoArk public ark;

    address public constant MORPHO_ADDRESS =
        0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address public constant METAMORPHO_ADDRESS =
        0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB;
    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant WBTC_ADDRESS =
        0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant MORPHO_URD_FACTORY =
        0x9baA51245CDD28D8D74Afe8B3959b616E9ee7c8D;

    Id public constant MARKET_ID =
        Id.wrap(
            0x3a85e619751152991742810df6ec69ce473daef99e28a64ab2340d7b7ccfee49
        );

    IMorpho public morpho;
    IERC20 public usdc;
    IERC20 public rewardToken;
    MockUniversalRewardsDistributor public rewardsDistributor;

    uint256 forkBlock = 20376149;
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        rewardsDistributor = new MockUniversalRewardsDistributor();
        rewardToken = IERC20(address(new ERC20Mock()));

        morpho = IMorpho(MORPHO_ADDRESS);
        usdc = IERC20(USDC_ADDRESS);

        ArkParams memory params = ArkParams({
            name: "TestArk",
            details: "TestArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC_ADDRESS,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new MorphoArk(
            MORPHO_ADDRESS,
            MARKET_ID,
            MORPHO_URD_FACTORY,
            params
        );

        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(address(ark)),
            address(commander)
        );
        vm.stopPrank();

        // Set up the rewards distributor
        bytes32 mockRoot = keccak256("mockRoot");
        rewardsDistributor.setRoot(mockRoot, mockRoot);

        // Fund the rewards distributor
        deal(address(rewardToken), address(rewardsDistributor), 1000e18);

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();
    }

    function test_Constructor_MorphoArk_fork() public {
        // Arrange
        ArkParams memory params = ArkParams({
            name: "TestArk",
            details: "TestArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(usdc),
            depositCap: 1000,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        // Act & Assert
        vm.expectRevert(abi.encodeWithSignature("InvalidMorphoAddress()"));
        new MorphoArk(address(0), Id.wrap(0), MORPHO_URD_FACTORY, params);

        vm.expectRevert(abi.encodeWithSignature("InvalidMorphoAddress()"));
        new MorphoArk(address(0), MARKET_ID, MORPHO_URD_FACTORY, params);

        vm.expectRevert(abi.encodeWithSignature("InvalidMarketId()"));
        new MorphoArk(MORPHO_ADDRESS, Id.wrap(0), MORPHO_URD_FACTORY, params);

        MorphoArk newArk = new MorphoArk(
            MORPHO_ADDRESS,
            MARKET_ID,
            MORPHO_URD_FACTORY,
            params
        );
        assertTrue(newArk.depositCap() == 1000, "Max allocation should be set");
        assertTrue(
            Id.unwrap(newArk.marketId()) == Id.unwrap(MARKET_ID),
            "Market ID should be set"
        );
        assertTrue(newArk.totalAssets() == 0, "Total assets should be zero");
        assertTrue(
            address(newArk.MORPHO()) == MORPHO_ADDRESS,
            "Morpho address should be set"
        );
    }

    function test_Board_MorphoArk_fork() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.approve(address(ark), amount);

        // Expect the supply call to Morpho
        vm.expectCall(
            MORPHO_ADDRESS,
            abi.encodeWithSelector(
                IMorphoBase.supply.selector,
                morpho.idToMarketParams(MARKET_ID),
                amount,
                0,
                address(ark),
                ""
            )
        );

        // Expect the Boarded event to be emitted
        vm.expectEmit();
        emit Boarded(commander, USDC_ADDRESS, amount);

        // Act
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Assert
        uint256 assetsAfterDeposit = ark.totalAssets();
        assertEq(
            assetsAfterDeposit,
            amount - 1,
            "Total assets should equal deposited amount"
        );

        // Warp time to simulate interest accrual
        vm.warp(block.timestamp + 1 days);

        morpho.accrueInterest(morpho.idToMarketParams(MARKET_ID));

        uint256 assetsAfterAccrual = ark.totalAssets();
        assertTrue(
            assetsAfterAccrual > assetsAfterDeposit,
            "Assets should increase after accrual"
        );
    }

    function test_Disembark_MorphoArk_fork() public {
        // First, board some assets
        test_Board_MorphoArk_fork();

        uint256 initialBalance = usdc.balanceOf(commander);
        uint256 amountToWithdraw = 500 * 10 ** 6; // 500 USDC

        vm.prank(commander);

        // Expect the withdraw call to Morpho
        vm.expectCall(
            MORPHO_ADDRESS,
            abi.encodeWithSelector(
                IMorphoBase.withdraw.selector,
                morpho.idToMarketParams(MARKET_ID),
                amountToWithdraw,
                0,
                address(ark),
                address(ark)
            )
        );

        // Expect the Disembarked event to be emitted
        vm.expectEmit();
        emit Disembarked(commander, USDC_ADDRESS, amountToWithdraw);

        vm.prank(commander);
        ark.disembark(amountToWithdraw, bytes(""));

        uint256 finalBalance = usdc.balanceOf(commander);
        assertEq(
            finalBalance - initialBalance,
            amountToWithdraw,
            "Commander should receive withdrawn amount"
        );

        uint256 remainingAssets = ark.totalAssets();

        assertTrue(
            remainingAssets > 1000 * 10 ** 6 - amountToWithdraw,
            "Remaining assets should more than initial balance minus withdrawn amount (accounting the accrued interest)"
        );
    }

    function testHarvest() public {
        // make sure the URD is registered
        vm.mockCall(
            address(MORPHO_URD_FACTORY),
            abi.encodeWithSelector(
                IUrdFactory.isUrd.selector,
                address(rewardsDistributor)
            ),
            abi.encode(true)
        );
        // Prepare harvest data
        address[] memory urd = new address[](1);
        urd[0] = address(rewardsDistributor);

        address[] memory rewards = new address[](1);
        rewards[0] = address(rewardToken);

        uint256[] memory claimable = new uint256[](1);
        claimable[0] = 100e18;

        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = new bytes32[](1);
        proofs[0][0] = keccak256("mockProof");

        MorphoArk.RewardsData memory rewardsData = MorphoArk.RewardsData({
            urd: urd,
            rewards: rewards,
            claimable: claimable,
            proofs: proofs
        });

        bytes memory harvestData = abi.encode(rewardsData);

        // Expect the Claimed event from the rewards distributor
        vm.expectEmit(true, true, true, true, address(rewardsDistributor));
        emit IUniversalRewardsDistributor.Claimed(
            address(ark),
            address(rewardToken),
            100e18
        );

        // Expect the ArkHarvested event from the MorphoArk
        vm.expectEmit(true, true, true, true, address(ark));
        emit IArkEvents.ArkHarvested(rewards, claimable);

        // Call harvest
        vm.prank(address(raft));
        (
            address[] memory harvestedTokens,
            uint256[] memory harvestedAmounts
        ) = ark.harvest(harvestData);

        // Assert the harvested amounts
        assertEq(harvestedTokens.length, 1, "Should have harvested 1 token");
        assertEq(
            harvestedTokens[0],
            address(rewardToken),
            "Harvested token should be reward token"
        );
        assertEq(
            harvestedAmounts[0],
            100e18,
            "Should have harvested 100e18 reward tokens"
        );

        // Assert the rewards were transferred to the raft
        assertEq(
            rewardToken.balanceOf(ark.raft()),
            100e18,
            "Raft should have received the harvested rewards"
        );
    }
}
