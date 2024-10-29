// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IGovernanceRewardsManagerErrors} from "./IGovernanceRewardsManagerErrors.sol";

/**
 * @title IGovernanceRewardsManager
 * @notice Interface for the GovernanceRewardsManager contract
 * @dev Manages staking and distribution of multiple reward tokens
 */
interface IGovernanceRewardsManager is IGovernanceRewardsManagerErrors {
    /**
     * @notice Stakes tokens for a staker
     * @param staker The address of the staker
     * @param amount The amount of tokens to stake
     */
    function stakeFor(address staker, uint256 amount) external;

    /**
     * @notice Unstakes tokens for a staker
     * @param staker The address of the staker
     * @param amount The amount of tokens to unstake
     */
    function unstakeFor(address staker, uint256 amount) external;

    /**
     * @notice Returns the balance of a staker
     * @param account The address of the staker
     * @return The balance of the staker
     */
    function balanceOf(address account) external view returns (uint256);
}
