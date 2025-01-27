// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISummerVestingWallet} from "../interfaces/ISummerVestingWallet.sol";

/**
 * @title ISummerTokenErrors
 * @notice Interface defining custom errors for the SummerToken contract
 */
interface ISummerTokenErrors {
    /**
     * @dev Error thrown when an invalid vesting type is provided
     * @param invalidType The invalid vesting type that was provided
     */
    error InvalidVestingType(ISummerVestingWallet.VestingType invalidType);

    /**
     * @dev Error thrown when the caller is not the decay manager or governor
     * @param caller The address of the caller
     */
    error CallerIsNotAuthorized(address caller);

    /**
     * @dev Error thrown when the caller is not the decay manager
     * @param caller The address of the caller
     */
    error CallerIsNotDecayManager(address caller);

    /**
     * @dev Error thrown when the decay rate is too high
     */
    error DecayRateTooHigh(uint256 rate);

    /**
     * @dev Error thrown when the decay free window is invalid (less than 30 days or more than 365.25 days)
     * @param window The invalid window duration that was provided
     */
    error InvalidDecayFreeWindow(uint40 window);

    /**
     * @dev Error thrown when attempting to initialize the contract after it has already been initialized
     */
    error AlreadyInitialized();

    /**
     * @dev Error thrown when attempting to undelegate while staked
     */
    error CannotUndelegateWhileStaked();
}
