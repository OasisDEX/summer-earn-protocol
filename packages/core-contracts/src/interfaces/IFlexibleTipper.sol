// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ITipper} from "./ITipper.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

/**
 * @title IFlexibleTipper
 * @notice Interface for the FlexibleTipper contract that extends the base Tipper
 *         with an optional High-Water Mark (HWM) performance fee.
 * @dev Supports three fee modes:
 *      - AUM: Time-based assets-under-management fee (original Tipper behavior)
 *      - PERFORMANCE: HWM-based fee charged only on new profit
 *      - BOTH: AUM + PERFORMANCE fees applied together
 */
interface IFlexibleTipper is ITipper {
    /**
     * @notice Enum representing the available fee types
     * @param AUM Assets Under Management fee (time-based, annualized)
     * @param PERFORMANCE High-Water Mark performance fee (profit-based)
     * @param BOTH Both AUM and Performance fees applied together
     */
    enum FeeType {
        AUM,
        PERFORMANCE,
        BOTH
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when the fee type changes, with HWM reset details for auditability
     * @param oldFeeType The previous fee type
     * @param newFeeType The new fee type
     * @param oldHWM The HWM value before the reset
     * @param newHWM The HWM value after the reset (current assetsPerShare)
     */
    event FeeTypeChanged(
        FeeType oldFeeType,
        FeeType newFeeType,
        uint256 oldHWM,
        uint256 newHWM
    );

    /**
     * @notice Emitted when the performance fee rate is updated
     * @param newRate The new performance fee rate
     */
    event PerformanceFeeRateUpdated(Percentage newRate);

    /**
     * @notice Emitted when the high-water mark is updated
     * @param newHighWaterMark The new high-water mark value (assetsPerShare * 1e18)
     */
    event HighWaterMarkUpdated(uint256 newHighWaterMark);

    /**
     * @notice Emitted when performance fee shares are accrued
     * @param feeShares The number of shares minted as performance fee
     */
    event PerformanceFeeAccrued(uint256 feeShares);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Thrown when the performance fee rate exceeds the maximum allowed (50%)
     */
    error PerformanceFeeRateTooHigh();

    /**
     * @notice Thrown when attempting to set the performance fee rate to zero
     */
    error PerformanceFeeRateCannotBeZero();

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the current fee type
     * @return The current FeeType enum value
     */
    function feeType() external view returns (FeeType);

    /**
     * @notice Returns the current performance fee rate
     * @return The performance fee rate as a Percentage
     */
    function performanceFeeRate() external view returns (Percentage);

    /**
     * @notice Returns the current high-water mark
     * @dev The HWM is the highest-ever assetsPerShare ratio, scaled by 1e18
     * @return The high-water mark value
     */
    function highWaterMark() external view returns (uint256);
}
