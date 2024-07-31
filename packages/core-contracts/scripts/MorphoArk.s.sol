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

        address arkAssetToken = customToken == address(0)
            ? config.usdcToken
            : customToken;
        if (config.morphoBlue.blue == address(0)) {
            console.log("Morpho Blue address is not set");
            vm.stopBroadcast();
            return;
        }
        if (Id.unwrap(config.morphoBlue.usdcMarketId) == 0) {
            console.log("Morpho USDC Market ID is not set");
            vm.stopBroadcast();
            return;
        }
        ArkParams memory params = ArkParams({
            accessManager: config.protocolAccessManager,
            configurationManager: config.configurationManager,
            token: arkAssetToken,
            maxAllocation: maxAllocation
        });

        IArk ark = new MorphoArk(
            config.morphoBlue.blue,
            config.morphoBlue.usdcMarketId,
            params
        );
        updateAddressInConfig(network, "morphoUsdcArk", address(ark));
        console.log("Deployed Morpho Ark");
        console.log(address(ark));

        vm.stopBroadcast();
    }
}
