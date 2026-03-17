// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {OracleRegistry} from "../src/OracleRegistry.sol";
import {RwaOracle} from "../src/RwaOracle.sol";

contract DeployRwaOracle is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address owner = vm.addr(deployerPrivateKey);

        string memory ticker = vm.envString("TICKER");
        address asset = vm.envAddress("ASSET_ADDRESS");
        string memory description = vm.envString("ORACLE_DESCRIPTION");
        address[] memory signers = vm.envAddressArray("SIGNERS");
        uint256 threshold = vm.envUint("THRESHOLD");

        // Use existing registry if provided, otherwise deploy new one
        address registryAddr = vm.envOr("REGISTRY_ADDRESS", address(0));

        vm.startBroadcast(deployerPrivateKey);

        OracleRegistry registry;
        if (registryAddr == address(0)) {
            registry = new OracleRegistry(owner);
            console.log("Deployed OracleRegistry at:", address(registry));
        } else {
            registry = OracleRegistry(registryAddr);
            console.log("Using existing OracleRegistry at:", address(registry));
        }

        RwaOracle oracle = new RwaOracle(
            description,
            signers,
            threshold,
            owner
        );
        console.log("Deployed RwaOracle for", ticker, "at:", address(oracle));

        registry.setOracle(ticker, asset, address(oracle));
        console.log("Registered oracle in registry");

        vm.stopBroadcast();
    }
}
