// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import {FleetCommander} from "../src/contracts/FleetCommander.sol";
import {IFleetCommander} from "../src/interfaces/IFleetCommander.sol";
import {FleetCommanderParams, ArkConfiguration} from "../src/types/FleetCommanderTypes.sol";
import {PercentageUtils} from "../src/libraries/PercentageUtils.sol";
import {BaseDeploymentScript} from "./BaseDeploymentScript.s.sol";

contract FleetCommanderDeploy is BaseDeploymentScript {
    function run() external {
        uint256 deployerPrivateKey = _getDeployerPrivateKey();

        vm.startBroadcast(deployerPrivateKey);

        ArkConfiguration[] memory initialArks = new ArkConfiguration[](2);
        initialArks[0] = ArkConfiguration({
            ark: address(1),
            maxAllocation: 5000000
        });
        initialArks[1] = ArkConfiguration({
            ark: address(2),
            maxAllocation: 5000000
        });

        FleetCommanderParams memory params = FleetCommanderParams({
            configurationManager: CONFIGURATION_MANAGER,
            initialArks: initialArks,
            initialMinFundsBufferBalance: 50 * 10 ** 6,
            initialRebalanceCooldown: 3 minutes,
            asset: USDC,
            name: "FleetCommander_BaseUSDC",
            symbol: "FCBUSD",
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
}
