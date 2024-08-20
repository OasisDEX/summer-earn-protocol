// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "@summerfi/percentage-solidity/contracts/Percentage.sol";

/**
 * @notice Configuration parameters for the FleetCommander contract
 */
struct FleetCommanderParams {
    string name;
    string symbol;
    address[] initialArks;
    address configurationManager;
    address accessManager;
    address asset;
    address bufferArk;
    uint256 initialMinimumFundsBufferBalance;
    uint256 initialRebalanceCooldown;
    uint256 depositCap;
    Percentage initialTipRate;
    Percentage minimumRateDifference;
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
