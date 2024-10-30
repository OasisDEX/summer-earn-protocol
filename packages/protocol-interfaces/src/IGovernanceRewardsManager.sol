// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IGovernanceRewardsManagerErrors} from "./IGovernanceRewardsManagerErrors.sol";

/**
 * @title IGovernanceRewardsManager
 * @notice Interface for the GovernanceRewardsManager contract
 * @dev Manages staking and distribution of multiple reward tokens
 *
 * Control Flow:
 * - Staking operations (stakeFor, unstakeFor) are restricted to the SummerToken contract
 * - Direct staking is not allowed to ensure synchronization with token operations
 * - Reward distribution and protocol configuration are managed through protocol access control
 * - Users can directly interact with unstaking and reward claiming functions
 */
interface IGovernanceRewardsManager is IGovernanceRewardsManagerErrors {
    /**
     * @notice Stakes tokens for a staker
     * @param staker The address of the staker
     * @param amount The amount of tokens to stake
     * @dev Can only be called by the staking token contract
     */
    function stakeFor(address staker, uint256 amount) external;

    /**
     * @notice Unstakes tokens for a staker
     * @param staker The address of the staker
     * @param amount The amount of tokens to unstake
     * @dev Can only be called by the staking token contract
     */
    function unstakeFor(address staker, uint256 amount) external;

    /**
     * @notice Returns the balance of staked tokens for an account
     * @param account The address of the staker
     * @return The amount of tokens staked by the account
     */
    function balanceOf(address account) external view returns (uint256);
}
