// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IArkFactoryErrors
 * @dev This file contains custom error definitions for the ArkFactory contract.
 * @notice These custom errors provide more gas-efficient and informative error handling
 * compared to traditional require statements with string messages.
 */
interface IArkFactoryErrors {
    /**
     * @notice Thrown when attempting to set the Raft address to the zero address.
     */
    error CannotSetRaftToZeroAddress();
}
