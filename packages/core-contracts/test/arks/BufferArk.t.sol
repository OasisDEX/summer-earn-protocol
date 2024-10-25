// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ArkParams, BufferArk} from "../../src/contracts/arks/BufferArk.sol";
import {Test, console} from "forge-std/Test.sol";

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";

import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import "../../src/events/IArkEvents.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";

import {ArkTestBase} from "./ArkTestBase.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

contract BufferArkTest is Test, IArkEvents, ArkTestBase {
    BufferArk public ark;

    function setUp() public {
        initializeCoreContracts();
        ArkParams memory params = ArkParams({
            name: "TestArk",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: address(mockToken),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });
        ark = new BufferArk(params, address(commander));

        // Permissioning
        vm.prank(governor);
        accessManager.grantCommanderRole(
            address(address(ark)),
            address(commander)
        );
    }

    function test_Constructor() public {
        ArkParams memory params = ArkParams({
            name: "TestArk",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: address(mockToken),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });
        ark = new BufferArk(params, address(commander));
        assertEq(address(ark.token()), address(mockToken));
        assertEq(ark.depositCap(), type(uint256).max);
    }

    function test_Board() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 18;
        mockToken.mint(commander, amount);
        vm.prank(commander);
        mockToken.approve(address(ark), amount);

        // Expect the Boarded event to be emitted
        vm.expectEmit();
        emit Boarded(commander, address(mockToken), amount);

        // Act
        vm.prank(commander); // Execute the next call as the commander
        ark.board(amount, bytes(""));
    }

    function test_Disembark() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 18;
        mockToken.mint(address(ark), amount);

        // Expect the Disembarked event to be emitted
        vm.expectEmit();
        emit Disembarked(commander, address(mockToken), amount);

        // Act
        vm.prank(commander); // Execute the next call as the commander
        ark.disembark(amount, bytes(""));
    }
}
