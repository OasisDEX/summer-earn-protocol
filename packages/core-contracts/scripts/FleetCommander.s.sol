// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import {FleetCommander} from "../src/contracts/FleetCommander.sol";
import {IFleetCommander} from "../src/interfaces/IFleetCommander.sol";
import {FleetCommanderParams} from "../src/types/FleetCommanderTypes.sol";
import {PercentageUtils} from "../src/libraries/PercentageUtils.sol";
import {DeploymentScript} from "./DeploymentScript.s.sol";
import "../src/interfaces/IArk.sol";
contract FleetCommanderDeploy is DeploymentScript {
    using stdJson for string;

    struct FleetDefinition {
        address[] arks;
        string fleetName;
        string symbol;
    }

    function run() external reloadConfig {
        vm.createSelectFork(network);
        uint256 deployerPrivateKey = _getDeployerPrivateKey();

        vm.startBroadcast(deployerPrivateKey);

        (
            string memory fleetName,
            string memory fleetSymbol,
            address[] memory initialArks
        ) = _loadInitialArkConfigurations();

        FleetCommanderParams memory params = FleetCommanderParams({
            configurationManager: config.configurationManager,
            accessManager: config.protocolAccessManager,
            initialArks: initialArks,
            initialMinimumFundsBufferBalance: 50 * 10 ** 6,
            initialRebalanceCooldown: 3 minutes,
            asset: config.usdcToken,
            name: fleetName,
            symbol: fleetSymbol,
            initialMinimumPositionWithdrawal: PercentageUtils
                .fromDecimalPercentage(2),
            initialMaximumBufferWithdrawal: PercentageUtils
                .fromDecimalPercentage(20),
            depositCap: type(uint256).max,
            bufferArk: config.bufferArk,
            initialTipRate: 0
        });

        IFleetCommander commander = new FleetCommander(params);
        console.log("Deployed Fleet Commander Address");
        console.log(address(commander));

        for (uint256 i = 0; i < initialArks.length; i++) {
            IArk(initialArks[i]).grantCommanderRole(address(commander));
        }
        IArk(config.bufferArk).grantCommanderRole(address(commander));
        updateAddressInConfig(network, "fleetCommander", address(commander));
        vm.stopBroadcast();
    }

    function _loadInitialArkConfigurations()
        internal
        view
        returns (string memory, string memory, address[] memory)
    {
        string memory fleetDefinitionPath = _getFleetDefinitionPath();
        string memory json = vm.readFile(fleetDefinitionPath);
        string memory key = string(abi.encodePacked(".", network));
        bytes memory jsonByNetwork = json.parseRaw(key);

        FleetDefinition memory fleetDefinition = abi.decode(
            jsonByNetwork,
            (FleetDefinition)
        );

        return (
            fleetDefinition.fleetName,
            fleetDefinition.symbol,
            fleetDefinition.arks
        );
    }

    function _getFleetDefinitionPath() internal view returns (string memory) {
        string memory _definitionPath;
        try vm.envString("DEF_PATH") returns (string memory definitionPath) {
            _definitionPath = definitionPath;
        } catch {
            revert("No definition path supplied");
        }

        return _definitionPath;
    }
}
