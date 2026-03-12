// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IAssetsForwarderEvents
 * @notice Interface for the AssetsForwarder events
 */
interface IAssetsForwarderEvents {
    /**
     * @notice Emitted when assets are forwarded from the sender to a target address
     * @param sender The address that initiated the forward and provided the assets
     * @param target The address that received the assets
     * @param asset The address of the asset transferred
     * @param amount The amount of assets transferred
     */
    event AssetForwarded(
        address indexed sender,
        address indexed target,
        address indexed asset,
        uint256 amount
    );

    /**
     * @notice Emitted when existing assets in the contract are sent to a target address
     * @param target The address that received the assets
     * @param asset The address of the asset transferred
     * @param amount The amount of assets transferred
     */
    event AssetSent(
        address indexed target,
        address indexed asset,
        uint256 amount
    );

    /**
     * @notice Emitted when existing assets in the contract are swept to the keeper
     * @param keeper The address of the keeper that received the assets
     * @param asset The address of the asset transferred
     * @param amount The amount of assets transferred
     */
    event AssetSwept(
        address indexed keeper,
        address indexed asset,
        uint256 amount
    );
}
