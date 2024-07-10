// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import {FleetCommander} from "../src/contracts/FleetCommander.sol";
import {IFleetCommander} from "../src/interfaces/IFleetCommander.sol";
import {FleetCommanderParams, ArkConfiguration} from "../src/types/FleetCommanderTypes.sol";
import {PercentageUtils} from "../src/libraries/PercentageUtils.sol";
import {DeploymentScript} from "./DeploymentScript.s.sol";

contract FleetCommanderDeploy is DeploymentScript {
    using stdJson for string;

    struct FleetDefinition {
        ArkConfiguration[] arks;
        string fleetName;
        string symbol;
    }

    function run() external {
        uint256 deployerPrivateKey = _getDeployerPrivateKey();

        vm.startBroadcast(deployerPrivateKey);

        (
            string memory fleetName,
            string memory fleetSymbol,
            ArkConfiguration[] memory initialArks
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
                .fromDecimalPercentage(20)
        });

        IFleetCommander commander = new FleetCommander(params);
        console.log("Deployed Fleet Commander Address");
        console.log(address(commander));

        vm.stopBroadcast();
    }

    function _loadInitialArkConfigurations()
        internal
        view
        returns (string memory, string memory, ArkConfiguration[] memory)
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
