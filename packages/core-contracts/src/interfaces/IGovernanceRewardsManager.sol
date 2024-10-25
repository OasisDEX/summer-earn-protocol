// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStakingRewardsManagerBase} from "./IStakingRewardsManagerBase.sol";
import {ISummerGovernor} from "@summerfi/earn-gov-contracts/interfaces/ISummerGovernor.sol";
import {IGovernanceRewardsManagerErrors} from "../errors/IGovernanceRewardsManagerErrors.sol";
/**
 * @title IGovernanceRewardsManager
 * @notice Interface for the GovernanceRewardsManager contract
 * @dev Manages staking and distribution of multiple reward tokens
 */
interface IGovernanceRewardsManager is
    IGovernanceRewardsManagerErrors,
    IStakingRewardsManagerBase
{
    /**
     * @notice Returns the address of the SummerGovernor contract
     * @return The address of the SummerGovernor
     */
    function governor() external view returns (ISummerGovernor);

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
}
