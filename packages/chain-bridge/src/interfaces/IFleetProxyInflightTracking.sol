// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

/**
 * @title IFleetProxyInflightTracking
 * @notice Interface for the FleetProxy contract which manages inflight withdrawal assets
 * @dev Implements method to track in-flight withdrawal assets during bridging operations
 */
interface IFleetProxyInflightTracking is IERC165 {
    /**
     * @notice Updates the inflight withdrawal assets amount when a bridge operation is executed
     * @param amount Amount of withdrawal assets that are now in-flight
     * @dev Called by authorized bridge components when withdrawal assets are transferred cross-chain
     */
    function updateInflightWithdrawals(uint256 amount) external;

    /**
     * @notice Returns the current amount of inflight withdrawal assets
     * @return Amount of withdrawal assets currently in-flight
     */
    function inflightWithdrawals() external view returns (uint256);

    /**
     * @notice Emitted when inflight withdrawal assets amount is updated
     * @param amount The new amount of in-flight withdrawal assets
     */
    event InflightWithdrawalsUpdated(uint256 amount);
}
