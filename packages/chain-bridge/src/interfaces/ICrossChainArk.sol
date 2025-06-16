// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

import {IInflightAssetTracking} from "./IInflightAssetTracking.sol";

/**
 * @title ICrossChainArk
 * @notice Interface for the CrossChainArk contract which manages cross-chain assets
 * @dev Extends IInflightAssetTracking for consistent inflight asset management
 */
interface ICrossChainArk is IInflightAssetTracking {
    // ICrossChainArk-specific functions can be added here if needed
    // The updateInflightAssets function and InflightAssetsUpdated event
    // are inherited from IInflightAssetTracking
}
