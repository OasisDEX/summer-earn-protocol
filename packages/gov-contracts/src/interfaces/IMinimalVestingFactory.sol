// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/// @dev this is a minimal vesting factory interface
interface IMinimalVestingFactory {
    /// @dev each user can have a single vesting wallet - the balance of the vesting wallet can only go down
    function vestingWallets(address _user) external view returns (address);
    /// @dev the owner of the vesting wallet
    function vestingWalletOwners(
        address _wallet
    ) external view returns (address);
}
