// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import {AaveV3Ark} from "../src/contracts/arks/AaveV3Ark.sol";
import {ArkParams} from "../src/types/ArkTypes.sol";
import {IArk} from "../src/interfaces/IArk.sol";
import "./common/ArkDeploymentScript.s.sol";

contract AaveV3ArkDeploy is ArkDeploymentScript {
    function run() external reloadConfig {
        vm.createSelectFork(network);
        uint256 deployerPrivateKey = _getDeployerPrivateKey();
        vm.startBroadcast(deployerPrivateKey);

        address arkAssetToken = customToken;
        require(arkAssetToken != address(0), "ark asset token invalid");

        string memory tokenName = vm.envString("SYMBOL");
        require(bytes(tokenName).length > 0, "SYMBOL environment variable is empty");

        if (config.aaveV3Pool == address(0)) {
            console.log("Aave V3 Pool address is not set");
            vm.stopBroadcast();
            return;
        }
        ArkParams memory params = ArkParams({
            name: "AaveV3Ark",
            accessManager: config.protocolAccessManager,
            configurationManager: config.configurationManager,
            token: arkAssetToken,
            maxAllocation: maxAllocation
        });

        IArk ark = new AaveV3Ark(config.aaveV3Pool, config.aaveV3RewardsController, params);

        string memory configKey = string(abi.encodePacked(tokenName, "AaveV3Ark"));
        updateAddressInConfig(network, configKey, address(ark));
        console.log("Deployed Aave V3 Ark");
        console.log(address(ark));

        vm.stopBroadcast();
    }
}
