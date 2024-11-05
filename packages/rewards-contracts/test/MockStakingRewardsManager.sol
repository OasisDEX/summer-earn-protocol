// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {StakingRewardsManagerBase} from "../src/contracts/StakingRewardsManagerBase.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockStakingRewardsManager is StakingRewardsManagerBase {
    constructor(
        address accessManager,
        address _stakingToken
    ) StakingRewardsManagerBase(accessManager) {
        _initialize(IERC20(_stakingToken));
    }

    function _initialize(IERC20 _stakingToken) internal override {
        stakingToken = _stakingToken;
    }

    function stakeFor(address receiver, uint256 amount) external override {
        _stake(_msgSender(), receiver, amount);
    }
}
