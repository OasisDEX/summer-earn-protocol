// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import {CompoundV3Ark} from "../src/contracts/arks/CompoundV3Ark.sol";
import {ArkParams} from "../src/types/ArkTypes.sol";
import {IArk} from "../src/interfaces/IArk.sol";
import "./common/ArkDeploymentScript.s.sol";

contract CompoundV3ArkDeploy is ArkDeploymentScript {
    function run() external reloadConfig {
        vm.createSelectFork(network);
        uint256 deployerPrivateKey = _getDeployerPrivateKey();
        vm.startBroadcast(deployerPrivateKey);

        string memory tokenName = vm.envString("SYMBOL");
        require(bytes(tokenName).length > 0, "SYMBOL environment variable is empty");

        string memory lowercaseTokenName = toLowerCase(tokenName);

        string memory poolKey = string(abi.encodePacked("compound.", lowercaseTokenName, ".pool"));
        string memory rewardsKey = string(abi.encodePacked("compound.", lowercaseTokenName, ".rewards"));
        string memory tokenKey = string(abi.encodePacked("compound.", lowercaseTokenName, ".token"));

        address compoundV3Pool = _readAddressFromJson(json, network, poolKey);
        address compoundV3Rewards = _readAddressFromJson(json, network, rewardsKey);
        address compoundV3Token = _readAddressFromJson(json, network, tokenKey);

        if (compoundV3Pool == address(0)) {
            console.log("Compound V3 Pool address is not set");
            vm.stopBroadcast();
            return;
        }

        if (compoundV3Rewards == address(0)) {
            console.log("Compound V3 Rewards address is not set");
            vm.stopBroadcast();
            return;
        }

        if (compoundV3Token == address(0)) {
            console.log("Compound V3 token address is not set");
            vm.stopBroadcast();
            return;
        }

        ArkParams memory params = ArkParams({
            name: "CompoundV3Ark",
            accessManager: config.protocolAccessManager,
            configurationManager: config.configurationManager,
            token: compoundV3Token,
            maxAllocation: maxAllocation
        });

        IArk ark = new CompoundV3Ark(compoundV3Pool, compoundV3Rewards, params);

        string memory configKey = string(abi.encodePacked(tokenName, "CompoundV3Ark"));
        updateAddressInConfig(network, configKey, address(ark));

        console.log("Deployed Compound V3 Ark");
        console.log(address(ark));

        vm.stopBroadcast();
    }
}
