// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @notice Emitted when an account is not whitelisted.
 *
 * @param context The context in which the whitelist check failed.
 * @param account The account that failed the whitelist check.
 */
error NotWhitelisted(address context, address account);
