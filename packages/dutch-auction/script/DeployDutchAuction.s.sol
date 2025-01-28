// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.25 <0.9.0;

import {DutchAuctionManager} from "../src/DutchAuctionManager.sol";
import {Script, console} from "forge-std/Script.sol";

contract DeployDutchAuction is Script {
    address public deployedAddress;

    /// @dev Default private key to use if neither $PRIVATE_KEY nor $MNEMONIC is set.
    uint256 internal constant DEFAULT_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    /// @dev Needed for the deterministic deployments.
    bytes32 internal constant ZERO_SALT = bytes32(0);

    /// @dev The address of the transaction broadcaster.
    address public broadcaster;

    constructor() {
        uint256 privateKey = vm.envOr({
            name: "PRIVATE_KEY",
            defaultValue: DEFAULT_PRIVATE_KEY
        });
        broadcaster = vm.addr(privateKey);
    }

    function test() public {}

    modifier broadcast() {
        vm.startBroadcast(broadcaster);
        _;
        vm.stopBroadcast();
    }

    function getDeployedAddress() public view returns (address) {
        return deployedAddress;
    }

    function run() public broadcast {
        DutchAuctionManager auctionManager = new DutchAuctionManager();
        deployedAddress = address(auctionManager);
        console.log(
            "DutchAuctionManager deployed at:",
            address(auctionManager)
        );
    }
}
