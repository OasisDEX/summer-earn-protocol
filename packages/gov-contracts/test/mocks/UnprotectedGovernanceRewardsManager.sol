// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {GovernanceRewardsManager} from "../../src/contracts/GovernanceRewardsManager.sol";

contract UnprotectedGovernanceRewardsManager is GovernanceRewardsManager {
    constructor(
        address _stakingToken,
        address accessManager
    ) GovernanceRewardsManager(_stakingToken, accessManager) {}

    // Stake method without updateReward modifier
    function stakeWithoutUpdateReward(
        uint256 amount
    ) external updateDecay(_msgSender()) {
        _stake(_msgSender(), _msgSender(), amount);
    }
}
