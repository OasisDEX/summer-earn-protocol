// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/**
 * @title IArkErrors
 * @dev This file contains custom error definitions for the Ark contract.
 * @notice These custom errors provide more gas-efficient and informative error handling
 * compared to traditional require statements with string messages.
 */
interface IArkErrors {
    /**
     * @notice Thrown when attempting to remove a commander from an Ark that still has assets.
     */
    error CannotRemoveCommanderFromArkWithAssets();

    /**
     * @notice Thrown when trying to add a commander to an Ark that already has one.
     */
    error CannotAddCommanderToArkWithCommander();

    /**
     * @notice Thrown when attempting to deploy an Ark without specifying a configuration manager.
     */
    error CannotDeployArkWithoutConfigurationManager();

    /**
     * @notice Thrown when attempting to deploy an Ark without specifying a Raft address.
     */
    error CannotDeployArkWithoutRaft();

    /**
     * @notice Thrown when attempting to deploy an Ark without specifying a token address.
     */
    error CannotDeployArkWithoutToken();

    /**
     * @notice Thrown when attempting to deploy an Ark with an empty name.
     */
    error CannotDeployArkWithEmptyName();

    /**
     * @notice Thrown when an invalid vault address is provided.
     */
    error InvalidVaultAddress();

    /**
     * @notice Thrown when there's a mismatch between expected and actual assets in an ERC4626 operation.
     */
    error ERC4626AssetMismatch();

    /**
     * @notice Thrown when attempting to use keeper data when it's not required.
     */
    error CannotUseKeeperDataWhenNotRequired();

    /**
     * @notice Thrown when keeper data is required but not provided.
     */
    error KeeperDataRequired();

    /**
     * @notice Thrown when invalid board data is provided.
     */
    error InvalidBoardData();

    /**
     * @notice Thrown when invalid disembark data is provided.
     */
    error InvalidDisembarkData();
}
