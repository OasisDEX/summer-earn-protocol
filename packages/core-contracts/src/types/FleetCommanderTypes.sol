// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./Percentage.sol";

/**
 * @notice Configuration of an Ark added to the FleetCommander
 */
struct ArkConfiguration {
    Percentage maxAllocation; // Max allocation as a percentage (see Percentage.sol for more details)
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
