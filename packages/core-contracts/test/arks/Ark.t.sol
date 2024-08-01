// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "../../src/contracts/arks/AaveV3Ark.sol";
import "../../src/errors/AccessControlErrors.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import "../../src/events/IArkEvents.sol";
import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";
import {DataTypes} from "../../src/interfaces/aave-v3/DataTypes.sol";
import {ArkMock} from "../mocks/ArkMock.sol";
import {ArkTestHelpers} from "../helpers/ArkHelpers.sol";

contract AaveV3ArkTest is Test, IArkEvents, ArkTestHelpers {
    ArkMock public ark;
    address public governor = address(1);
    address public commander = address(4);
    address public raft = address(2);
    ERC20Mock public mockToken;

    function setUp() public {
        mockToken = new ERC20Mock();

        IProtocolAccessManager accessManager = new ProtocolAccessManager(
            governor
        );

        IConfigurationManager configurationManager = new ConfigurationManager(
            ConfigurationManagerParams({
                accessManager: address(accessManager),
                raft: raft,
                tipJar: address(0)
            })
        );

        ArkParams memory params = ArkParams({
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: address(mockToken),
            maxAllocation: type(uint256).max
        });

        ark = new ArkMock(params);
    }

    function test_GrantCommanderRole_ShouldSucceed() public {
        // Act
        vm.prank(governor);
        ark.grantCommanderRole(commander);

        // Assert
        assertTrue(ark.commander() == commander, "Commander role not granted");
    }

    function test_GrantCommanderRole_ShouldFail() public {
        // Arrange
        vm.prank(governor);
        ark.grantCommanderRole(commander);

        vm.expectRevert(
            abi.encodeWithSignature("CannotAddCommanderToArkWithCommander()")
        );

        // Act
        vm.prank(governor);
        ark.grantCommanderRole(commander);

        // Assert
        assertTrue(ark.commander() == commander, "Commander role not granted");
    }

    function test_GrantRoleDirectly_ShouldFail() public {
        // Act
        vm.expectRevert(
            abi.encodeWithSignature("DirectGrantIsDisabled(address)", governor)
        );
        vm.prank(governor);
        ark.grantRole(keccak256("COMMANDER_ROLE"), commander);

        // Assert
        assertTrue(ark.commander() != commander, "Commander role granted");
    }

    function test_RevokeRoleDirectly_ShouldFail() public {
        // Arrange
        vm.prank(governor);
        ark.grantCommanderRole(commander);

        // Act
        vm.expectRevert(
            abi.encodeWithSignature("DirectRevokeIsDisabled(address)", governor)
        );
        vm.prank(governor);
        ark.revokeRole(keccak256("COMMANDER_ROLE"), commander);

        // Assert
        assertTrue(ark.commander() == commander, "Commander role not granted");
    }

    function test_RevokeCommanderRole_ShouldSucceed() public {
        // Arrange
        vm.prank(governor);
        ark.grantCommanderRole(commander);

        // Act
        vm.prank(governor);
        ark.revokeCommanderRole(commander);

        // Assert
        assertFalse(ark.commander() == commander, "Commander role not revoked");
    }

    function test_RevokeCommanderRole_ShouldFail() public {
        // Arrange
        vm.prank(governor);
        ark.grantCommanderRole(commander);
        mockArkTotalAssets(address(ark), 1000);

        // Act
        vm.expectRevert(
            abi.encodeWithSignature("CannotRemoveCommanderFromArkWithAssets()")
        );
        vm.prank(governor);
        ark.revokeCommanderRole(commander);

        // Assert
        assertTrue(ark.commander() == commander, "Commander role not revoked");
    }
}
