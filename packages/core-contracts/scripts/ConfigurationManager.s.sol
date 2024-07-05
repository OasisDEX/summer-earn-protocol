// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import {ConfigurationManager} from "../src/contracts/ConfigurationManager.sol";
import {IConfigurationManager} from "../src/interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "../src/types/ConfigurationManagerTypes.sol";
import {BaseDeploymentScript} from "./BaseDeploymentScript.s.sol";

contract ConfigurationManagerDeploy is BaseDeploymentScript {
    function run() external {
        uint256 deployerPrivateKey = _getDeployerPrivateKey();
        vm.startBroadcast(deployerPrivateKey);

        IConfigurationManager manager = new ConfigurationManager(
            ConfigurationManagerParams({governor: GOVERNOR, raft: RAFT})
        );
        console.log("Deployed Configuration Manager Address");
        console.log(address(manager));

        vm.stopBroadcast();
    }
}
