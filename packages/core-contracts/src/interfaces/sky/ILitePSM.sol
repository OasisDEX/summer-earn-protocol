// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title ILitePSM
/// @notice Minimal interface for the Sky/Maker LitePSM (Peg Stability Module)
interface ILitePSM {
    /// @notice Sells gem (collateral) tokens for the stablecoin
    /// @param usr The recipient of the stablecoin
    /// @param gemAmt The amount of gem tokens to sell
    /// @return The amount of stablecoin received
    function sellGem(address usr, uint256 gemAmt) external returns (uint256);
    /// @notice Buys gem (collateral) tokens with the stablecoin
    /// @param usr The recipient of the gem tokens
    /// @param gemAmt The amount of gem tokens to buy
    /// @return The amount of stablecoin paid
    function buyGem(address usr, uint256 gemAmt) external returns (uint256);
    /// @notice Returns the factor to convert gem amounts to 18 decimals
    /// @return The 18-decimal conversion factor
    function to18ConversionFactor() external view returns (uint256);
    /// @notice Returns the address of the gem (collateral) token
    /// @return The gem token address
    function gem() external view returns (address);
}
