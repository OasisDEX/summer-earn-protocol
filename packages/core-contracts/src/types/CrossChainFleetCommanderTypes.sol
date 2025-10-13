// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {FleetCommanderParams} from "./FleetCommanderTypes.sol";

/**
 * @title CrossChainFleetCommanderParams
 * @notice Parameters for initializing a CrossChainFleetCommander
 * @dev Extends FleetCommanderParams with additional cross-chain specific parameters
 */
struct CrossChainFleetCommanderParams {
    /// @notice The base FleetCommander parameters
    FleetCommanderParams fleetCommanderParams;
    /// @notice The initial cooldown period between deposit and withdraw/redeem (in seconds)
    /// @dev This will be set in FleetConfig and can be updated via governance
    uint256 cooldownPeriod;
}
