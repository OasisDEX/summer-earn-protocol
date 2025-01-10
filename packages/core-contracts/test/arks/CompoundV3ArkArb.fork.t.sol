// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ArkParams, CompoundV3Ark} from "../../src/contracts/arks/CompoundV3Ark.sol";
import {Test, console} from "forge-std/Test.sol";

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";

import {IArkEvents} from "../../src/events/IArkEvents.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";

import {IComet} from "../../src/interfaces/compound-v3/IComet.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";

import {ArkTestBase} from "./ArkTestBase.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

contract CompoundV3ArkArbitrumTest is Test, IArkEvents, ArkTestBase {
    CompoundV3Ark public ark;

    address public constant cometAddress =
        0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf;
    address public constant cometRewards =
        0x88730d254A2f7e6AC8388c3198aFd694bA9f7fae;
    IComet public comet;
    IERC20 public usdc;

    uint256 constant FORK_BLOCK = 293962852;
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("arbitrum"), FORK_BLOCK);

        usdc = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
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
        vm.prank(governor);
        configurationManager.setRaft(address(governor));
        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();
    }

    function test_Board_CompoundV3_Arbitrum_fork() public {
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
        vm.prank(commander);
        ark.board(amount, bytes(""));

        uint256 assetsAfterDeposit = ark.totalAssets();
        vm.warp(block.timestamp + 10000);
        uint256 assetsAfterAccrual = ark.totalAssets();
        console.log("assetsAfterDeposit: ", assetsAfterDeposit);
        console.log("assetsAfterAccrual: ", assetsAfterAccrual);
        assertTrue(assetsAfterAccrual > assetsAfterDeposit);
    }

    function test_BoardAndHarvest_CompoundV3_Arbitrum_fork() public {
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
        vm.prank(commander);
        ark.board(amount, bytes(""));

        uint256 assetsAfterDeposit = ark.totalAssets();
        vm.warp(block.timestamp + 10000);
        uint256 assetsAfterAccrual = ark.totalAssets();

        vm.prank(governor);
        ark.harvest(bytes(""));

        console.log("assetsAfterDeposit: ", assetsAfterDeposit);
        console.log("assetsAfterAccrual: ", assetsAfterAccrual);
        assertTrue(assetsAfterAccrual > assetsAfterDeposit);
    }
}
