// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/**
 * @title IConfigurationManagerErrors
 * @dev This file contains custom error definitions for the ConfigurationManager contract.
 * @notice These custom errors provide more gas-efficient and informative error handling
 * compared to traditional require statements with string messages.
 */
interface IConfigurationManagerErrors {
    /**
     * @notice Thrown when an operation is attempted with a zero address where a non-zero address is required.
     */
    error ZeroAddress();
}
