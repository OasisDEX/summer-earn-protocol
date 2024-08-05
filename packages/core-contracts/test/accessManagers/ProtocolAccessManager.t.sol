// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";
import {CallerIsNotAdmin, CallerIsNotGovernor, CallerIsNotKeeper} from "../../src/errors/AccessControlErrors.sol";

contract ProtocolAccessManagerTest is Test {
    ProtocolAccessManager public accessManager;
    address public governor;
    address public admin;
    address public keeper;
    address public user;

    function setUp() public {
        governor = address(0x1);
        admin = address(0x2);
        keeper = address(0x3);
        user = address(0x4);

        vm.prank(governor);
        accessManager = new ProtocolAccessManager(governor);
    }

    function testConstructor() public {
        assertTrue(
            accessManager.hasRole(accessManager.DEFAULT_ADMIN_ROLE(), governor)
        );
        assertTrue(
            accessManager.hasRole(accessManager.GOVERNOR_ROLE(), governor)
        );
    }

    function testSupportsInterface() public {
        assertTrue(
            accessManager.supportsInterface(
                type(IProtocolAccessManager).interfaceId
            )
        );
    }

    function testGrantAdminRole() public {
        vm.prank(governor);
        accessManager.grantAdminRole(admin);
        assertTrue(
            accessManager.hasRole(accessManager.DEFAULT_ADMIN_ROLE(), admin)
        );
    }

    function testRevokeAdminRole() public {
        vm.startPrank(governor);
        accessManager.grantAdminRole(admin);
        accessManager.revokeAdminRole(admin);
        vm.stopPrank();
        assertFalse(
            accessManager.hasRole(accessManager.DEFAULT_ADMIN_ROLE(), admin)
        );
    }

    function testGrantGovernorRole() public {
        vm.prank(governor);
        accessManager.grantGovernorRole(user);
        assertTrue(accessManager.hasRole(accessManager.GOVERNOR_ROLE(), user));
    }

    function testRevokeGovernorRole() public {
        vm.startPrank(governor);
        accessManager.grantGovernorRole(user);
        accessManager.revokeGovernorRole(user);
        vm.stopPrank();
        assertFalse(accessManager.hasRole(accessManager.GOVERNOR_ROLE(), user));
    }

    function testGrantKeeperRole() public {
        vm.prank(governor);
        accessManager.grantKeeperRole(keeper);
        assertTrue(accessManager.hasRole(accessManager.KEEPER_ROLE(), keeper));
    }

    function testRevokeKeeperRole() public {
        vm.startPrank(governor);
        accessManager.grantKeeperRole(keeper);
        accessManager.revokeKeeperRole(keeper);
        vm.stopPrank();
        assertFalse(accessManager.hasRole(accessManager.KEEPER_ROLE(), keeper));
    }

    function testOnlyAdminModifier() public {
        vm.expectRevert(
            abi.encodeWithSelector(CallerIsNotAdmin.selector, user)
        );
        vm.prank(user);
        accessManager.grantAdminRole(user);
    }

    function testOnlyGovernorModifier() public {
        vm.expectRevert(
            abi.encodeWithSelector(CallerIsNotGovernor.selector, user)
        );
        vm.prank(user);
        accessManager.grantKeeperRole(user);
    }

    function test_GrantRoleDirectly_ShouldFail() public {
        // Act
        vm.expectRevert(
            abi.encodeWithSignature("DirectGrantIsDisabled(address)", governor)
        );
        vm.prank(governor);
        accessManager.grantRole(keccak256("KEEPER_ROLE"), keeper);
    }

    function test_RevokeRoleDirectly_ShouldFail() public {
        // Arrange
        vm.prank(governor);
        accessManager.grantKeeperRole(keeper);

        // Act
        vm.expectRevert(
            abi.encodeWithSignature("DirectRevokeIsDisabled(address)", governor)
        );
        vm.prank(governor);
        accessManager.revokeRole(keccak256("COMMANDER_ROLE"), keeper);
    }
}
