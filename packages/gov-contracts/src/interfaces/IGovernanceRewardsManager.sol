// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IGovernanceRewardsManagerErrors} from "../errors/IGovernanceRewardsManagerErrors.sol";
import {IStakingRewardsManagerBase} from "@summerfi/rewards-contracts/interfaces/IStakingRewardsManagerBase.sol";
/**
 * @title IGovernanceRewardsManager
 * @notice Interface for the GovernanceRewardsManager contract
 * @dev Manages staking and distribution of multiple reward tokens
 */
interface IGovernanceRewardsManager is
    IStakingRewardsManagerBase,
    IGovernanceRewardsManagerErrors
{
    /**
     * @notice Returns the balance of staked tokens for an account
     * @param account The address of the staker
     * @return The amount of tokens staked by the account
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @notice Updates the smoothed decay factor for an account
     * @param account The address to update the smoothed decay factor for
     */
    function updateSmoothedDecayFactor(address account) external;
}
