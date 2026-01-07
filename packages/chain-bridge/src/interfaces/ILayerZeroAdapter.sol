// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title ILayerZeroAdapter
 * @notice Interface containing event definitions for LayerZeroAdapter
 * @dev Following the standardization pattern for consistent event definitions
 */
interface ILayerZeroAdapter {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Error thrown when the LayerZero endpoint is invalid
    error InvalidEndpoint();

    /// @notice Error thrown when the initial owner is invalid
    error InvalidOwner();

    /// @notice Error thrown when array lengths don't match
    error ArrayLengthMismatch();

    /// @notice Error thrown when an endpoint ID is invalid
    error InvalidEndpointId();

    /// @notice Error thrown when OApp address doesn't match expected OFT contract
    error UntrustedOApp(address received, address expected);

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when OFT contract is set for a token
    event OftSet(address indexed token, address indexed oft);

    /// @notice Emitted when read libraries are configured
    event ReadLibrariesConfigured(
        address indexed readLib1002,
        uint32 indexed readChannelId
    );

    /// @notice Emitted when read DVNs are configured
    event ReadDVNsConfigured(
        uint32 indexed readChannelId,
        address[] readDVNs,
        uint16 confirmations
    );

    /// @notice Emitted when a read channel is activated
    event ReadChannelActivated(uint32 indexed readChannelId);

    /// @notice Emitted when per-chain read support is updated
    event ChainReadSupportUpdated(uint16 indexed chainId, bool supported);
}
