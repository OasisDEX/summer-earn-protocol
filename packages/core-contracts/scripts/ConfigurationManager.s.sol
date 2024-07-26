// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import {ConfigurationManager} from "../src/contracts/ConfigurationManager.sol";
import {IConfigurationManager} from "../src/interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "../src/types/ConfigurationManagerTypes.sol";
import {DeploymentScript} from "./DeploymentScript.s.sol";

contract ConfigurationManagerDeploy is DeploymentScript {
    function run() external reloadConfig {
        vm.createSelectFork(network);
        uint256 deployerPrivateKey = _getDeployerPrivateKey();
        vm.startBroadcast(deployerPrivateKey);
        if (config.protocolAccessManager == address(0)) {
            revert("ProtocolAccessManager not deployed");
        }
        if (config.configurationManager != address(0)) {
            revert("ConfigurationManager already deployed");
        }

        IConfigurationManager manager = new ConfigurationManager(
            ConfigurationManagerParams({
                accessManager: config.protocolAccessManager,
                raft: config.raft,
                tipJar: address(0)
            })
        );
        updateAddressInConfig(
            network,
            "configurationManager",
            address(manager)
        );
        console.log("Deployed Configuration Manager Address");
        console.log(address(manager));

        vm.stopBroadcast();
    }
}
