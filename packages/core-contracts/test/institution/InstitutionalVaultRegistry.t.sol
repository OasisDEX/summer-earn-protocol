// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {InstitutionalVaultRegistry} from "../../src/contracts/InstitutionalVaultRegistry.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {ConfigurationManager} from "@summerfi/config-contracts/contracts/ConfigurationManager.sol";
import {HarborCommand} from "../../src/contracts/HarborCommand.sol";
import {IInstitutionalVaultRegistry} from "../../src/interfaces/IInstitutionalVaultRegistry.sol";
import {IInstitutionalVaultRegistryErrors} from "../../src/interfaces/IInstitutionalVaultRegistryErrors.sol";
import {ConfigurationManagerParams} from "@summerfi/config-contracts/types/ConfigurationManagerTypes.sol";

contract InstitutionalVaultRegistryTest is Test {
    ProtocolAccessManager public accessManager;
    ConfigurationManager public configurationManager;
    HarborCommand public harborCommand;
    InstitutionalVaultRegistry public registry;
    address public governor = address(0x1);

    function setUp() public {
        vm.startPrank(governor);
        accessManager = new ProtocolAccessManager(governor);
        harborCommand = new HarborCommand(address(accessManager));
        configurationManager = new ConfigurationManager(address(accessManager));
        configurationManager.initializeConfiguration(
            ConfigurationManagerParams({
                raft: address(0x2),
                tipJar: address(0x3),
                treasury: address(0x4),
                harborCommand: address(harborCommand),
                fleetCommanderRewardsManagerFactory: address(0x5)
            })
        );
        registry = new InstitutionalVaultRegistry(governor);
        vm.stopPrank();
    }

    function _inst(
        address aq
    ) internal view returns (IInstitutionalVaultRegistry.Institution memory) {
        return
            IInstitutionalVaultRegistry.Institution({
                configurationManager: address(configurationManager),
                protocolAccessManager: address(accessManager),
                admiralsQuarters: aq
            });
    }

    function test_Add_Get_Remove_Update() public {
        bytes32 id1 = bytes32("inst-1");
        bytes32 id2 = bytes32("inst-2");

        vm.prank(governor);
        registry.addInstitution(id1, _inst(address(0xA1)));

        assertTrue(registry.exists(id1));
        assertEq(
            registry.getConfigurationManager(id1),
            address(configurationManager)
        );
        assertEq(
            registry.getProtocolAccessManager(id1),
            address(accessManager)
        );
        assertEq(registry.getHarborCommand(id1), address(harborCommand));
        assertEq(registry.getAdmiralsQuarters(id1), address(0xA1));

        vm.prank(governor);
        registry.updateAdmiralsQuarters(id1, address(0xA2));
        assertEq(registry.getAdmiralsQuarters(id1), address(0xA2));

        vm.prank(governor);
        registry.removeInstitution(id1);
        assertFalse(registry.exists(id1));
    }

    function test_Exists_False_Initially() public {
        bytes32 unknown = bytes32("unknown");
        assertFalse(registry.exists(unknown), "exists should be false");
    }

    function test_AddInstitution_Reverts_On_ZeroAddress() public {
        bytes32 id = bytes32("inst-zero");
        IInstitutionalVaultRegistry.Institution
            memory bad = IInstitutionalVaultRegistry.Institution({
                configurationManager: address(configurationManager),
                protocolAccessManager: address(accessManager),
                admiralsQuarters: address(0)
            });

        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IInstitutionalVaultRegistryErrors.AddressZero.selector
            )
        );
        registry.addInstitution(id, bad);
    }

    function test_AddInstitution_Reverts_On_Duplicate() public {
        bytes32 id = bytes32("dup");
        vm.prank(governor);
        registry.addInstitution(id, _inst(address(0xAA)));

        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IInstitutionalVaultRegistryErrors
                    .InstitutionAlreadyExists
                    .selector,
                id
            )
        );
        registry.addInstitution(id, _inst(address(0xAB)));
    }

    function test_GetInstitution_Reverts_When_NotFound() public {
        bytes32 id = bytes32("ghost");
        vm.expectRevert(
            abi.encodeWithSelector(
                IInstitutionalVaultRegistryErrors.InstitutionNotFound.selector,
                id
            )
        );
        registry.getInstitution(id);
    }

    function test_RemoveInstitution_Reverts_When_NotFound() public {
        bytes32 id = bytes32("missing");
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IInstitutionalVaultRegistryErrors.InstitutionNotFound.selector,
                id
            )
        );
        registry.removeInstitution(id);
    }

    function test_RemoveInstitution_Reverts_When_AlreadyRemoved() public {
        bytes32 id = bytes32("inst");
        vm.prank(governor);
        registry.addInstitution(id, _inst(address(0xA1)));

        vm.prank(governor);
        registry.removeInstitution(id);

        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IInstitutionalVaultRegistryErrors.InstitutionNotFound.selector,
                id
            )
        );
        registry.removeInstitution(id);
    }

    function test_UpdateAdmiralsQuarters_Reverts_When_NotFound() public {
        bytes32 id = bytes32("none");
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IInstitutionalVaultRegistryErrors.InstitutionNotFound.selector,
                id
            )
        );
        registry.updateAdmiralsQuarters(id, address(0xA2));
    }

    function test_UpdateAdmiralsQuarters_Reverts_When_Removed() public {
        bytes32 id = bytes32("removed");
        vm.prank(governor);
        registry.addInstitution(id, _inst(address(0xA1)));

        vm.prank(governor);
        registry.removeInstitution(id);

        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IInstitutionalVaultRegistryErrors.InstitutionNotFound.selector,
                id
            )
        );
        registry.updateAdmiralsQuarters(id, address(0xA2));
    }

    function test_UpdateAdmiralsQuarters_Reverts_When_ZeroAddress() public {
        bytes32 id = bytes32("zero-update");
        vm.prank(governor);
        registry.addInstitution(id, _inst(address(0xA1)));

        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IInstitutionalVaultRegistryErrors.AddressZero.selector
            )
        );
        registry.updateAdmiralsQuarters(id, address(0));
    }

    function test_UpdateAdmiralsQuarters_Reverts_When_SameAddress() public {
        bytes32 id = bytes32("same");
        vm.prank(governor);
        registry.addInstitution(id, _inst(address(0xA1)));

        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IInstitutionalVaultRegistryErrors.SameAddress.selector
            )
        );
        registry.updateAdmiralsQuarters(id, address(0xA1));
    }
}
