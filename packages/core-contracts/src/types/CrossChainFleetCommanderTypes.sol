// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

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
    /// @notice The initial cooldown period between deposit and withdraw/redeem (in seconds)
    /// @dev This will be set in FleetConfig and can be updated via governance
    uint256 initialCooldownPeriod;
}
