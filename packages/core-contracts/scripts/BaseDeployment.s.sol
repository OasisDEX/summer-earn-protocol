// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";

contract BaseDeploymentScript is Script {
    address public constant GOVERNOR =
    0xAb1a4Ae0F851700CC42442c588f458B553cB2620;
    address public constant RAFT = 0xAb1a4Ae0F851700CC42442c588f458B553cB2620;
    address public constant CONFIGURATION_MANAGER = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
    uint256 private constant ANVIL_DEFAULT_PRIVATE_KEY =
    0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function _getDeployerPrivateKey() internal view returns (uint256) {
        uint256 chainId = block.chainid;
        if (chainId == 31337) {
            return ANVIL_DEFAULT_PRIVATE_KEY;
        } else {
            return vm.envUint("PRIVATE_KEY");
        }
    }
}
