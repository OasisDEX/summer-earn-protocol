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
    event AssetSupported(
        uint16 chainId,
        address asset,
        address stargateContract
    );

    /// @notice Emitted when slippage tolerance is updated
    event SlippageToleranceUpdated(uint256 newSlippageBps);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when refunding excess native fee to `refundAddress` fails
    error RefundFailed(address recipient, uint256 amount);
}
