// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/contracts/SummerToken.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Create constructor params
        ISummerToken.TokenParams memory params = ISummerToken.TokenParams({
            name: "SummerToken",
            symbol: "SUMMER",
            lzEndpoint: 0x1a44076050125825900e736c501f859c50fE728c, // Base LZ Endpoint
            owner: msg.sender,
            accessManager: 0xc806342dfdfFAf86169cE72123f394d782E4246A,
            initialDecayFreeWindow: 2592000,
            initialDecayRate: 3170979200,
            initialDecayFunction: 0,
            transferEnableDate: 1731667188
        });

        // Deploy with verbose logging
        console.log("Deploying SummerToken with params:");
        console.log("Name:", params.name);
        console.log("Symbol:", params.symbol);
        console.log("LZ Endpoint:", params.lzEndpoint);
        console.log("Owner:", params.owner);

        SummerToken token = new SummerToken(params);
        console.log("SummerToken deployed at:", address(token));

        vm.stopBroadcast();
    }
}
