// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import {FleetCommander} from "../src/contracts/FleetCommander.sol";
import {IFleetCommander} from "../src/interfaces/IFleetCommander.sol";
import {FleetCommanderParams, ArkConfiguration} from "../src/types/FleetCommanderTypes.sol";
import {PercentageUtils} from "../src/libraries/PercentageUtils.sol";
import {DeploymentScript} from "./DeploymentScript.s.sol";

contract FleetCommanderDeploy is BaseDeploymentScript {
    address public constant USDC_BASE_TOKEN =
        0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address[] public ARK_ADDRESSES = [address(1), address(2)];

    function run() external {
        uint256 deployerPrivateKey = _getDeployerPrivateKey();

        vm.startBroadcast(deployerPrivateKey);

        (
            string memory fleetName,
            string memory fleetSymbol,
            ArkConfiguration[] memory initialArks
        ) = _loadInitialArkConfigurations();

        FleetCommanderParams memory params = FleetCommanderParams({
            configurationManager: CONFIGURATION_MANAGER,
            initialArks: initialArks,
            initialMinFundsBufferBalance: 50 * 10 ** 6,
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
        returns (string, string, ArkConfiguration[])
    {
        string memory fleetDefinitionPath = _getFleetDefinitionPath();
        string memory json = vm.readFile(fleetDefinitionPath);

        // Paths
        string memory fleetNamePath = string(
            abi.encodePacked(".", network, ".fleetName")
        );
        string memory symbolPath = string(
            abi.encodePacked(".", network, ".symbol")
        );
        string memory arksPath = string(
            abi.encodePacked(".", network, ".arks")
        );

        // Read
        string memory fleetName = json.readString(fleetNamePath);
        string memory symbol = json.readString(symbolPath);

        bytes memory parsedJson = vm.parseJson(arksPath);
        ArkConfiguration[] memory initialArks = abi.decode(
            parsedJson,
            (ArkConfiguration[])
        );

        return (fleetName, symbol, initialArks);
    }

    function _getFleetDefinitionPath() internal returns (string) {
        string memory _definitionPath;
        try vm.envString("DEF_PATH") returns (string definitionPath) {
            _definitionPath = definitionPath;
        } catch {
            revert("No definition path supplied");
        }

        return _definitionPath;
    }
}
