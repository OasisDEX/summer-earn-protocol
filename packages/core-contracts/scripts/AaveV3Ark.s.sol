// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import {AaveV3Ark} from "../src/contracts/arks/AaveV3Ark.sol";
import {ArkParams} from "../src/types/ArkTypes.sol";
import {IArk} from "../src/interfaces/IArk.sol";
import "./ArkDeploymentScript.s.sol";

contract AaveV3ArkDeploy is ArkDeploymentScript {
    function run() external {
        uint256 deployerPrivateKey = _getDeployerPrivateKey();
        vm.startBroadcast(deployerPrivateKey);

        address arkAssetToken = customToken == address(0)
            ? config.usdcToken
            : customToken;

        ArkParams memory params = ArkParams({
            accessManager: config.protocolAccessManager,
            configurationManager: config.configurationManager,
            token: arkAssetToken,
            maxAllocation: maxAllocation
        });

        IArk ark = new AaveV3Ark(config.aaveV3Pool, params);

        console.log("Deployed Aave V3 Ark");
        console.log(address(ark));

        vm.stopBroadcast();
    }
}
