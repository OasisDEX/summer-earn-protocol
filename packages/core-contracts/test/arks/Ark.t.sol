// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";

import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import {AaveV3Ark, ArkParams} from "../../src/contracts/arks/AaveV3Ark.sol";
import {IArkEvents} from "../../src/events/IArkEvents.sol";

import {IArkConfigProvider} from "../../src/interfaces/IArkConfigProvider.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {IFleetCommander} from "../../src/interfaces/IFleetCommander.sol";
import {IFleetCommanderConfigProvider} from "../../src/interfaces/IFleetCommanderConfigProvider.sol";
import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Test, console} from "forge-std/Test.sol";

import {ArkMock} from "../mocks/ArkMock.sol";
import {RestictedWithdrawalArkMock} from "../mocks/RestictedWithdrawalArkMock.sol";
import {ArkTestBase} from "./ArkTestBase.sol";

contract ArkTest is Test, IArkEvents, ArkTestBase {
    ArkMock public ark;
    RestictedWithdrawalArkMock public unrestrictedArk;
    ArkMock public otherArk;

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
            requiresKeeperData: false
        });

        ark = new ArkMock(params);
        otherArk = new ArkMock(params);

        params.requiresKeeperData = true;
        unrestrictedArk = new RestictedWithdrawalArkMock(params);
    }

    function test_ConstructorZ() public {
        ArkParams memory params = ArkParams({
            name: "",
            accessManager: address(0),
            configurationManager: address(0),
            token: address(0),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false
        });

        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidAccessManagerAddress(address)",
                address(0)
            )
        );
        new ArkMock(params);

        vm.expectRevert(
            abi.encodeWithSignature(
                "CannotDeployArkWithoutConfigurationManager()"
            )
        );
        params.accessManager = address(accessManager);
        new ArkMock(params);

        vm.expectRevert(
            abi.encodeWithSignature("CannotDeployArkWithoutToken()")
        );
        params.configurationManager = address(configurationManager);
        new ArkMock(params);

        vm.expectRevert(
            abi.encodeWithSignature("CannotDeployArkWithEmptyName()")
        );
        params.token = address(3);
        new ArkMock(params);

        vm.prank(governor);
        configurationManager.setRaft(address(0));
        vm.expectRevert(abi.encodeWithSignature("RaftNotSet()"));
        params.name = "TestArk";
        new ArkMock(params);

        vm.prank(governor);
        configurationManager.setRaft(raft);

        new ArkMock(params);
    }

    function test_GrantRoleDirectly_ShouldFail() public {
        // Act
        vm.expectRevert(
            abi.encodeWithSignature("DirectGrantIsDisabled(address)", governor)
        );
        vm.prank(governor);
        accessManager.grantRole(keccak256("COMMANDER_ROLE"), commander);

        // Assert
        assertTrue(ark.commander() != commander, "Commander role granted");
    }

    function test_RevokeRoleDirectly_ShouldFail() public {
        // Arrange
        vm.prank(governor);
        accessManager.grantCommanderRole(
            address(address(ark)),
            address(commander)
        );
        _mockIsArkActive(address(commander), address(ark), true);
        _mockArkCommander(address(ark), address(commander));

        // Act
        vm.expectRevert(
            abi.encodeWithSignature("DirectRevokeIsDisabled(address)", governor)
        );
        vm.prank(governor);
        accessManager.revokeRole(keccak256("COMMANDER_ROLE"), commander);

        // Assert
        assertTrue(ark.commander() == commander, "Commander role not granted");
    }

    function test_RevokeCommanderRole_ShouldSucceed() public {
        // Arrange
        vm.prank(governor);
        accessManager.grantCommanderRole(
            address(address(ark)),
            address(commander)
        );

        // Act
        vm.prank(governor);
        accessManager.revokeCommanderRole(address(address(ark)), commander);

        // Assert
        assertFalse(ark.commander() == commander, "Commander role not revoked");
    }

    function test_BoardByCommander_ShouldSucceed() public {
        vm.prank(governor);
        accessManager.grantCommanderRole(
            address(address(ark)),
            address(commander)
        );

        uint256 amount = 1000;
        mockToken.mint(commander, amount);

        vm.startPrank(commander);
        mockToken.approve(address(ark), amount);
        vm.expectEmit();
        emit Boarded(commander, address(mockToken), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        assertEq(
            mockToken.balanceOf(address(ark)),
            amount,
            "Token not transferred to ark"
        );
    }

    function test_BoardByArk_ShouldSucceed() public {
        // Arrange
        vm.prank(governor);
        accessManager.grantCommanderRole(
            address(address(ark)),
            address(commander)
        );

        uint256 amount = 1000;
        mockToken.mint(address(otherArk), amount);
        _mockArkCommander(address(ark), address(commander));
        _mockIsArkActive(address(commander), address(otherArk), true);

        // Act
        vm.startPrank(address(otherArk));
        mockToken.approve(address(ark), amount);
        vm.expectEmit();
        emit Boarded(address(otherArk), address(mockToken), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Assert
        assertEq(
            mockToken.balanceOf(address(ark)),
            amount,
            "Token not transferred to ark"
        );
    }

    function test_BoardByNonArk_ShouldFail() public {
        // Arrange
        vm.prank(governor);
        accessManager.grantCommanderRole(
            address(address(ark)),
            address(commander)
        );

        uint256 amount = 1000;
        address nonArk = address(5);
        mockToken.mint(nonArk, amount);
        _mockArkCommander(address(ark), address(commander));
        _mockIsArkActive(address(commander), nonArk, false);
        // Act && Assert
        vm.startPrank(nonArk);
        mockToken.approve(address(ark), amount);
        vm.expectRevert(
            abi.encodeWithSignature(
                "CallerIsNotAuthorizedToBoard(address)",
                nonArk
            )
        );
        ark.board(amount, bytes(""));
        vm.stopPrank();
    }

    function test_Disembark_ShouldSucceed() public {
        // Arrange
        vm.prank(governor);
        accessManager.grantCommanderRole(
            address(address(ark)),
            address(commander)
        );

        uint256 amount = 1000;
        mockToken.mint(address(ark), amount);

        // Act
        vm.startPrank(commander);
        vm.expectEmit();
        emit Disembarked(commander, address(mockToken), amount);
        ark.disembark(amount, bytes(""));
        vm.stopPrank();

        // Assert
        assertEq(
            mockToken.balanceOf(commander),
            amount,
            "Token not transferred to commander"
        );
    }

    function test_DisembarkByNonCommander_ShouldFail() public {
        // Arrange
        vm.prank(governor);
        accessManager.grantCommanderRole(
            address(address(ark)),
            address(commander)
        );

        uint256 amount = 1000;
        mockToken.mint(address(ark), amount);

        // Act && Assert
        vm.expectRevert(
            abi.encodeWithSignature(
                "CallerIsNotCommander(address)",
                address(this)
            )
        );
        ark.disembark(amount, bytes(""));
    }

    function test_Move_ShouldSucceed() public {
        // Arrange
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(address(ark)),
            address(commander)
        );
        accessManager.grantCommanderRole(
            address(address(otherArk)),
            address(commander)
        );
        vm.stopPrank();

        uint256 amount = 1000;
        mockToken.mint(address(ark), amount);
        _mockArkCommander(address(otherArk), address(commander));
        _mockIsArkActive(address(commander), address(ark), true);

        // Act
        vm.startPrank(commander);
        vm.expectEmit();
        emit Moved(address(ark), address(otherArk), address(mockToken), amount);
        ark.move(amount, address(otherArk), bytes(""), bytes(""));
        vm.stopPrank();
        // Assert

        assertEq(
            mockToken.balanceOf(address(otherArk)),
            amount,
            "Token not transferred to other ark"
        );
    }

    function test_MoveByNonCommander_ShouldFail() public {
        // Arrange
        vm.prank(governor);
        accessManager.grantCommanderRole(
            address(address(ark)),
            address(commander)
        );

        uint256 amount = 1000;
        mockToken.mint(address(ark), amount);

        // Act && Assert
        vm.expectRevert(
            abi.encodeWithSignature(
                "CallerIsNotCommander(address)",
                address(this)
            )
        );
        ark.move(amount, address(otherArk), bytes(""), bytes(""));
    }

    function test_validateCommonData() public {
        // Arrange
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(address(ark)),
            address(commander)
        );
        accessManager.grantCommanderRole(
            address(address(unrestrictedArk)),
            address(commander)
        );
        vm.stopPrank();

        uint256 amount = 1000;
        mockToken.mint(address(ark), amount);

        // Act && Assert
        vm.expectRevert(
            abi.encodeWithSignature("CannotUseKeeperDataWhenNotRequired()")
        );
        vm.prank(commander);
        ark.board(0, bytes("test data test data test data 12"));

        vm.expectRevert(abi.encodeWithSignature("KeeperDataRequired()"));
        vm.prank(commander);
        unrestrictedArk.board(0, bytes(""));
    }
}
