// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IWhitelistEvents
 *
 * @notice Legacy event surface inherited by `IWhitelist`. Maintained for ABI compatibility; the
 *         authoritative whitelist mutation event is emitted by the central access manager
 *         (`IProtocolAccessManagerV2.WhitelistStatusUpdated(context, account, allowed)`) since the
 *         inheriting `Whitelist` helper delegates all state to that contract.
 */
interface IWhitelistEvents {
    /// @notice Account-scoped whitelist status change. Retained for ABI compatibility; not emitted
    ///         by the `Whitelist` helper. Listen for the access-manager event for live updates.
    /// @param account The account whose whitelist status changed
    /// @param allowed The new whitelist status for the account
    event WhitelistStatusUpdated(address indexed account, bool allowed);
}
