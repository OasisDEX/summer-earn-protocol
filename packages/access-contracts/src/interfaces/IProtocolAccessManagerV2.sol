// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IProtocolAccessManager} from "./IProtocolAccessManager.sol";

/**
 * @title IProtocolAccessManagerV2
 *
 * @notice Public surface of `ProtocolAccessManagerV2`. Extends the V1 manager with a per-context
 *         whitelist and a contract-specific Operator role used by institutional Fleet variants.
 */
interface IProtocolAccessManagerV2 {
    /// @notice Emitted when an account's explicit whitelist record for `context` changes.
    /// @param context The context (e.g. a Fleet address) the status is scoped to
    /// @param account The account whose status changed
    /// @param isWhitelisted The new status (`true` for whitelisted, `false` for removed)
    event WhitelistStatusUpdated(
        address indexed context,
        address indexed account,
        bool isWhitelisted
    );

    /// @notice Emitted when the global-open flag for `context` changes.
    /// @param context The context the flag is scoped to
    /// @param isOpen `true` if every account now reads as whitelisted for `context`
    event WhitelistOpenUpdated(address indexed context, bool isOpen);

    /// @notice Reverts when `setWhitelistedBatch` is called with mismatched `accounts` and
    ///         `allowed` array lengths.
    error Whitelist_LengthMismatch();

    /// @notice Reverts when `setWhitelistedBatch` is called with more accounts than
    ///         `MAX_WHITELIST_BATCH_SIZE` (currently 200).
    error Whitelist_BatchTooLarge();

    /**
     * @notice Grants the contract-specific Operator role for `fleetCommanderAddress` to `account`.
     * @dev Despite the parameter name, the Operator role is scoped to any contract that exposes
     *      `hasOperatorRole(account)` against itself — typically a Fleet, but also AdmiralsQuarters
     *      and the rounds vaults. Inheriting contracts (via `ProtocolAccessManagedV2`) use the role
     *      to let trusted bundler/proxy contracts bypass user-side gateways. Restricted to the
     *      Governor role.
     * @param fleetCommanderAddress The contract the Operator role is scoped to (typically a Fleet)
     * @param account The account to grant the role to
     */
    function grantOperatorRole(
        address fleetCommanderAddress,
        address account
    ) external;

    /**
     * @notice Revokes the contract-specific Operator role for `fleetCommanderAddress` from `account`.
     * @dev Despite the parameter name, the Operator role is contract-scoped — it applies to any
     *      contract that exposes `hasOperatorRole(account)` against itself (see
     *      `ProtocolAccessManagedV2`), not just Fleets. Restricted to the Governor role.
     * @param fleetCommanderAddress The contract the Operator role is scoped to (typically a Fleet)
     * @param account The account to revoke the role from
     */
    function revokeOperatorRole(
        address fleetCommanderAddress,
        address account
    ) external;

    /**
     * @notice Grants `WHITELIST_MANAGER_ROLE` to `account`.
     * @dev Whitelist managers may call `setWhitelisted`, `setWhitelistedBatch`, and
     *      `setWhitelistOpen`. Restricted to the Governor role.
     * @param account The account to grant the role to.
     */
    function grantWhitelistManagerRole(address account) external;

    /**
     * @notice Revokes `WHITELIST_MANAGER_ROLE` from `account`.
     * @dev Restricted to the Governor role.
     * @param account The account to revoke the role from.
     */
    function revokeWhitelistManagerRole(address account) external;

    /**
     * @notice Returns whether `account` is allowed to interact with `context`.
     * @param context The context (typically a Fleet address) the check is scoped to
     * @param account The account to check
     * @return `true` when either `context`'s whitelist is globally open or `account` has an
     *         explicit whitelist record for `context`.
     */
    function isWhitelisted(
        address context,
        address account
    ) external view returns (bool);

    /**
     * @notice Batch variant of `isWhitelisted`: returns the per-account status array under a single
     *         load of the `_isWhitelistOpen[context]` flag.
     * @param context The context the check is scoped to
     * @param accounts Accounts to check
     * @return statuses Array of statuses aligned with `accounts`.
     */
    function areWhitelisted(
        address context,
        address[] calldata accounts
    ) external view returns (bool[] memory);

    /**
     * @notice Returns whether `context`'s whitelist has been globally opened.
     * @param context The context to check
     * @return True if `context`'s whitelist is globally open.
     */
    function isWhitelistOpen(address context) external view returns (bool);

    /**
     * @notice Sets `account`'s explicit whitelist record for `context`.
     * @dev Idempotent — no event is emitted when the status is unchanged. Restricted to
     *      `WHITELIST_MANAGER_ROLE`.
     * @param context The context the record is scoped to
     * @param account The account to update
     * @param allowed The new status (`true` for whitelisted, `false` to remove the record).
     */
    function setWhitelisted(
        address context,
        address account,
        bool allowed
    ) external;

    /**
     * @notice Batch variant of `setWhitelisted`. Reverts on length mismatch or when the batch
     *         exceeds `MAX_WHITELIST_BATCH_SIZE`. Restricted to `WHITELIST_MANAGER_ROLE`.
     * @param context The context the records are scoped to
     * @param accounts Accounts to update
     * @param allowed Per-account statuses, aligned with `accounts`
     */
    function setWhitelistedBatch(
        address context,
        address[] calldata accounts,
        bool[] calldata allowed
    ) external;

    /**
     * @notice Sets the global-open flag for `context`. When `true`, every account reads as
     *         whitelisted for `context`. Restricted to `WHITELIST_MANAGER_ROLE`.
     * @param context The context to update
     * @param isOpen The new open status
     */
    function setWhitelistOpen(address context, bool isOpen) external;
}
