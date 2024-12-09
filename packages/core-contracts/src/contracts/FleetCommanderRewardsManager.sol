// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IFleetCommanderRewardsManager} from "../interfaces/IFleetCommanderRewardsManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StakingRewardsManagerBase} from "@summerfi/rewards-contracts/contracts/StakingRewardsManagerBase.sol";
import {IStakingRewardsManagerBase} from "@summerfi/rewards-contracts/interfaces/IStakingRewardsManagerBase.sol";

/**
 * @title FleetCommanderRewardsManager
 * @notice Contract for managing staking rewards specific to the Fleet system
 * @dev Extends StakingRewardsManagerBase with Fleet-specific functionality
 */
contract FleetCommanderRewardsManager is
    IFleetCommanderRewardsManager,
    StakingRewardsManagerBase
{
    address public immutable fleetCommander;

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

    /// @inheritdoc IStakingRewardsManagerBase
    function stakeOnBehalfOf(
        address receiver,
        uint256 amount
    ) external override updateReward(receiver) {
        _stake(_msgSender(), receiver, amount);
    }

    function unstakeOnBehalfOf(
        address from,
        address receiver,
        uint256 amount,
        bool claimRewards
    ) external override updateReward(from) {
        // Check if the caller is the same as the 'from' address or has the required role
        if (_msgSender() != from && !hasAdmiralsQuartersRole(_msgSender())) {
            revert CallerNotAdmiralsQuarters();
        }

        _unstake(from, receiver, amount);

        if (claimRewards) {
            // sends claimed rewards directly to `from` address
            _getReward(from);
        }
    }
}
