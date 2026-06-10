// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/// @title IWETH
/// @notice Minimal interface for Wrapped Ether (WETH)
interface IWETH {
    /// @notice Wraps the sent ETH into WETH, crediting the caller
    function deposit() external payable;
    /// @notice Transfers WETH to a recipient
    /// @param to The recipient
    /// @param value The amount to transfer
    /// @return True if the transfer succeeded
    function transfer(address to, uint256 value) external returns (bool);
    /// @notice Unwraps WETH back into ETH, sending it to the caller
    function withdraw(uint256) external;
    /// @notice Returns the WETH balance of an account
    /// @return The WETH balance
    function balanceOf(address) external view returns (uint256);
}
