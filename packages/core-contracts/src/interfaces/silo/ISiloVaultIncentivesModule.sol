// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title ISiloVaultIncentivesModule
/// @notice Interface for the Silo vault incentives module that tracks notification receivers
interface ISiloVaultIncentivesModule {
    /// @notice Returns the list of incentive claiming logic contracts that are notified on vault state changes
    /// @return The notification receiver addresses
    function getNotificationReceivers()
        external
        view
        returns (address[] memory);
}
