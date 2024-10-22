// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "./StakingRewardsManagerBase.sol";
import {IFleetStakingRewardsManager} from "../interfaces/IFleetStakingRewardsManager.sol";

/**
 * @title FleetStakingRewardsManager
 * @notice Contract for managing staking rewards specific to the Fleet system
 * @dev Extends StakingRewardsManagerBase with Fleet-specific functionality
 */
contract FleetStakingRewardsManager is
    StakingRewardsManagerBase,
    IFleetStakingRewardsManager
{
    address public fleetCommander;

    /**
     * @notice Initializes the FleetStakingRewardsManager contract
     * @param _accessManager Address of the AccessManager contract
     * @param _fleetCommander Address of the FleetCommander contract
     */
    constructor(
        address _accessManager,
        address _fleetCommander
    ) StakingRewardsManagerBase(_accessManager) {
        fleetCommander = _fleetCommander;
        _initialize(IERC20(fleetCommander));
    }

    function _initialize(IERC20 _stakingToken) internal override {
        stakingToken = _stakingToken;
        emit StakingTokenInitialized(address(_stakingToken));
    }
}
