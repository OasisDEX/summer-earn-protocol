// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import {AaveV3Ark} from "../src/contracts/arks/AaveV3Ark.sol";
import {ArkParams} from "../src/types/ArkTypes.sol";
import "./common/ArkDeploymentScript.s.sol";
import {BufferArk} from "../src/contracts/arks/BufferArk.sol";

contract BufferArkDeploy is ArkDeploymentScript {
    function run() external reloadConfig {
        vm.createSelectFork(network);

        uint256 deployerPrivateKey = _getDeployerPrivateKey();
        vm.startBroadcast(deployerPrivateKey);

        string memory tokenName = vm.envString("SYMBOL");
        require(
            bytes(tokenName).length > 0,
            "SYMBOL environment variable is empty"
        );

        string memory lowercaseTokenName = toLowerCase(tokenName);
        string memory tokenKey = string(
            abi.encodePacked("tokens.", lowercaseTokenName)
        );
        address arkAssetToken = _readAddressFromJson(json, network, tokenKey);

        if (arkAssetToken == address(0)) {
            revert("Ark asset token invalid");
        }

        if (config.protocolAccessManager == address(0)) {
            revert("Protocol access manager address not set");
        }
        if (config.configurationManager == address(0)) {
            revert("Configuration manager address not set");
        }

        ArkParams memory params = ArkParams({
            name: "BufferArk",
            accessManager: config.protocolAccessManager,
            configurationManager: config.configurationManager,
            token: arkAssetToken,
            maxAllocation: maxAllocation
        });

        BufferArk ark = new BufferArk(params);

        console.log("Deployed Buffer Ark");
        console.log(address(ark));

        string memory configKey = string(
            abi.encodePacked("bufferArk.", tokenName)
        );
        updateAddressInConfig(network, configKey, address(ark));

        vm.stopBroadcast();
    }
}
