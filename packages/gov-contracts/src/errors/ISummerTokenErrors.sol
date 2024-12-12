// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ISummerVestingWallet} from "../interfaces/ISummerVestingWallet.sol";

/* @title ISummerTokenErrors
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
}
