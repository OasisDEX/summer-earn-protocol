// SPDX-License-Identifier: MIT
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
}
