// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

/**
 * @title ICrossChainArk
 * @notice Interface for the CrossChainArk contract which manages cross-chain assets
 * @dev Implements method to track in-flight assets during bridging operations
 */
interface ICrossChainArk is IERC165 {
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
