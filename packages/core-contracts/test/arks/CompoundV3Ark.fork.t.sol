// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ArkParams, CompoundV3Ark} from "../../src/contracts/arks/CompoundV3Ark.sol";
import {Test, console} from "forge-std/Test.sol";

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";

import {IArkEvents} from "../../src/events/IArkEvents.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";

import {ICometRewards} from "../../src/interfaces/compound-v3/ICometRewards.sol";
import {IComet} from "../../src/interfaces/compound-v3/IComet.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";

import {ArkTestBase} from "./ArkTestBase.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

contract CompoundV3ArkTest is Test, IArkEvents, ArkTestBase {
    CompoundV3Ark public ark;

    address public constant cometAddress =
        0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    address public constant cometRewards = address(5);
    IComet public comet;
    IERC20 public usdc;

    uint256 forkBlock = 20276596;
    uint256 forkId;

    address constant MAINNET_COMET = 0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    address constant MAINNET_REWARDS =
        0x1B0e765F6224C21223AeA2af16c1C46E38885a40;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        comet = IComet(cometAddress);

        ArkParams memory params = ArkParams({
            name: "TestArk",
            details: "TestArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(usdc),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });
        ark = new CompoundV3Ark(address(comet), cometRewards, params);

        // Permissioning
        vm.prank(governor);
        accessManager.grantCommanderRole(
            address(address(ark)),
            address(commander)
        );

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();
    }

    function test_Board_CompoundV3_fork() public {
        // Arrange
        uint256 amount = 1990 * 10 ** 6;
        deal(address(usdc), commander, amount);
        vm.prank(commander);
        usdc.approve(address(ark), amount);

        // Expect comet to emit Supply
        vm.expectEmit();
        emit IComet.Supply(address(ark), address(ark), amount);

        // Expect the Transfer event to be emitted - minted compound tokens
        vm.expectEmit();
        emit IERC20.Transfer(
            0x0000000000000000000000000000000000000000,
            address(ark),
            amount - 1
        );

        // Expect the Boarded event to be emitted
        vm.expectEmit();
        emit Boarded(commander, address(usdc), amount);

        // Act
        vm.prank(commander); // Execute the next call as the commander
        ark.board(amount, bytes(""));

        uint256 assetsAfterDeposit = ark.totalAssets();
        vm.warp(block.timestamp + 10000);
        uint256 assetsAfterAccrual = ark.totalAssets();
        console.log("assetsAfterDeposit: ", assetsAfterDeposit);
        console.log("assetsAfterAccrual: ", assetsAfterAccrual);
        assertTrue(assetsAfterAccrual > assetsAfterDeposit);
    }

    function test_Harvest_CompoundV3_Mainnet() public {
        vm.selectFork(vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock));
        initializeCoreContracts();

        ArkParams memory params = ArkParams({
            name: "TestArk",
            details: "TestArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(usdc),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        CompoundV3Ark mainnetArk = new CompoundV3Ark(
            MAINNET_COMET,
            MAINNET_REWARDS,
            params
        );

        // Setup permissions using existing pattern
        vm.prank(governor);
        accessManager.grantCommanderRole(address(mainnetArk), commander);

        vm.startPrank(commander);
        mainnetArk.registerFleetCommander();

        // Supply and test rewards
        uint256 amount = 1000e6; // 1000 USDC
        deal(address(usdc), commander, amount);
        usdc.approve(address(mainnetArk), amount);
        mainnetArk.board(amount, "");
        vm.stopPrank();

        vm.warp(block.timestamp + 30 days);
        vm.roll(block.number + 100_000);

        vm.prank(raft);
        (address[] memory tokens, uint256[] memory amounts) = mainnetArk
            .harvest("");

        assertEq(tokens.length, 1);
        assertTrue(amounts[0] > 0, "Should have harvested COMP rewards");
    }
}
