// SPDX-License-Identifier: BUSL-1.1
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
     * @notice Returns the wrapped staking token
     * @return The wrapped staking token
     */
    function wrappedStakingToken() external view returns (address);

    /**
     * @notice Emitted when unstakeAndWithdrawOnBehalfOf is called (operation not supported)
     * @param owner The address that owns the staked tokens
     * @param receiver The address that would have received the unstaked tokens
     * @param amount The amount of tokens that was attempted to be unstaked
     */
    event UnstakeOnBehalfOfIgnored(
        address indexed owner,
        address indexed receiver,
        uint256 amount
    );

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

    /**
     * @notice Calculates the smoothed decay factor for a given account without modifying state
     * @param account The address of the account to calculate for
     * @return The calculated smoothed decay factor
     */
    function calculateSmoothedDecayFactor(
        address account
    ) external view returns (uint256);
}
