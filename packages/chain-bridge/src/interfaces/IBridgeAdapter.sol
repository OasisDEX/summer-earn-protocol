// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {Bps} from "../helpers/Bps.sol";

/**
 * @title IBridgeAdapter
 * @notice Core interface for bridge adapters with shared functionality
 * @dev Provides unified methods for bridge adapters. Adapters should also inherit from
 * @dev IAssetAdapter and/or IMessageAdapter based on their capabilities
 */
interface IBridgeAdapter {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a relay or messaging operation fails
    event RelayFailed(bytes32 indexed transferId, bytes reason);

    /// @notice Emitted when bridge router is updated
    event BridgeRouterUpdated(address oldRouter, address newRouter);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when insufficient msg.value is provided for the specified msgValue
    error InsufficientMsgValue(uint128 required, uint256 provided);

    /// @notice Thrown when a chain is not supported
    error UnsupportedChain();

    /// @notice Thrown when the operation is not supported by the adapter
    error OperationNotSupported();

    /// @notice Thrown when insufficient fee is provided for an operation
    error InsufficientFee(uint256 required, uint256 provided);

    /// @notice Thrown when an unsupported message type is received
    error UnsupportedMessageType();

    /// @notice Error for slippage exceeding tolerance
    error SlippageExceedsTolerance(
        uint256 expectedAmount,
        uint256 receivedAmount,
        Bps toleranceBps
    );

    /// @notice Error for untrusted Stargate pool contract
    error Untrusted(string what, address from, address additionalInfo);

    /**
     * @notice Check if an adapter supports a specific operation type
     * @param operationType Type of operation to check support for
     * @return Whether the adapter supports the operation type
     * @dev This method should check both asset and message capabilities based on operationType
     */
    function supportsOperation(
        BridgeTypes.OperationType operationType
    ) external view returns (bool);
}
