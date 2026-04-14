// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IWhitelistEvents} from "./IWhitelistEvents.sol";

/**
 * @title IWhitelist
 * @notice Interface for the Whitelist contract
 * @dev This contract provides a whitelist utility that delegates to a per-context central logic.
 *      Use `onlyWhitelisted(context, account)` to gate functions.
 */
interface IWhitelist is IWhitelistEvents {
    /**
     * @notice Checks if an account is whitelisted for a specific context
     * @param context The context for which the account status is checked
     * @param account The account to check
     * @return True if the account is whitelisted or if the whitelist for the context is set to open mode
     */
    function isWhitelisted(
        address context,
        address account
    ) external view returns (bool);

    /**
     * @notice Returns true if the whitelist for a specific context is globally open
     * @param context The context to check
     */
    function isWhitelistOpen(address context) external view returns (bool);
}
