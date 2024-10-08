// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import {ContractSpecificRoles, IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";

import {Test} from "forge-std/Test.sol";

contract ProtocolAccessManagerTest is Test {
    TestProtocolAccessManager public accessManager;
    address public governor;
    address public admin;
    address public keeper;
    address public user;
    address public commander;
    address public curator;
    address public guardian;

    function setUp() public {
        governor = address(0x1);
        guardian = address(0x1);
        admin = address(0x2);
        keeper = address(0x3);
        user = address(0x4);
        curator = address(0x5);
        commander = address(0x6);

        vm.prank(governor);
        accessManager = new TestProtocolAccessManager(governor, guardian);
    }

    function test_Constructor() public view {
        assertTrue(
            accessManager.hasRole(accessManager.GUARDIAN_ROLE(), guardian)
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
        accessManager.grantKeeperRole(address(0), keeper);
        assertTrue(
            accessManager.hasRole(
                accessManager.generateRole(
                    ContractSpecificRoles.KEEPER_ROLE,
                    address(0)
                ),
                keeper
            )
        );
    }

    function test_RevokeKeeperRole() public {
        vm.startPrank(governor);
        accessManager.grantContractSpecificRole(
            ContractSpecificRoles.KEEPER_ROLE,
            address(0),
            keeper
        );
        accessManager.revokeKeeperRole(address(0), keeper);
        vm.stopPrank();
        assertFalse(
            accessManager.hasRole(
                accessManager.generateRole(
                    ContractSpecificRoles.KEEPER_ROLE,
                    address(0)
                ),
                keeper
            )
        );
    }

    function test_GrantCommanderRole() public {
        vm.prank(governor);
        accessManager.grantCommanderRole(address(0), commander);
    }

    function test_RevokeCommanderRole() public {
        vm.startPrank(governor);
        accessManager.grantContractSpecificRole(
            ContractSpecificRoles.COMMANDER_ROLE,
            address(0),
            commander
        );
        accessManager.revokeContractSpecificRole(
            ContractSpecificRoles.COMMANDER_ROLE,
            address(0),
            commander
        );
        vm.stopPrank();
        assertFalse(
            accessManager.hasRole(
                accessManager.generateRole(
                    ContractSpecificRoles.COMMANDER_ROLE,
                    address(0)
                ),
                commander
            )
        );
    }

    function test_GrantCuratorRole() public {
        vm.prank(governor);
        accessManager.grantContractSpecificRole(
            ContractSpecificRoles.CURATOR_ROLE,
            address(0),
            curator
        );
        assertTrue(
            accessManager.hasRole(
                accessManager.generateRole(
                    ContractSpecificRoles.CURATOR_ROLE,
                    address(0)
                ),
                curator
            )
        );
    }

    function test_RevokeCuratorRole() public {
        vm.startPrank(governor);
        accessManager.grantCuratorRole(address(0), curator);
        accessManager.revokeCuratorRole(address(0), curator);
        vm.stopPrank();
        assertFalse(
            accessManager.hasRole(
                accessManager.generateRole(
                    ContractSpecificRoles.CURATOR_ROLE,
                    address(0)
                ),
                curator
            )
        );
    }

    function test_selfRevokeCommanderRole() public {
        vm.prank(governor);
        accessManager.grantContractSpecificRole(
            ContractSpecificRoles.COMMANDER_ROLE,
            address(0),
            commander
        );
        vm.prank(commander);
        accessManager.selfRevokeContractSpecificRole(
            ContractSpecificRoles.COMMANDER_ROLE,
            address(0)
        );
        assertFalse(
            accessManager.hasRole(
                accessManager.generateRole(
                    ContractSpecificRoles.COMMANDER_ROLE,
                    address(0)
                ),
                commander
            )
        );
    }

    function test_selfRevokeContractSpecificRole_shouldFail() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "CallerIsNotContractSpecificRole(address,bytes32)",
                commander,
                accessManager.generateRole(
                    ContractSpecificRoles.COMMANDER_ROLE,
                    address(0)
                )
            )
        );
        vm.prank(commander);
        accessManager.selfRevokeContractSpecificRole(
            ContractSpecificRoles.COMMANDER_ROLE,
            address(0)
        );
    }

    function test_OnlyGovernorModifier() public {
        vm.expectRevert(
            abi.encodeWithSignature("CallerIsNotGovernor(address)", user)
        );
        vm.prank(user);
        accessManager.grantContractSpecificRole(
            ContractSpecificRoles.KEEPER_ROLE,
            address(0),
            user
        );
    }

    function test_OnlyGovernorModifier_Fail() public {
        vm.expectRevert(
            abi.encodeWithSignature("CallerIsNotGovernor(address)", user)
        );
        vm.prank(user);
        accessManager.grantContractSpecificRole(
            ContractSpecificRoles.KEEPER_ROLE,
            address(0),
            user
        );
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
        accessManager.grantContractSpecificRole(
            ContractSpecificRoles.KEEPER_ROLE,
            address(0),
            keeper
        );

        // Act
        vm.expectRevert(
            abi.encodeWithSignature("DirectRevokeIsDisabled(address)", governor)
        );
        vm.prank(governor);
        accessManager.revokeRole(keccak256("COMMANDER_ROLE"), keeper);
    }
}

contract TestProtocolAccessManager is ProtocolAccessManager {
    constructor(
        address governor,
        address guardian
    ) ProtocolAccessManager(governor, guardian) {}
}
