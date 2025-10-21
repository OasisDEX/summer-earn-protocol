// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Bps} from "../helpers/Bps.sol";

/**
 * @title IStargateAdapter
 * @notice Interface containing error and event definitions for StargateAdapter
 * @dev Following the standardization pattern for consistent error/event definitions
 */
interface IStargateAdapter {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when an asset support is added
    event AssetSupported(address asset, address stargateContract);

    /// @notice Emitted when slippage tolerance is updated
    event SlippageToleranceUpdated(Bps newSlippageBps);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when LayerZero endpoint address is invalid
    error InvalidLzEndpoint();

    /// @notice Thrown when slippage tolerance is outside valid range
    error InvalidSlippageTolerance(uint256 provided);

    /// @notice Thrown when asset address is invalid
    error InvalidAssetAddress();

    /// @notice Thrown when Stargate contract address is invalid
    error InvalidStargateContract();

    /// @notice Thrown when Stargate contract type is invalid
    error InvalidStargateType();

    /// @notice Thrown when Stargate pool token doesn't match expected asset
    error InvalidStargatePoolToken(address expected, address actual);
}
