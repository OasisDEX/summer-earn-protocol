// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IWhitelistEvents} from "./IWhitelistEvents.sol";

/**
 * @title IWhitelist
 *
 * @notice Public surface of the `Whitelist` helper. Inheriting contracts gate user-facing functions
 *         with `onlyWhitelisted(context, account)`; state lives in the central
 *         `ProtocolAccessManagerV2` and is keyed by a `context` address (typically the vault
 *         performing the check, e.g. the Fleet).
 */
interface IWhitelist is IWhitelistEvents {
    /**
     * @notice Returns whether `account` may interact with `context`.
     * @param context The context the check is scoped to (usually a vault address)
     * @param account The account to check
     * @return `true` if `account` is explicitly whitelisted for `context`, or if `context`'s
     *         whitelist is globally open (`isWhitelistOpen(context) == true`).
     */
    function isWhitelisted(
        address context,
        address account
    ) external view returns (bool);

    /**
     * @notice Returns whether the whitelist for `context` is globally open (every account passes).
     * @param context The context to check
     */
    function isWhitelistOpen(address context) external view returns (bool);
}
