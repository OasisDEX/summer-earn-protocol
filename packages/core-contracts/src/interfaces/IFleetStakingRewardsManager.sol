// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "./IStakingRewardsManagerBase.sol";

/**
 * @title IFleetStakingRewardsManager
 * @notice Interface for the FleetStakingRewardsManager contract
 * @dev Extends IStakingRewardsManagerBase with Fleet-specific functionality
 */
interface IFleetStakingRewardsManager is IStakingRewardsManagerBase {
    /**
     * @notice Returns the address of the FleetCommander contract
     * @return The address of the FleetCommander
     */
    function fleetCommander() external view returns (address);
}
