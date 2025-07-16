// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

/**
 * @title IInflightAssetTracking
 * @notice Generic interface for contracts that track inflight assets during bridging operations
 * @dev Implements method to track assets that are currently being bridged cross-chain
 */
interface IInflightAssetTracking is IERC165 {
    /**
     * @notice Updates the inflight assets amount when a bridge operation is executed
     * @param amount Amount of assets that are now in-flight
     * @dev Called by authorized bridge components when assets are transferred cross-chain
     */
    function updateInflightAssets(uint256 amount) external;

    /**
     * @notice Emitted when inflight assets amount is updated
     * @param amount The new amount of in-flight assets
     */
    event InflightAssetsUpdated(uint256 amount);
}
