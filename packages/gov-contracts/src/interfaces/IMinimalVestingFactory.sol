// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/// @title IMinimalVestingFactory
/// @notice Minimal vesting factory interface exposing the wallet/owner lookups used by the escrow
interface IMinimalVestingFactory {
    /// @notice Returns the vesting wallet deployed for a given user
    /// @dev each user can have a single vesting wallet - the balance of the vesting wallet can only go down
    /// @param _user The user whose vesting wallet address is queried
    /// @return The address of the user's vesting wallet (or the zero address if none)
    function vestingWallets(address _user) external view returns (address);
    /// @notice Returns the owner recorded for a given vesting wallet
    /// @dev the owner of the vesting wallet
    /// @param _wallet The vesting wallet address whose owner is queried
    /// @return The address recorded as the owner of the wallet
    function vestingWalletOwners(
        address _wallet
    ) external view returns (address);
}
