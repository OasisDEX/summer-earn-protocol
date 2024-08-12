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
        address daiToken;
        address aaveV3Pool;
        address aaveV3RewardsController;
        address compoundV3UsdcPool;
        address compoundV3UsdcRewards;
        address harborCommand;
        address usdcBufferArk;
        address daiBufferArk;
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
        // CORE
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
        _config.harborCommand = _readAddressFromJson(
            json,
            _network_,
            "harborCommand"
        );
        _config.usdcBufferArk = _readAddressFromJson(json, _network_, "bufferArk.usdc");
        _config.daiBufferArk = _readAddressFromJson(json, _network_, "bufferArk.dai");

        _config.tipJar = _readAddressFromJson(json, _network_, "tipJar");
        _config.tipRate = _readUintFromJson(json, _network_, "tipRate");
        _config.swapProvider = _readAddressFromJson(
            json,
            _network_,
            "swapProvider"
        );

        // Tokens
        _config.usdcToken = _readAddressFromJson(json, _network_, "tokens.usdc");
        _config.daiToken = _readAddressFromJson(json, _network_, "tokens.dai");

        // AAVE V3
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

        // META MORPHO
        _config.metaMorpho.steakhouseUsdc = _readAddressFromJson(
            json,
            _network_,
            "metaMorpho.steakhouseUsdc"
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

    function toLowerCase(string memory str) internal pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint i = 0; i < bStr.length; i++) {
            if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }

    modifier reloadConfig() {
        _;
        config = _readConfig(network);
    }
}
