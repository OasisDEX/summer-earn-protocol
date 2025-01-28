// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IFleetCommanderRewardsManagerFactory} from "../interfaces/IFleetCommanderRewardsManagerFactory.sol";
import {FleetCommanderRewardsManager} from "./FleetCommanderRewardsManager.sol";

contract FleetCommanderRewardsManagerFactory is
    IFleetCommanderRewardsManagerFactory
{
    constructor() {}

    function createRewardsManager(
        address accessManager,
        address fleetCommander
    ) external returns (address) {
        FleetCommanderRewardsManager rewardsManager = new FleetCommanderRewardsManager(
                accessManager,
                fleetCommander
            );

        emit RewardsManagerCreated(address(rewardsManager), fleetCommander);
        return address(rewardsManager);
    }
}
