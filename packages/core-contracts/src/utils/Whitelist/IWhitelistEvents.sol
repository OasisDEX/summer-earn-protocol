// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * EVENTS
 */
interface IWhitelistEvents {
    /**
     * @param account The account whose whitelist status changed.
     * @param allowed The new whitelist status for the account.
     */
    event WhitelistStatusUpdated(address indexed account, bool allowed);
}
