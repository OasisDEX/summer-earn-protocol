// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title IArkEvents
/// @notice Interface for events emitted by Ark contracts
interface IArkEvents {
    /// @notice Emitted when a harvest operation is completed
    /// @param amount The amount of tokens harvested
    event Harvested(uint256 amount);

    /// @notice Emitted when tokens are boarded (deposited) into the Ark
    /// @param commander The address of the FleetCommander initiating the boarding
    /// @param token The address of the token being boarded
    /// @param amount The amount of tokens boarded
    event Boarded(address indexed commander, address token, uint256 amount);

    /// @notice Emitted when tokens are disembarked (withdrawn) from the Ark
    /// @param commander The address of the FleetCommander initiating the disembarking
    /// @param token The address of the token being disembarked
    /// @param amount The amount of tokens disembarked
    event Disembarked(address indexed commander, address token, uint256 amount);

    /// @notice Emitted when the deposit cap of the Ark is updated
    /// @param newCap The new deposit cap value
    event DepositCapUpdated(uint256 newCap);

    /// @notice Emitted when the maximum allocation of the Ark is updated
    /// @param newMaxAllocation The new maximum allocation value
    event MaxAllocationUpdated(uint256 newMaxAllocation);

    /// @notice Emitted when the Raft address associated with the Ark is updated
    /// @param newRaft The address of the new Raft
    event RaftUpdated(address newRaft);

    /// @notice Emitted when the Ark is poked twice in the same block
    event ArkPokedTooSoon();

    /// @notice Emitted when the Ark is poked and the total assets did not change
    event ArkPokedNoChange();

    /// @notice Emitted when the Ark is poked and the total assets did change
    /// @param totalAssets The total assets of the Ark
    /// @param timestamp The timestamp of the poke
    event ArkPoked(uint256 totalAssets, uint256 timestamp);
}
