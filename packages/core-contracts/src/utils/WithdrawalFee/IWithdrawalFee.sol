// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

/**
 * @title IWithdrawalFee
 * @notice Interface for withdrawal fee functionality
 * @dev Provides configurable withdrawal fees to protect against MEV/flash loan attacks
 */
interface IWithdrawalFee {
    /**
     * EVENTS
     */

    /**
     * @notice Emitted when the withdrawal fee is updated
     * @param previousFee The previous withdrawal fee percentage
     * @param newFee The new withdrawal fee percentage
     */
    event WithdrawalFeeUpdated(Percentage previousFee, Percentage newFee);

    /**
     * @notice Emitted when a withdrawal fee is collected
     * @param user The address of the user who paid the fee
     * @param assets The total assets that were being withdrawn
     * @param feeAmount The amount of assets collected as fee
     */
    event WithdrawalFeeCollected(
        address indexed user,
        uint256 assets,
        uint256 feeAmount
    );

    /**
     * ERRORS
     */

    /**
     * @notice Error thrown when the withdrawal fee is too high
     */
    error WithdrawalFeeTooHigh();

    /**
     * VIEW FUNCTIONS
     */

    /**
     * @notice Returns the current withdrawal fee percentage
     * @return The current withdrawal fee as a Percentage
     */
    function getWithdrawalFee() external view returns (Percentage);
}
