// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IWithdrawalFee} from "./IWithdrawalFee.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {Constants} from "@summerfi/constants/Constants.sol";

/**
 * @title WithdrawalFee
 * @custom:see IWithdrawalFee
 * @notice Abstract contract that provides withdrawal fee functionality
 * @dev A recommended initial fee of 0.025% is based on protecting against arbitrage on a 5% APY over ~48 hours.
 *      Calculation: 5% annual / 365 days * 2 days / 2 (as deterrent) ≈ 0.0274% → rounded to 0.025%
 *      This fee serves as MEV/flash loan attack protection and benefits remaining vault participants.
 */
abstract contract WithdrawalFee is IWithdrawalFee {
    using PercentageUtils for uint256;

    /**
     * STATE VARIABLES
     */

    /**
     * @notice The current withdrawal fee percentage
     * @dev Stored as a Percentage type with 18 decimals of precision
     */
    Percentage internal _withdrawalFee;

    /**
     * @notice The maximum allowed withdrawal fee (10%)
     * @dev Prevents governance abuse by capping the maximum fee
     */
    uint256 private constant MAXIMUM_WITHDRAWAL_FEE = 10 * Constants.WAD; // 10% = 10 * 1e18

    /**
     * CONSTRUCTOR
     */

    /**
     * @notice Initializes the withdrawal fee
     * @param initialFee The initial withdrawal fee percentage (recommended: 0.025%)
     * @dev Recommended initial fee of 0.025% = 25000000000000000 (0.00025 * 1e18)
     */
    constructor(Percentage initialFee) {
        _validateWithdrawalFee(initialFee);
        _withdrawalFee = initialFee;
    }

    /**
     * VIEW FUNCTIONS
     */

    /// @inheritdoc IWithdrawalFee
    function getWithdrawalFee() external view virtual returns (Percentage) {
        return _withdrawalFee;
    }

    /**
     * INTERNAL FUNCTIONS
     */

    /**
     * @notice Calculates the withdrawal fee for a given amount of assets
     * @param assets The total amount of assets for which to calculate the fee
     * @return The calculated fee amount
     * @dev The fee mechanism works by:
     *      1. User burns the full amount of shares corresponding to their withdrawal
     *      2. User receives assets minus the fee amount
     *      3. The fee amount remains in the vault, increasing value for remaining shareholders
     *      This is standard ERC4626 behavior for withdrawal fees and ensures proper MEV protection.
     */
    function _calculateWithdrawalFee(
        uint256 assets
    ) internal view returns (uint256) {
        if (Percentage.unwrap(_withdrawalFee) == 0) {
            return 0;
        }
        return assets.applyPercentage(_withdrawalFee);
    }

    /**
     * @notice Calculates the withdrawal fee for a given amount of shares
     * @param shares The total amount of shares for which to calculate the fee
     * @return The calculated fee amount in shares
     * @dev The fee mechanism works by:
     *      1. Fee is calculated as a percentage of the shares being redeemed
     *      2. Fee shares are transferred to the tipJar
     *      3. User burns only the remaining shares (shares - feeShares)
     *      4. This approach eliminates MEV opportunities by not affecting share price
     *      and properly routes protocol fees to the tipJar.
     */
    function _calculateWithdrawalFeeShares(
        uint256 shares
    ) public view returns (uint256) {
        if (Percentage.unwrap(_withdrawalFee) == 0) {
            return 0;
        }
        return shares.applyPercentage(_withdrawalFee);
    }

    /**
     * @notice Updates the withdrawal fee
     * @param newFee The new withdrawal fee percentage
     * @dev The function is internal so it can be wrapped with access modifiers if needed
     */
    function _updateWithdrawalFee(Percentage newFee) internal {
        _validateWithdrawalFee(newFee);
        Percentage previousFee = _withdrawalFee;
        _withdrawalFee = newFee;
        emit WithdrawalFeeUpdated(previousFee, newFee);
    }

    /**
     * @notice Validates that the withdrawal fee is within acceptable bounds
     * @param fee The withdrawal fee to validate
     * @dev Reverts if the fee exceeds the maximum allowed fee
     */
    function _validateWithdrawalFee(Percentage fee) private pure {
        if (Percentage.unwrap(fee) > MAXIMUM_WITHDRAWAL_FEE) {
            revert WithdrawalFeeTooHigh();
        }
    }
}
