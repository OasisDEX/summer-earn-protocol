// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ArkParams, CompoundV3Ark} from "../../src/contracts/arks/CompoundV3Ark.sol";
import {Test, console} from "forge-std/Test.sol";

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";

import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import {IArkEvents} from "../../src/events/IArkEvents.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";
import {IComet} from "../../src/interfaces/compound-v3/IComet.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ArkTestBase} from "./ArkTestBase.sol";

contract CompoundV3ArkTest is Test, IArkEvents, ArkTestBase {
    CompoundV3Ark public ark;

    address public constant cometAddress =
        0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    address public constant cometRewards = address(5);
    IComet public comet;
    IERC20 public usdc;

    uint256 forkBlock = 20276596;
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        comet = IComet(cometAddress);

        ArkParams memory params = ArkParams({
            name: "TestArk",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: address(usdc),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false
        });
        ark = new CompoundV3Ark(address(comet), cometRewards, params);

        // Permissioning
        vm.prank(governor);
        ark.grantCommanderRole(commander);
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
}
