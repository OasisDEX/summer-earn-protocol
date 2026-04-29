// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AdmiralsQuartersWhitelist} from "../../src/contracts/AdmiralsQuartersWhitelist.sol";
import {FleetCommanderWhitelist} from "../../src/contracts/FleetCommanderWhitelist.sol";
import {HarborCommand} from "../../src/contracts/HarborCommand.sol";
import {InstitutionalVaultRegistry} from "../../src/contracts/InstitutionalVaultRegistry.sol";
import {IInstitutionalVaultRegistry} from "../../src/interfaces/IInstitutionalVaultRegistry.sol";
import {FleetCommanderParams, FleetCommanderWhitelistParams} from "../../src/types/FleetCommanderTypes.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ProtocolAccessManagerV2} from "@summerfi/access-contracts/contracts/ProtocolAccessManagerV2.sol";
import {ConfigurationManager} from "@summerfi/config-contracts/contracts/ConfigurationManager.sol";
import {ConfigurationManagerParams} from "@summerfi/config-contracts/types/ConfigurationManagerTypes.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test} from "forge-std/Test.sol";

abstract contract FleetCommanderInstitutionalTestBase is Test {
    ProtocolAccessManagerV2 public accessManager;
    ConfigurationManager public configurationManager;
    HarborCommand public harborCommand;
    InstitutionalVaultRegistry public registry;

    address public governor = address(0x1);

    function _setupCore() internal {
        vm.startPrank(governor);
        accessManager = new ProtocolAccessManagerV2(governor);
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
        Percentage initialTipRate,
        bool isOperatorGatewayOpen
    ) internal view returns (FleetCommanderWhitelistParams memory) {
        return
            FleetCommanderWhitelistParams({
                accessManager: address(accessManager),
                configurationManager: address(configurationManager),
                initialMinimumBufferBalance: 0,
                initialRebalanceCooldown: 0,
                asset: asset,
                name: name_,
                symbol: symbol_,
                details: "institutional",
                initialTipRate: initialTipRate,
                depositCap: type(uint256).max,
                isOperatorGatewayOpen: isOperatorGatewayOpen
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
