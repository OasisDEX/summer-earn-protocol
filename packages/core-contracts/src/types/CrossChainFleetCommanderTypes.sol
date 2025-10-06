// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title AsyncOperation
 * @notice Represents a queued async operation (deposit or withdrawal)
 */
struct AsyncOperation {
    /// @notice The user who initiated the operation
    address user;
    /// @notice The receiver of the operation (for deposits/withdrawals)
    address receiver;
    /// @notice The amount of assets involved
    uint256 amount;
    /// @notice The number of shares involved (for withdrawals)
    uint256 shares;
    /// @notice The timestamp when the operation was queued
    uint256 timestamp;
    /// @notice The type of operation (0 = deposit, 1 = withdrawal)
    uint8 operationType;
    /// @notice Whether the operation has been processed
    bool processed;
}

/**
 * @title CrossChainFleetCommanderParams
 * @notice Parameters for initializing a CrossChainFleetCommander
 */
struct CrossChainFleetCommanderParams {
    /// @notice The name of the FleetCommander
    string name;
    /// @notice The symbol of the FleetCommander
    string symbol;
    /// @notice The underlying asset token
    address asset;
    /// @notice The initial tip rate
    uint256 initialTipRate;
    /// @notice The initial rebalance cooldown
    uint256 initialRebalanceCooldown;
    /// @notice The minimum amount for queue operations (in asset units)
    uint256 minQueueAmount;
}
