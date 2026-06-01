// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @notice Reverts when `account` is not whitelisted for `context`.
 *
 * @param context The context for which the whitelist check was performed (usually a vault address).
 * @param account The account that failed the whitelist check.
 */
error NotWhitelisted(address context, address account);
