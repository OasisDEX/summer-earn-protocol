// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./Percentage.sol";

/**
 * @notice Configuration parameters for the FleetCommander contract
 */
struct FleetCommanderParams {
    address configurationManager;
    address accessManager;
    address[] initialArks;
    uint256 initialMinimumFundsBufferBalance;
    uint256 initialRebalanceCooldown;
    address asset;
    string name;
    string symbol;
    Percentage initialMinimumPositionWithdrawal;
    Percentage initialMaximumBufferWithdrawal;
    uint256 depositCap;
    address bufferArk;
    Percentage initialTipRate;
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
