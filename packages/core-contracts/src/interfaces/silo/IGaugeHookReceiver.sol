// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IGaugeHookReceiver
/// @notice Interface for the Silo hook receiver that maps share tokens to their reward gauges
interface IGaugeHookReceiver {
    /// @notice Get the gauge for the share token
    /// @param _shareToken The share token to query
    /// @return The configured gauge address for the share token
    function configuredGauges(
        address _shareToken
    ) external view returns (address);
}
