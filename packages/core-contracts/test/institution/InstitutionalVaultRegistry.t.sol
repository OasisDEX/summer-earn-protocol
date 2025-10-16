// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {InstitutionalVaultRegistry} from "../../src/contracts/InstitutionalVaultRegistry.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";
import {HarborCommand} from "../../src/contracts/HarborCommand.sol";
import {IInstitutionalVaultRegistry} from "../../src/interfaces/IInstitutionalVaultRegistry.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";

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
                admiralsQuarters: aq,
                active: true
            });
    }

    function test_Add_Get_Disable_Update() public {
        bytes32 id1 = keccak256("inst-1");
        bytes32 id2 = keccak256("inst-2");

        vm.prank(governor);
        registry.addInstitution(id1, _inst(address(0xA1)));

        assertTrue(registry.exists(id1));
        assertTrue(registry.isActive(id1));
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
        registry.disableInstitution(id1);
        assertTrue(registry.exists(id1));
        assertFalse(registry.isActive(id1));
    }
}

