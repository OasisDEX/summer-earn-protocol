// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import {ProtocolAccessManager} from "../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../src/interfaces/IProtocolAccessManager.sol";
import {ConfigurationManagerParams} from "../src/types/ConfigurationManagerTypes.sol";
import {DeploymentScript} from "./DeploymentScript.s.sol";

contract ProtocolAccessManagerDeploy is DeploymentScript {
    function run() external {
        uint256 deployerPrivateKey = _getDeployerPrivateKey();
        vm.startBroadcast(deployerPrivateKey);

        IProtocolAccessManager manager = new ProtocolAccessManager(config.governor);
        console.log("Deployed Protocol Access Manager Address");
        console.log(address(manager));

        vm.stopBroadcast();
    }
}
