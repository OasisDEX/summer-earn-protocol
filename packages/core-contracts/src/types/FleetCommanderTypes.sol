// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./Percentage.sol";

/**
 * @notice Configuration of an Ark added to the FleetCommander
 */
struct ArkConfiguration {
    address ark; // Ark address
    uint256 maxAllocation; // Max allocation as token balance
}

/**
 * @notice Configuration parameters for the FleetCommander contract
 */
struct FleetCommanderParams {
    address configurationManager;
    ArkConfiguration[] initialArks;
    uint256 initialFundsBufferBalance;
    uint256 initialRebalanceCooldown;
    address asset;
    string name;
    string symbol;
    Percentage initialMinimumPositionWithdrawal;
    Percentage initialMaximumBufferWithdrawal;
}

/**
 * @notice Data structure for the rebalance event
 * @param fromArk The address of the Ark from which assets are moved
 * @param toArk The address of the Ark to which assets are moved
 * @param amount The amount of assets being moved
 */
struct RebalanceData {
    address fromArk;
    address toArk;
    uint256 amount;
}
