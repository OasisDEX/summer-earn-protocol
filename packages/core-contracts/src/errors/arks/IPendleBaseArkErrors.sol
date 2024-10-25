// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Percentage} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

/// @title IPendleBaseArkErrors
/// @notice Interface defining custom errors for the Pendle Base Ark contract
interface IPendleBaseArkErrors {
    /// @notice Thrown when the oracle is not ready to provide a price
    error OracleNotReady();

    /// @notice Thrown when an invalid asset is provided for the SY (Standardized Yield)
    error InvalidAssetForSY();

    /// @notice Thrown when an invalid next market is provided
    error InvalidNextMarket();

    /// @notice Thrown when the provided oracle duration is too low
    /// @param providedDuration The duration provided
    /// @param minimumDuration The minimum required duration
    error OracleDurationTooLow(
        uint32 providedDuration,
        uint256 minimumDuration
    );

    /// @notice Thrown when the provided slippage percentage is too high
    /// @param providedSlippage The slippage percentage provided
    /// @param maxSlippage The maximum allowed slippage percentage
    error SlippagePercentageTooHigh(
        Percentage providedSlippage,
        Percentage maxSlippage
    );

    /// @notice Thrown when attempting to interact with an expired market
    error MarketExpired();
}
