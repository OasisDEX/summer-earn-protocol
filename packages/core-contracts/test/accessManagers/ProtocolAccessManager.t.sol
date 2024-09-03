// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";

import {CallerIsNotAdmin, CallerIsNotGovernor, CallerIsNotKeeper} from "../../src/errors/AccessControlErrors.sol";
import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";
import {Test} from "forge-std/Test.sol";

contract ProtocolAccessManagerTest is Test {
    TestProtocolAccessManager public accessManager;
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
        accessManager = new TestProtocolAccessManager(governor);
    }

    function test_Constructor() public view {
        assertTrue(
            accessManager.hasRole(accessManager.DEFAULT_ADMIN_ROLE(), governor)
        );
        assertTrue(
            accessManager.hasRole(accessManager.GOVERNOR_ROLE(), governor)
        );
    }

    function test_SupportsInterface() public view {
        assertTrue(
            accessManager.supportsInterface(
                type(IProtocolAccessManager).interfaceId
            )
        );
    }

    function test_GrantAdminRole() public {
        vm.prank(governor);
        accessManager.grantAdminRole(admin);
        assertTrue(
            accessManager.hasRole(accessManager.DEFAULT_ADMIN_ROLE(), admin)
        );
    }

    function test_RevokeAdminRole() public {
        vm.startPrank(governor);
        accessManager.grantAdminRole(admin);
        accessManager.revokeAdminRole(admin);
        vm.stopPrank();
        assertFalse(
            accessManager.hasRole(accessManager.DEFAULT_ADMIN_ROLE(), admin)
        );
    }

    function test_GrantSuperKeeperRole() public {
        vm.prank(governor);
        accessManager.grantSuperKeeperRole(admin);
        assertTrue(
            accessManager.hasRole(accessManager.SUPER_KEEPER_ROLE(), admin)
        );
    }

    function test_RevokeSuperKeeperRole() public {
        vm.startPrank(governor);
        accessManager.grantSuperKeeperRole(admin);
        accessManager.revokeSuperKeeperRole(admin);
        vm.stopPrank();
        assertFalse(
            accessManager.hasRole(accessManager.SUPER_KEEPER_ROLE(), admin)
        );
    }

    function test_GrantGovernorRole() public {
        vm.prank(governor);
        accessManager.grantGovernorRole(user);
        assertTrue(accessManager.hasRole(accessManager.GOVERNOR_ROLE(), user));
    }

    function test_RevokeGovernorRole() public {
        vm.startPrank(governor);
        accessManager.grantGovernorRole(user);
        accessManager.revokeGovernorRole(user);
        vm.stopPrank();
        assertFalse(accessManager.hasRole(accessManager.GOVERNOR_ROLE(), user));
    }

    function test_GrantKeeperRole() public {
        vm.prank(governor);
        accessManager.grantKeeperRole(keeper);
        assertTrue(accessManager.hasRole(accessManager.KEEPER_ROLE(), keeper));
    }

    function test_RevokeKeeperRole() public {
        vm.startPrank(governor);
        accessManager.grantKeeperRole(keeper);
        accessManager.revokeKeeperRole(keeper);
        vm.stopPrank();
        assertFalse(accessManager.hasRole(accessManager.KEEPER_ROLE(), keeper));
    }

    function test_OnlyAdminModifier() public {
        vm.expectRevert(
            abi.encodeWithSelector(CallerIsNotAdmin.selector, user)
        );
        vm.prank(user);
        accessManager.grantAdminRole(user);
    }

    function test_OnlyGovernorModifier() public {
        vm.expectRevert(
            abi.encodeWithSelector(CallerIsNotGovernor.selector, user)
        );
        vm.prank(user);
        accessManager.grantKeeperRole(user);
    }

    function test_OnlyGovernorModifier_Fail() public {
        vm.expectRevert(
            abi.encodeWithSelector(CallerIsNotGovernor.selector, user)
        );
        vm.prank(user);
        accessManager.grantKeeperRole(user);
    }

    function test_OnlyKeeperModifier_Fail() public {
        vm.expectRevert(
            abi.encodeWithSelector(CallerIsNotKeeper.selector, user)
        );
        vm.prank(user);
        accessManager.dummyKeeperFunction();
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

contract TestProtocolAccessManager is ProtocolAccessManager {
    constructor(address governor) ProtocolAccessManager(governor) {}

    // Add this dummy function for testing purposes
    function dummyKeeperFunction() external onlyKeeper {
        // This function doesn't need to do anything
    }
}
