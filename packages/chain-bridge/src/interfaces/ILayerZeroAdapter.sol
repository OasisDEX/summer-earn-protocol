// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title ILayerZeroAdapter
 * @notice Interface containing event definitions for LayerZeroAdapter
 * @dev Following the standardization pattern for consistent event definitions
 */
interface ILayerZeroAdapter {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

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
