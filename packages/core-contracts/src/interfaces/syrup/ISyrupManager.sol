// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title ISyrupManager
/// @notice Interface for the Maple Syrup pool manager
interface ISyrupManager {
    /// @notice Returns the address of the pool's withdrawal manager
    /// @return The withdrawal manager address
    function withdrawalManager() external view returns (address);
}
