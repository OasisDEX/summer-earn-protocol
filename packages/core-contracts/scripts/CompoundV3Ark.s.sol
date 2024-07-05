// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import {ConfigurationManager} from "../src/contracts/ConfigurationManager.sol";
import {IConfigurationManager} from "../src/interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "../src/types/ConfigurationManagerTypes.sol";
import {BaseDeploymentScript} from "./BaseDeploymentScript.s.sol";
import {CompoundV3Ark} from "../src/contracts/arks/CompoundV3Ark.sol";

contract CompoundV3ArkDeploy is BaseDeploymentScript {
    address public constant USDC_BASE_TOKEN = 0x833589fcd6edb6e08f4c7c32d4f71b54bda02913;
    address public constant COMPOUND_V3_USDC_BASE = 0xb125E6687d4313864e53df431d5425969c15Eb2F;

    function run() external {
        uint256 deployerPrivateKey = _getDeployerPrivateKey();
        vm.startBroadcast(deployerPrivateKey);

        IConfigurationManager manager = new ConfigurationManager(
            ConfigurationManagerParams({governor: GOVERNOR, raft: RAFT})
        );

        ArkParams memory params = ArkParams({
            configurationManager: CONFIGURATION_MANAGER,
            token: USDC_BASE_TOKEN
        });

        IArk ark = new CompoundV3Ark(address(COMPOUND_V3_USDC_BASE), params);

        console.log("Deployed Compound V3 Ark");
        console.log(address(ark));

        vm.stopBroadcast();
    }
}
