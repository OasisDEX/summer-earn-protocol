// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import {DeploymentScript} from "./DeploymentScript.s.sol";
import {CompoundV3Ark} from "../src/contracts/arks/CompoundV3Ark.sol";
import {ArkParams} from "../src/types/ArkTypes.sol";
import {IArk} from "../src/interfaces/IArk.sol";

contract CompoundV3ArkDeploy is DeploymentScript {
    function run() external {
        uint256 deployerPrivateKey = _getDeployerPrivateKey();
        vm.startBroadcast(deployerPrivateKey);

        address arkAssetToken = customToken == address(0)
            ? config.usdcToken
            : customToken;

        ArkParams memory params = ArkParams({
            configurationManager: config.configurationManager,
            token: arkAssetToken
        });

        IArk ark = new CompoundV3Ark(config.compoundV3Pool, params);

        console.log("Deployed Compound V3 Ark");
        console.log(address(ark));

        vm.stopBroadcast();
    }
}
