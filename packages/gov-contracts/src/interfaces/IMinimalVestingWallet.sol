// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/// @title IMinimalVestingWallet
/// @notice Minimal vesting wallet interface exposing the subset of the vesting wallet used by the escrow
interface IMinimalVestingWallet {
    /// @notice Returns the vesting wallet's balance of staked tokens for an account
    /// @dev the balance of the vesting wallet can only go down - if it goes up - tokens were sent to the wallet (unintended bhavior)
    /// @param _user The address to query the balance for
    /// @return The staked balance held by the wallet for the account
    function balanceOf(address _user) external view returns (uint256);
    /// @notice Returns the current owner of the vesting wallet
    /// @dev the current owner of the vesting wallet ( might be different that owner in the factory contract)
    /// @return The address of the current wallet owner
    function owner() external view returns (address);
    /// @notice Transfers ownership of the vesting wallet to a new owner
    /// @dev the ownership of the vesting wallet can be trnsfered - this is used to transfer the ownership of the vesting wallet to the user
    /// @param newOwner The address of the new owner
    function transferOwnership(address newOwner) external;
    /// @notice Returns the amount of a given token already released from the vesting wallet
    /// @dev the amount of tokens released from the vesting wallet
    /// @param _token The token whose released amount is queried
    /// @return The amount of the token already released
    function released(address _token) external view returns (uint256);
}
