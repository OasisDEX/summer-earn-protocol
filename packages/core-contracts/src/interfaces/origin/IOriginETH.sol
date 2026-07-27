// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IOriginETH
/// @notice Minimal interface for the Origin rebasing ETH token (OETH)
interface IOriginETH {
    /// @notice Mints tokens to an account (vault only)
    /// @param to The recipient of the minted tokens
    /// @param amount The amount to mint
    function mint(address to, uint256 amount) external;
    /// @notice Returns the token balance of an account
    /// @param account The account to query
    /// @return The token balance
    function balanceOf(address account) external view returns (uint256);
    /// @notice Returns the address of the associated vault
    /// @return The vault address
    function vaultAddress() external view returns (address);
    /// @notice Transfers tokens to a recipient
    /// @param to The recipient
    /// @param amount The amount to transfer
    function transfer(address to, uint256 amount) external;
    /// @notice Opts the caller into rebasing (receiving yield via supply changes)
    function rebaseOptIn() external;
    /// @notice Returns the rebase state of an account
    /// @param account The account to query
    /// @return The rebase state code
    function rebaseState(address account) external view returns (uint8);
    /// @notice Changes the total supply to distribute rebasing yield (vault only)
    /// @param amount The new total supply
    function changeSupply(uint256 amount) external;
    /// @notice Returns the total token supply
    /// @return The total supply
    function totalSupply() external view returns (uint256);
}
