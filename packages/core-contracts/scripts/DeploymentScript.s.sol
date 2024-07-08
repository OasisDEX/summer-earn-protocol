// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeploymentScript is Script {
    using stdJson for string;

    uint256 private constant ANVIL_DEFAULT_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    string public network;
    address public customToken;
    Config public config;

    constructor() {
        (string memory _network, address _customToken) = _getTokenAndNetwork();
        Config memory _config = _readConfig(network);

        network = _network;
        customToken = _customToken;
        config = _config;
    }

    function _getDeployerPrivateKey() internal view returns (uint256) {
        uint256 chainId = block.chainid;
        if (chainId == 31337) {
            return ANVIL_DEFAULT_PRIVATE_KEY;
        } else {
            return vm.envUint("PRIVATE_KEY");
        }
    }

    struct Config {
        address governor;
        address raft;
        address configurationManager;
        address usdcToken;
        address aaveV3Pool;
        address compoundV3Pool;
    }

    function _readConfig(
        string memory network
    ) internal view returns (Config memory) {
        string memory json = vm.readFile("scripts/config.json");

        // Governance configuration
        string memory governorPath = string(
            abi.encodePacked(".", network, ".governor")
        );
        address governor = json.readAddress(governorPath);
        string memory raftPath = string(
            abi.encodePacked(".", network, ".raft")
        );
        address raft = json.readAddress(raftPath);
        string memory configurationManagerPath = string(
            abi.encodePacked(".", network, ".configurationManager")
        );
        address configurationManager = json.readAddress(configurationManagerPath);

        // Tokens
        string memory usdcTokenPath = string(
            abi.encodePacked(".", network, ".usdcToken")
        );
        address usdcToken = json.readAddress(usdcTokenPath);

        // Protocols
        string memory aaveV3PoolPath = string(
            abi.encodePacked(".", network, ".aaveV3Pool")
        );
        address aaveV3Pool = json.readAddress(aaveV3PoolPath);

        string memory compoundPoolPath = string(
            abi.encodePacked(".", network, ".compound.usdcToken")
        );
        address compoundV3Pool = json.readAddress(compoundPoolPath);

        return Config(governor, raft, configurationManager, usdcToken, aaveV3Pool, compoundV3Pool);
    }

    function _getTokenAndNetwork()
        internal
        view
        returns (string memory, address)
    {
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
