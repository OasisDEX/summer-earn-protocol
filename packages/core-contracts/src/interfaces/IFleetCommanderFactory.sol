// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {FleetCommanderParams} from "../types/FleetCommanderTypes.sol";
import {FactoryArkConfig} from "../types/FleetCommanderFactoryTypes.sol";

interface IFleetCommanderFactory {
    function createFleetCommander(
        FleetCommanderParams memory params,
        FactoryArkConfig[] memory newArkConfigs
    ) external returns (address);
}
