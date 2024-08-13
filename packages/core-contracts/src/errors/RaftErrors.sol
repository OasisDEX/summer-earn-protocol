// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./CommonAuctionErrors.sol";

/**
 * @notice Thrown when attempting to start an auction for an Ark and reward token pair that already has an active auction
 * @param ark The address of the Ark
 * @param rewardToken The address of the reward token
 */
error RaftAuctionAlreadyRunning(address ark, address rewardToken);
