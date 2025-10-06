// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

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
 * @dev Extends FleetCommanderParams with additional cross-chain specific parameters
 */
struct CrossChainFleetCommanderParams {
    /// @notice The name of the FleetCommander
    string name;
    /// @notice The details of the FleetCommander
    string details;
    /// @notice The symbol of the FleetCommander
    string symbol;
    /// @notice The configuration manager address
    address configurationManager;
    /// @notice The access manager address
    address accessManager;
    /// @notice The underlying asset token
    address asset;
    /// @notice The initial minimum buffer balance
    uint256 initialMinimumBufferBalance;
    /// @notice The initial rebalance cooldown
    uint256 initialRebalanceCooldown;
    /// @notice The deposit cap
    uint256 depositCap;
    /// @notice The initial tip rate (as a percentage, e.g., 5 for 5%)
    Percentage initialTipRate;
    /// @notice The minimum amount for queue operations (in asset units)
    uint256 minQueueAmount;
}
