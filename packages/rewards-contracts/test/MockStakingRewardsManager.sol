// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {StakingRewardsManagerBase} from "../src/contracts/StakingRewardsManagerBase.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract MockStakingRewardsManager is StakingRewardsManagerBase {
    using EnumerableSet for EnumerableSet.AddressSet;
    constructor(
        address accessManager,
        address _stakingToken
    ) StakingRewardsManagerBase(accessManager) {
        stakingToken = _stakingToken;
    }

    function stakeOnBehalfOf(address receiver, uint256 amount) external {
        _stake(_msgSender(), receiver, amount);
    }

    function unstakeAndWithdrawOnBehalfOf(
        address from,
        uint256 amount,
        bool claimRewards
    ) external {
        /* no op */
    }

    function buggedRemoveRewardToken(
        address rewardToken
    ) external onlyGovernor {
        if (!_isRewardToken(address(rewardToken))) {
            revert RewardTokenDoesNotExist();
        }

        if (block.timestamp <= rewardData[rewardToken].periodFinish) {
            revert RewardPeriodNotComplete();
        }

        // Check if all tokens have been claimed, allowing a small dust balance
        uint256 remainingBalance = IERC20(rewardToken).balanceOf(address(this));
        uint256 dustThreshold;

        try IERC20Metadata(address(rewardToken)).decimals() returns (
            uint8 decimals
        ) {
            // For tokens with 4 or fewer decimals, use a minimum threshold of 1
            // For tokens with more decimals, use 0.01% of 1 token
            if (decimals <= 4) {
                dustThreshold = 1;
            } else {
                dustThreshold = 10 ** (decimals - 4); // 0.01% of 1 token
            }
        } catch {
            dustThreshold = 1e14; // Default threshold for tokens without decimals
        }

        if (remainingBalance > dustThreshold) {
            revert RewardTokenStillHasBalance(remainingBalance);
        }

        // Remove the token from the rewardTokens map
        _rewardTokensList.remove(address(rewardToken));

        // Reset the reward data for this token
        delete rewardData[address(rewardToken)];

        emit RewardTokenRemoved(address(rewardToken));
    }
}
