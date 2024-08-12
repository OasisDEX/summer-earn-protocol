// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import {Id} from "morpho-blue/interfaces/IMorpho.sol";

contract DeploymentScript is Script {
    using stdJson for string;

    uint256 private constant ANVIL_DEFAULT_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    string public network;
    address public customToken;
    Config public config;
    string public json;

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
        address aaveV3RewardsController;
        address compoundV3Pool;
        address harborCommand;
        address bufferArk;
        address tipJar;
        address swapProvider;
        MorphoBlueConfig morphoBlue;
        MetamorphoConfig metaMorpho;
        uint256 tipRate;
    }

    struct MorphoBlueConfig {
        address blue;
        Id usdcMarketId;
    }

    struct MetamorphoConfig {
        address metamorpho;
        address steakhouseUsdc;
    }

    function _readConfig(
        string memory _network_
    ) internal returns (Config memory) {
        json = vm.readFile("scripts/config.json");

        Config memory _config;
        _config.governor = _readAddressFromJson(json, _network_, "governor");
        _config.raft = _readAddressFromJson(json, _network_, "raft");
        _config.protocolAccessManager = _readAddressFromJson(
            json,
            _network_,
            "protocolAccessManager"
        );
        _config.configurationManager = _readAddressFromJson(
            json,
            _network_,
            "configurationManager"
        );
        _config.usdcToken = _readAddressFromJson(json, _network_, "usdcToken");
        _config.aaveV3Pool = _readAddressFromJson(
            json,
            _network_,
            "aaveV3.pool"
        );
        _config.aaveV3RewardsController = _readAddressFromJson(
            json,
            _network_,
            "aaveV3.rewards"
        );
        _config.compoundV3Pool = _readAddressFromJson(
            json,
            _network_,
            "compound.usdcToken"
        );
        _config.harborCommand = _readAddressFromJson(
            json,
            _network_,
            "harborCommand"
        );
        _config.morphoBlue.blue = _readAddressFromJson(
            json,
            _network_,
            "morpho.blue"
        );
        _config.morphoBlue.usdcMarketId = Id.wrap(
            _readBytes32FromJson(json, _network_, "morpho.usdcMarketId")
        );
        _config.metaMorpho.steakhouseUsdc = _readAddressFromJson(
            json,
            _network_,
            "metaMorpho.steakhouseUsdc"
        );
        _config.bufferArk = _readAddressFromJson(json, _network_, "bufferArk");
        _config.tipJar = _readAddressFromJson(json, _network_, "tipJar");
        _config.tipRate = _readUintFromJson(json, _network_, "tipRate");
        _config.swapProvider = _readAddressFromJson(
            json,
            _network_,
            "swapProvider"
        );
        return _config;
    }

    function _readAddressFromJson(
        string memory _json,
        string memory _network_,
        string memory key
    ) internal pure returns (address) {
        string memory path = string(abi.encodePacked(".", _network_, ".", key));
        return _json.readAddress(path);
    }

    function _readBytes32FromJson(
        string memory _json,
        string memory _network_,
        string memory key
    ) internal pure returns (bytes32) {
        string memory path = string(abi.encodePacked(".", _network_, ".", key));
        return _json.readBytes32(path);
    }

    function _readUintFromJson(
        string memory _json,
        string memory _network_,
        string memory key
    ) internal pure returns (uint256) {
        string memory path = string(abi.encodePacked(".", _network_, ".", key));
        return _json.readUint(path);
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

    function updateAddressInConfig(
        string memory _network,
        string memory _contractName,
        address _address
    ) internal {
        string memory contractKey = getContractKey(_network, _contractName);
        vm.writeJson(
            vm.toString(_address),
            "./scripts/config.json",
            contractKey
        );
    }

    function getContractKey(
        string memory _network,
        string memory _contractName
    ) internal pure returns (string memory) {
        string memory networkKey = string.concat(".", _network);
        string memory contractKey = string.concat(".", _contractName);
        return string.concat(networkKey, contractKey);
    }

    modifier reloadConfig() {
        _;
        config = _readConfig(network);
    }
}
