// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeploymentScript is Script {
    using stdJson for string;

    address public constant GOVERNOR =
    0xAb1a4Ae0F851700CC42442c588f458B553cB2620;
    address public constant RAFT = 0xAb1a4Ae0F851700CC42442c588f458B553cB2620;
    address public constant CONFIGURATION_MANAGER = 0x8aD75eFF83EbcB2E343b1b8d76eFBC796Cf38594;
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

    struct Config {
        address usdcToken;
        address aaveV3Pool;
        address compoundV3Pool;
    }

    function _readConfig(string memory network) internal view returns (Config memory) {
        string memory json = vm.readFile("scripts/config.json");
        string memory usdcTokenPath = string(abi.encodePacked(".", network, ".usdcToken"));
        string memory aaveV3PoolPath = string(abi.encodePacked(".", network, ".aaveV3Pool"));
        string memory compoundPoolPath = string(abi.encodePacked(".", network, ".compound.usdcToken"));

        address usdcToken = json.readAddress(usdcTokenPath);
        address aaveV3Pool = json.readAddress(aaveV3PoolPath);
        address compoundV3Pool = json.readAddress(compoundPoolPath);

        return Config(usdcToken, aaveV3Pool, compoundV3Pool);
    }

    function _getTokenAndNetwork() internal view returns (string memory, address) {
        string memory network = vm.envString("NETWORK");
        address customToken;
        try vm.envAddress("TOKEN") returns (address token) {
            customToken = token;
        } catch {
            customToken = address(0);
        }

        return (network, customToken);
    }
}
