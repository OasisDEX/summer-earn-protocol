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

        address arkAssetToken = customToken == address(0)
            ? config.usdcToken
            : customToken;

        ArkParams memory params = ArkParams({
            accessManager: config.protocolAccessManager,
            configurationManager: config.configurationManager,
            token: arkAssetToken,
            maxAllocation: maxAllocation
        });

        BufferArk ark = new BufferArk(params);

        console.log("Deployed Buffer Ark");
        console.log(address(ark));
        updateAddressInConfig(network, "bufferArk", address(ark));
        vm.stopBroadcast();
    }
}
