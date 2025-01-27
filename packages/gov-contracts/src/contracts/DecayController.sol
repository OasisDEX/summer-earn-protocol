// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISummerToken} from "../interfaces/ISummerToken.sol";
import {IDecayController} from "../interfaces/IDecayController.sol";
import {IGovernanceRewardsManager} from "../interfaces/IGovernanceRewardsManager.sol";

/**
 * @title DecayController
 * @notice Manages decay updates for governance rewards and voting power
 */
abstract contract DecayController is IDecayController {
    ISummerToken private immutable _summerToken;
    IGovernanceRewardsManager private _rewardsManager;

    constructor(address summerToken_) {
        if (summerToken_ == address(0)) {
            revert DecayController__ZeroAddress();
        }
        _summerToken = ISummerToken(summerToken_);
    }

    /**
     * @notice Internal function to set the rewards manager address
     * @dev This function must be called by the inheriting contract after deployment
     * to avoid circular dependencies, as both DecayController and GovernanceRewardsManager
     * need to reference each other. The pattern used is:
     * 1. Deploy DecayController (with rewardsManager unset)
     * 2. Deploy GovernanceRewardsManager (which can reference DecayController)
     * 3. Call this function to set rewardsManager address
     * @param rewardsManager_ Address of the GovernanceRewardsManager contract
     */
    function _setRewardsManager(address rewardsManager_) internal {
        if (rewardsManager_ == address(0)) {
            revert DecayController__ZeroAddress();
        }
        if (address(_rewardsManager) != address(0)) {
            revert DecayController__RewardsManagerAlreadySet();
        }
        _rewardsManager = IGovernanceRewardsManager(rewardsManager_);
    }

    function _updateDecay(address account) internal {
        if (account != address(0)) {
            _summerToken.updateDecayFactor(account);
            _rewardsManager.updateSmoothedDecayFactor(account);
        }
    }

    /**
     * @notice Modifier to update decay before executing a function
     * @param account Address to update decay for
     * @dev Updates both base decay and smoothed decay factors
     */
    modifier updateDecay(address account) {
        _updateDecay(account);
        _;
    }
}
