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
        Config memory _config = _readConfig(_network);

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
        address protocolAccessManager;
        address configurationManager;
        address usdcToken;
        address aaveV3Pool;
        address compoundV3Pool;
    }

    function _readConfig(
        string memory _network_
    ) internal view returns (Config memory) {
        string memory json = vm.readFile("scripts/config.json");

        Config memory _config;
        _config.governor = _readAddressFromJson(json, _network_, "governor");
        _config.raft = _readAddressFromJson(json, _network_, "raft");
        _config.protocolAccessManager = _readAddressFromJson(json, _network_, "protocolAccessManager");
        _config.configurationManager = _readAddressFromJson(json, _network_, "configurationManager");
        _config.usdcToken = _readAddressFromJson(json, _network_, "usdcToken");
        _config.aaveV3Pool = _readAddressFromJson(json, _network_, "aaveV3Pool");
        _config.compoundV3Pool = _readAddressFromJson(json, _network_, "compound.usdcToken");

        return _config;
    }

    function _readAddressFromJson(
        string memory json,
        string memory _network_,
        string memory key
    ) internal pure returns (address) {
        string memory path = string(abi.encodePacked(".", _network_, ".", key));
        return json.readAddress(path);
    }

    function _getTokenAndNetwork()
        internal
        view
        returns (string memory, address)
    {
        string memory _network = vm.envString("NETWORK");
        address _customToken;
        try vm.envAddress("TOKEN") returns (address token) {
            _customToken = token;
        } catch {
            _customToken = address(0);
        }

        return (_network, _customToken);
    }
}
