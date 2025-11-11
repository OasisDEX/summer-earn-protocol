// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @notice Emitted when an account is not whitelisted.
 *
 * @param account The account that failed the whitelist check.
 */
error NotWhitelisted(address account);
