pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import {MaxWithdrawExecutor} from "../src/contracts/misc/MaxWithdrawExecutor.sol";

contract DeployArbManVyper is Script {
    address constant KEEPER = 0xc2a8467a52Fec8383c424149000cf384de9Ba1B5;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIV_KEY");

        vm.createSelectFork("arbitrum");
        vm.startBroadcast(deployerPrivateKey);

        MaxWithdrawExecutor maxWithdrawer = new MaxWithdrawExecutor(KEEPER);
        console.log(
            "MaxWithdrawExecutor deployed to arbitrum",
            address(maxWithdrawer)
        );
        vm.stopBroadcast();
    }
}
