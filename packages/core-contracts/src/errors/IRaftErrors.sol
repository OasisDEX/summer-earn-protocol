// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

/**
 * @title IRaftErrors
 * @dev This file contains custom error definitions for the Raft contract.
 * @notice These custom errors provide more gas-efficient and informative error handling
 * compared to traditional require statements with string messages.
 */
interface IRaftErrors {
    /**
     * @notice Thrown when attempting to start an auction for an Ark and reward token pair that already has an active
     * auction
     * @param ark The address of the Ark
     * @param rewardToken The address of the reward token
     */
    error RaftAuctionAlreadyRunning(address ark, address rewardToken);

    /**
     * @notice Thrown when attempting to board rewards to an Ark that does not require keeper data
     * @param ark The address of the Ark
     */
    error RaftArkRequiresKeeperData(address ark);

    /**
     * @notice Thrown when attempting to board rewards to an Ark that requires keeper data
     * @param ark The address of the Ark
     */
    error RaftArkDoesntRequireKeeperData(address ark);
}
