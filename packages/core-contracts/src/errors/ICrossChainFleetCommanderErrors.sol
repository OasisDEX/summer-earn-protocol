// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title ICrossChainFleetCommanderErrors
 * @dev This file contains custom error definitions for the CrossChainFleetCommander contract.
 * @notice These custom errors provide more gas-efficient and informative error handling
 * compared to traditional require statements with string messages.
 */
interface ICrossChainFleetCommanderErrors {
    /**
     * @notice Thrown when cooldown period has not been met for withdraw/redeem operations
     * @param user The address of the user attempting the operation
     * @param currentTime The current block timestamp
     * @param cooldownEndTime The timestamp when cooldown period ends
     */
    error CrossChainFleetCommanderCooldownNotMet(
        address user,
        uint256 currentTime,
        uint256 cooldownEndTime
    );
}
