// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import {CompoundV3Ark} from "../src/contracts/arks/CompoundV3Ark.sol";
import {ArkParams} from "../src/types/ArkTypes.sol";
import {IArk} from "../src/interfaces/IArk.sol";
import "./common/ArkDeploymentScript.s.sol";
import {MorphoArk} from "../src/contracts/arks/MorphoArk.sol";

contract MorphoArkDeploy is ArkDeploymentScript {
    function run() external reloadConfig {
        vm.createSelectFork(network);
        uint256 deployerPrivateKey = _getDeployerPrivateKey();
        vm.startBroadcast(deployerPrivateKey);

        address morphoBlue = _readAddressFromJson(
            json,
            network,
            "morpho.blue"
        );

        if (morphoBlue == address(0)) {
            console.log("Morpho Blue address is not set");
            vm.stopBroadcast();
            return;
        }

        string memory tokenName = vm.envString("SYMBOL");
        require(bytes(tokenName).length > 0, "SYMBOL environment variable is empty");

        string memory lowercaseTokenName = toLowerCase(tokenName);

        string memory marketKey = string(abi.encodePacked("morpho.", lowercaseTokenName, ".marketId"));
        string memory tokenKey = string(abi.encodePacked("tokens.", lowercaseTokenName));

        bytes32 marketId = _readBytes32FromJson(json, network, marketKey);
        address arkAssetToken = _readAddressFromJson(json, network, tokenKey);

        if (marketId == 0) {
            console.log("Morpho Market ID is not set");
            vm.stopBroadcast();
            return;
        }

        ArkParams memory params = ArkParams({
            name: "MorphoArk",
            accessManager: config.protocolAccessManager,
            configurationManager: config.configurationManager,
            token: arkAssetToken,
            maxAllocation: maxAllocation
        });

        IArk ark = new MorphoArk(
            morphoBlue,
            Id.wrap(marketId),
            params
        );

        string memory configKey = string(abi.encodePacked(tokenName, "MorphoArk"));
        updateAddressInConfig(network, configKey, address(ark));
        console.log("Deployed Morpho Ark");
        console.log(address(ark));

        vm.stopBroadcast();
    }
}
