// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IAssetsForwarderErrors
 * @notice Interface for the AssetsForwarder errors
 */
interface IAssetsForwarderErrors {
    /**
     * @notice Thrown when the specified target address is the zero address
     */
    error InvalidTargetAddress();

    /**
     * @notice Thrown when the specified asset is the zero address
     */
    error InvalidAssetAddress();

    /**
     * @notice Thrown when the specified amount is zero
     */
    error ZeroAmount();
}
