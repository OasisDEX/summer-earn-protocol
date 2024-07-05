// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import {ConfigurationManager} from "../src/contracts/ConfigurationManager.sol";
import {IConfigurationManager} from "../src/interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "../src/types/ConfigurationManagerTypes.sol";
import {BaseDeploymentScript} from "./BaseDeploymentScript.s.sol";
import {AaveV3Ark} from "../src/contracts/arks/AaveV3Ark.sol";

contract AaveV3ArkDeploy is BaseDeploymentScript {
    address public constant USDC_BASE_TOKEN = 0x833589fcd6edb6e08f4c7c32d4f71b54bda02913;
    address public constant AAVE_V3_POOL_BASE = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;

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

        IArk ark = new AaveV3Ark(address(AAVE_V3_POOL_BASE), params);

        console.log("Deployed Aave V3 Ark");
        console.log(address(ark));

        vm.stopBroadcast();
    }
}
