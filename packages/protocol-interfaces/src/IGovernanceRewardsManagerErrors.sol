// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/* @title IGovernanceRewardsManagerErrors
 * @notice Interface defining custom errors for the Governance Rewards Manager
 */
interface IGovernanceRewardsManagerErrors {
    /* @notice Thrown when the caller is not the staking token */
    error InvalidCaller();

    /* @notice Thrown when direct staking is not allowed */
    error DirectStakingNotAllowed();
}
