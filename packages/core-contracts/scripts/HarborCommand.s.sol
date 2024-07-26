// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import {DeploymentScript} from "./DeploymentScript.s.sol";
import {HarborCommand} from "../src/contracts/HarborCommand.sol";

contract HarborCommandDeploy is DeploymentScript {
    using stdJson for string;

    function run() external reloadConfig {
        vm.createSelectFork(network);
        uint256 deployerPrivateKey = _getDeployerPrivateKey();
        vm.startBroadcast(deployerPrivateKey);
        if (config.protocolAccessManager == address(0)) {
            revert("ProtocolAccessManager not deployed");
        }
        if (config.harborCommand != address(0)) {
            revert("HarborCommand already deployed");
        }
        HarborCommand harborCommand = new HarborCommand(
            config.protocolAccessManager
        );
        console.log("Deployed HarborCommand Address", address(harborCommand));
        updateAddressInConfig(network, "harborCommand", address(harborCommand));
        console.log("HarborCommand deployed and saved to config.json");
        vm.stopBroadcast();
    }
}
