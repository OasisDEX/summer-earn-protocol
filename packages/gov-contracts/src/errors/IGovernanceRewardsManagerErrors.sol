// SPDX-License-Identifier: BUSL-1.1
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
     * @notice Thrown when the stakeOnBehalfOf function is called (operation not supported)
     */
    error StakeOnBehalfOfNotSupported();

    /**
     * @notice Thrown when the UnstakeOnBehalfOfNotSupported function is called (operation not supported)
     */
    error UnstakeOnBehalfOfNotSupported();

    /**
     * @notice Thrown when the caller is not delegated
     */
    error NotDelegated();
}
