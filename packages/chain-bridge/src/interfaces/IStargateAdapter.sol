// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

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
    event SlippageToleranceUpdated(uint256 newSlippageBps);

    /// @notice Emitted when a native refund fails; operation continues
    event RefundFailed(address indexed to, uint256 amount);
}
