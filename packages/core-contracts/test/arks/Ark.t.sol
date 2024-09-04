// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";

import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import {AaveV3Ark, ArkParams} from "../../src/contracts/arks/AaveV3Ark.sol";
import {IArkEvents} from "../../src/events/IArkEvents.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {IFleetCommander} from "../../src/interfaces/IFleetCommander.sol";

import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Test, console} from "forge-std/Test.sol";

import {ArkTestHelpers} from "../helpers/ArkHelpers.sol";
import {ArkMock} from "../mocks/ArkMock.sol";

contract ArkTest is Test, IArkEvents, ArkTestHelpers {
    ArkMock public ark;
    ArkMock public otherArk;
    address public governor = address(1);
    address public commander = address(4);
    address public raft = address(2);
    ERC20Mock public mockToken;
    IProtocolAccessManager accessManager;
    IConfigurationManager configurationManager;

    function setUp() public {
        mockToken = new ERC20Mock();

        accessManager = new ProtocolAccessManager(governor);

        configurationManager = new ConfigurationManager(
            ConfigurationManagerParams({
                accessManager: address(accessManager),
                raft: raft,
                tipJar: address(0)
            })
        );

        ArkParams memory params = ArkParams({
            name: "TestArk",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: address(mockToken),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: true
        });

        ark = new ArkMock(params);
        otherArk = new ArkMock(params);
    }

    function test_Constructor() public {
        ArkParams memory params = ArkParams({
            name: "",
            accessManager: address(0),
            configurationManager: address(0),
            token: address(0),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: true
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
        vm.expectRevert(
            abi.encodeWithSignature("CannotDeployArkWithoutRaft()")
        );
        params.name = "TestArk";
        new ArkMock(params);

        vm.prank(governor);
        configurationManager.setRaft(raft);

        new ArkMock(params);
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
        ark.grantCommanderRole(address(5));

        // Assert
        assertTrue(ark.commander() != address(5), "Commander role not granted");
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

    function test_BoardByCommander_ShouldSucceed() public {
        vm.prank(governor);
        ark.grantCommanderRole(commander);

        uint256 amount = 1000;
        mockToken.mint(commander, amount);

        vm.startPrank(commander);
        mockToken.approve(address(ark), amount);
        vm.expectEmit();
        emit Boarded(commander, address(mockToken), amount);
        ark.board(amount);
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
        ark.grantCommanderRole(commander);

        uint256 amount = 1000;
        mockToken.mint(address(otherArk), amount);

        vm.mockCall(
            commander,
            abi.encodeWithSelector(
                IFleetCommander.isArkActive.selector,
                address(otherArk)
            ),
            abi.encode(true)
        );

        // Act
        vm.startPrank(address(otherArk));
        mockToken.approve(address(ark), amount);
        vm.expectEmit();
        emit Boarded(address(otherArk), address(mockToken), amount);
        ark.board(amount);
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
        ark.grantCommanderRole(commander);

        uint256 amount = 1000;
        address nonArk = address(5);
        mockToken.mint(nonArk, amount);

        vm.mockCall(
            commander,
            abi.encodeWithSelector(
                IFleetCommander.isArkActive.selector,
                nonArk
            ),
            abi.encode(false)
        );
        // Act && Assert
        vm.startPrank(nonArk);
        mockToken.approve(address(ark), amount);
        vm.expectRevert(
            abi.encodeWithSignature(
                "CallerIsNotAuthorizedToBoard(address)",
                nonArk
            )
        );
        ark.board(amount);
        vm.stopPrank();
    }

    function test_Disembark_ShouldSucceed() public {
        // Arrange
        vm.prank(governor);
        ark.grantCommanderRole(commander);

        uint256 amount = 1000;
        mockToken.mint(address(ark), amount);

        // Act
        vm.startPrank(commander);
        vm.expectEmit();
        emit Disembarked(commander, address(mockToken), amount);
        ark.disembark(amount);
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
        ark.grantCommanderRole(commander);

        uint256 amount = 1000;
        mockToken.mint(address(ark), amount);

        // Act && Assert
        vm.expectRevert(
            abi.encodeWithSignature(
                "CallerIsNotCommander(address)",
                address(this)
            )
        );
        ark.disembark(amount);
    }

    function test_Move_ShouldSucceed() public {
        // Arrange
        vm.startPrank(governor);
        ark.grantCommanderRole(commander);
        otherArk.grantCommanderRole(commander);
        vm.stopPrank();

        uint256 amount = 1000;
        mockToken.mint(address(ark), amount);

        vm.mockCall(
            commander,
            abi.encodeWithSelector(
                IFleetCommander.isArkActive.selector,
                address(ark)
            ),
            abi.encode(true)
        );
        // Act
        vm.startPrank(commander);
        vm.expectEmit();
        emit Moved(address(ark), address(otherArk), address(mockToken), amount);
        ark.move(amount, address(otherArk));
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
        ark.grantCommanderRole(commander);

        uint256 amount = 1000;
        mockToken.mint(address(ark), amount);

        // Act && Assert
        vm.expectRevert(
            abi.encodeWithSignature(
                "CallerIsNotCommander(address)",
                address(this)
            )
        );
        ark.move(amount, address(otherArk));
    }
}
