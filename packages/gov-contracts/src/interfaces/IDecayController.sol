// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IDecayController
 * @notice Interface for the DecayController contract that manages decay updates
 */
interface IDecayController {
    /**
     * @notice Error thrown when a zero address is provided for the summer token
     */
    error DecayController__ZeroAddress();

    /**
     * @notice Error thrown when the rewards manager is already set
     */
    error DecayController__RewardsManagerAlreadySet();
}
