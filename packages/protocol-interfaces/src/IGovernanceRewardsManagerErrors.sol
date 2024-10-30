// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IGovernanceRewardsManagerErrors
 * @notice Interface defining custom errors for the Governance Rewards Manager
 */
interface IGovernanceRewardsManagerErrors {
    /**
     * @notice Thrown when the caller is not the staking token
     * @dev Used to restrict certain functions to only be callable by the staking token contract
     */
    error InvalidCaller();

    /**
     * @notice Thrown when direct staking is not allowed
     * @dev Direct staking is disabled - all staking must go through the stakeFor function
     */
    error DirectStakingNotAllowed();

    /**
     * @notice Thrown when attempting to initialize an already initialized staking token
     * @dev The staking token can only be initialized once
     */
    error StakingTokenAlreadyInitialized();

    /**
     * @notice Thrown when attempting to use the contract before initializing the staking token
     * @dev The staking token must be initialized before the contract can be used
     */
    error StakingTokenNotInitialized();
}
