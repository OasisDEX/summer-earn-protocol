// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title ITipAccruer Interface
/// @notice Interface for the tip accrual functionality in the FleetCommander contract
/// @dev This interface defines the events and functions related to tip accrual and management
interface ITipAccruer {
    /// @notice Emitted when the tip rate is updated
    /// @param newTipRate The new tip rate value (in basis points)
    event TipRateUpdated(uint256 newTipRate);

    /// @notice Emitted when tips are accrued
    /// @param tipAmount The amount of tips accrued in the underlying asset's smallest unit
    event TipAccrued(uint256 tipAmount);

    /// @notice Emitted when the tip jar address is updated
    /// @param newTipJar The new address of the tip jar
    event TipJarUpdated(address newTipJar);

    /// @notice Get the current tip rate
    /// @return The current tip rate in basis points (1/10000)
    /// @dev A tip rate of 100 represents 1%, 10000 represents 100%
    function tipRate() external view returns (uint256);

    /// @notice Get the timestamp of the last tip accrual
    /// @return The Unix timestamp of when tips were last accrued
    function lastTipTimestamp() external view returns (uint256);

    /// @notice Get the current tip jar address
    /// @return The address where accrued tips are sent
    function tipJar() external view returns (address);

    /// @notice Estimate the amount of tips accrued since the last tip accrual
    /// @return The estimated amount of accrued tips in the underlying asset's smallest unit
    /// @dev This function performs a calculation without changing the contract's state
    function estimateAccruedTip() external view returns (uint256);

    /// @notice Set a new tip rate
    /// @param _newTipRate The new tip rate to set (in basis points)
    /// @dev Only callable by authorized roles (e.g., governor)
    /// @dev This function should accrue any pending tips before changing the rate
    function setTipRate(uint256 _newTipRate) external;

    /// @notice Set a new tip jar address
    /// @param _newTipJar The new address to set as the tip jar
    /// @dev Only callable by authorized roles (e.g., governor)
    /// @dev The new address should not be the zero address
    function setTipJar(address _newTipJar) external;

    /// @notice Accrue tips based on the current tip rate and time elapsed
    /// @dev This function calculates the accrued tips, mints new shares, and sends them to the tip jar
    /// @dev It should be called before any significant state changes in the main contract
    /// @dev If no time has elapsed since the last tip accrual, this function should not make any changes
    function tip() external;
}
