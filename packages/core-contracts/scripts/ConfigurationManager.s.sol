// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import "../src/contracts/ERC721NFT.sol";

contract ConfigurationManagerDeploy is Script {
    address public constant GOVERNOR = 0xBc2e8Db797e7461D45dee36654DB3600b7D65ca2;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new ERC721NFT("NFT_Test", "TUT", GOVERNOR);

        vm.stopBroadcast();
    }
}
