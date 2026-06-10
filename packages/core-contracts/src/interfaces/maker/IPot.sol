// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/// @title IPot
/// @notice Minimal interface for the MakerDAO Pot (DSR savings) contract
interface IPot {
    /// @notice Returns the Dai Savings Rate per second, as a ray (1e27)
    /// @return The DSR per-second rate
    function dsr() external view returns (uint256);
    /// @notice Returns the rate accumulator, as a ray (1e27)
    /// @return The current accumulated rate
    function chi() external view returns (uint256);
    /// @notice Returns the timestamp of the last drip (chi update)
    /// @return The last drip timestamp
    function rho() external view returns (uint256);
}
