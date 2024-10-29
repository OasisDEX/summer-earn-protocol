// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IStakingRewardsManagerBase} from "./IStakingRewardsManagerBase.sol";

/**
 * @title IFleetRewardsManager
 * @notice Interface for the FleetStakingRewardsManager contract
 * @dev Extends IStakingRewardsManagerBase with Fleet-specific functionality
 */
interface IFleetRewardsManager is IStakingRewardsManagerBase {
    /**
     * @notice Returns the address of the FleetCommander contract
     * @return The address of the FleetCommander
     */
    function fleetCommander() external view returns (address);
}
