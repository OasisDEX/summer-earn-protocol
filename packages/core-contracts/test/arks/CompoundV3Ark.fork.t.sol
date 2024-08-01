// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "../../src/contracts/arks/CompoundV3Ark.sol";
import "../../src/errors/AccessControlErrors.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import "../../src/events/IArkEvents.sol";
import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";

contract CompoundV3ArkTest is Test, IArkEvents {
    CompoundV3Ark public ark;
    address public governor = address(1);
    address public commander = address(4);
    address public raft = address(2);
    address public constant cometAddress =
        0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    IComet public comet;
    IERC20 public dai;

    uint256 forkBlock = 20276596;
    uint256 forkId;

    function setUp() public {
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        dai = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        comet = IComet(cometAddress);

        IProtocolAccessManager accessManager = new ProtocolAccessManager(
            governor
        );

        IConfigurationManager configurationManager = new ConfigurationManager(
            ConfigurationManagerParams({
                accessManager: address(accessManager),
                raft: raft
            })
        );

        ArkParams memory params = ArkParams({
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: address(dai),
            maxAllocation: type(uint256).max
        });
        ark = new CompoundV3Ark(address(comet), params);

        // Permissioning
        vm.prank(governor);
        ark.grantCommanderRole(commander);
    }

    function test_Board_CompoundV3_fork() public {
        // Arrange
        uint256 amount = 1990 * 10 ** 6;
        deal(address(dai), commander, amount);
        vm.prank(commander);
        dai.approve(address(ark), amount);

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
        emit Boarded(commander, address(dai), amount);

        // Act
        vm.prank(commander); // Execute the next call as the commander
        ark.board(amount);

        uint256 assetsAfterDeposit = ark.totalAssets();
        vm.warp(block.timestamp + 10000);
        uint256 assetsAfterAccrual = ark.totalAssets();
        console.log("assetsAfterDeposit: ", assetsAfterDeposit);
        console.log("assetsAfterAccrual: ", assetsAfterAccrual);
        assertTrue(assetsAfterAccrual > assetsAfterDeposit);
    }
}
