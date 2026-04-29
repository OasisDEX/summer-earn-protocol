// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IWhitelist} from "../Whitelist/IWhitelist.sol";
import {IAssetsForwarderEvents} from "./IAssetsForwarderEvents.sol";
import {IAssetsForwarderErrors} from "./IAssetsForwarderErrors.sol";

/**
 * @title IAssetsForwarder
 * @notice Interface for the AssetsForwarder contract
 */
interface IAssetsForwarder is
    IWhitelist,
    IAssetsForwarderEvents,
    IAssetsForwarderErrors
{
    /**
     * @notice Pulls assets from the caller and sends them to the target address
     * @param targetAddress The address to receive the assets
     * @param asset The address of the asset to transfer
     * @param amount The amount of assets to transfer
     */
    function forwardAsset(
        address targetAddress,
        address asset,
        uint256 amount
    ) external;

    /**
     * @notice Sends existing assets in the contract to the target address
     * @param targetAddress The address to receive the assets
     * @param asset The address of the asset to transfer
     * @param amount The amount of assets to transfer
     */
    function sendAsset(
        address targetAddress,
        address asset,
        uint256 amount
    ) external;

    /**
     * @notice Sends existing assets in the contract to the caller (keeper)
     * @param asset The address of the asset to sweep
     * @param amount The amount of assets to sweep
     */
    function sweepAsset(address asset, uint256 amount) external;
}
