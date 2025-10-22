// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IWhitelistEvents} from "./IWhitelistEvents.sol";

/**
 * @title IWhitelist
 * @notice Interface for the Whitelist contract
 * @dev This contract provides a whitelist utility with events and an optional "open" mode.
 *      Use `onlyWhitelisted(account)` to gate functions. Manage status via
 *      `setWhitelisted` or `setWhitelistedBatch`. If `address(0)` is set to
 *      allowed, the whitelist becomes open and all accounts are considered allowed.
 */
interface IWhitelist is IWhitelistEvents {
    /**
     * @notice Returns true if `account` is whitelisted.
     * @dev Returns true for any account when the whitelist is open.
     */
    function isWhitelisted(address account) external view returns (bool);
    /**
     * @notice Sets the whitelist status for an account
     * @dev Inheriting contracts must implement access control
     * @param account The account to set the whitelist status for
     * @param allowed The whitelist status to set
     */
    function setWhitelisted(address account, bool allowed) external;

    /**
     * @notice Sets the whitelist status for a batch of accounts
     * @dev Inheriting contracts must implement access control
     * @param accounts The accounts to set the whitelist status for
     * @param allowed The whitelist status to set
     */
    function setWhitelistedBatch(
        address[] memory accounts,
        bool[] memory allowed
    ) external;
}
