// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {ConfigurationManager} from "@summerfi/config-contracts/contracts/ConfigurationManager.sol";
import {HarborCommand} from "../../src/contracts/HarborCommand.sol";
import {FleetCommanderWhitelist} from "../../src/contracts/FleetCommanderWhitelist.sol";
import {AdmiralsQuartersWhitelist} from "../../src/contracts/AdmiralsQuartersWhitelist.sol";
import {IInstitutionalVaultRegistry} from "../../src/interfaces/IInstitutionalVaultRegistry.sol";
import {InstitutionalVaultRegistry} from "../../src/contracts/InstitutionalVaultRegistry.sol";
import {ConfigurationManagerParams} from "@summerfi/config-contracts/types/ConfigurationManagerTypes.sol";
import {FleetCommanderParams} from "../../src/types/FleetCommanderTypes.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

abstract contract FleetCommanderWhitelistInstitutionalTestBase is Test {
    ProtocolAccessManager public accessManager;
    ConfigurationManager public configurationManager;
    HarborCommand public harborCommand;
    InstitutionalVaultRegistry public registry;

    address public governor = address(0x1);

    function _setupCore() internal {
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

    function _fleetParams(
        address asset,
        string memory name_,
        string memory symbol_,
        Percentage initialTipRate
    ) internal view returns (FleetCommanderParams memory) {
        return
            FleetCommanderParams({
                accessManager: address(accessManager),
                configurationManager: address(configurationManager),
                initialMinimumBufferBalance: 0,
                initialRebalanceCooldown: 0,
                asset: asset,
                name: name_,
                symbol: symbol_,
                details: "institutional",
                initialTipRate: initialTipRate,
                depositCap: type(uint256).max
            });
    }

    function _register(bytes32 id, address admiralsQuarters) internal {
        IInstitutionalVaultRegistry.Institution
            memory inst = IInstitutionalVaultRegistry.Institution({
                configurationManager: address(configurationManager),
                protocolAccessManager: address(accessManager),
                admiralsQuarters: admiralsQuarters
            });
        vm.prank(governor);
        registry.addInstitution(id, inst);
    }
}
