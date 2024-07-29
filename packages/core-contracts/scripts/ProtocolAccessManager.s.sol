// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import {ProtocolAccessManager} from "../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../src/interfaces/IProtocolAccessManager.sol";
import {ConfigurationManagerParams} from "../src/types/ConfigurationManagerTypes.sol";
import {DeploymentScript} from "./common/DeploymentScript.s.sol";

contract ProtocolAccessManagerDeploy is DeploymentScript {
    function run() external reloadConfig {
        vm.createSelectFork(network);
        uint256 deployerPrivateKey = _getDeployerPrivateKey();
        vm.startBroadcast(deployerPrivateKey);
        if (config.protocolAccessManager != address(0)) {
            revert("ProtocolAccessManager already deployed");
        }
        IProtocolAccessManager manager = new ProtocolAccessManager(
            config.governor
        );
        updateAddressInConfig(
            network,
            "protocolAccessManager",
            address(manager)
        );
        console.log("Deployed Protocol Access Manager Address");
        console.log(address(manager));

        vm.stopBroadcast();
    }
}
