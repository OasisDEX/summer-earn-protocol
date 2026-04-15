// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { IProtocolAccessManager } from "./IProtocolAccessManager.sol";

/**
 * @title IProtocolAccessManagerV2
 * @notice Defines system roles and provides role based remote-access control for
 *         contracts that inherit from ProtocolAccessManaged contract, including V2 features like Whitelisting.
 */
interface IProtocolAccessManagerV2 {

    /// @notice Emitted when the whitelist status of an account is updated in a context
    event WhitelistStatusUpdated(address indexed context, address indexed account, bool isWhitelisted);

    /// @notice Emitted when the whitelist open status of a context is updated
    event WhitelistOpenUpdated(address indexed context, bool isOpen);

    /**
     * @notice Thrown when the length of the accounts array and the allowed array do not match.
     */
    error Whitelist_LengthMismatch();

    /**
     * @notice Thrown when the batch size exceeds the maximum allowed (200).
     */
    error Whitelist_BatchTooLarge();

    /**
     * @notice Grants the Operator role to a given account
     * @param fleetCommanderAddress The address of the fleet commander to grant the role for
     * @param account The account to which the Operator role will be granted
     *
     * @dev The operator role is used to restrict usage of a particular contract to a particular
     *      address. In the context of the fleet commander, only the Operator could deposit and
     *      withdraw for example
     */
    function grantOperatorRole(address fleetCommanderAddress, address account) external;

    /**
     * @notice Revokes the Operator role from a given account
     * @param fleetCommanderAddress The address of the fleet commander to revoke the role for
     * @param account The account from which the Operator role will be revoked
     */
    function revokeOperatorRole(address fleetCommanderAddress, address account) external;

    /**
     * @notice Grants the WHITELIST_MANAGER_ROLE to an account
     * @param account The address of the account to grant the role to
     */
    function grantWhitelistManagerRole(address account) external;

    /**
     * @notice Revokes the WHITELIST_MANAGER_ROLE from an account
     * @param account The address of the account to revoke the role from
     */
    function revokeWhitelistManagerRole(address account) external;

    /**
     * @notice Returns whether an account is whitelisted in a given context
     * @param context The context (e.g. fleet address) to check against
     * @param account The account to check
     * @return bool True if whitelisted (or if context is globally open)
     */
    function isWhitelisted(address context, address account) external view returns (bool);

    /**
     * @notice Returns whether multiple accounts are whitelisted in a given context
     * @param context The context (e.g. fleet address) to check against
     * @param accounts Array of accounts to check
     * @return bool[] Array of whitelist statuses
     */
    function areWhitelisted(address context, address[] calldata accounts) external view returns (bool[] memory);

    /**
     * @notice Returns whether the whitelist for a given context is globally open
     * @param context The context to check
     * @return bool True if open
     */
    function isWhitelistOpen(address context) external view returns (bool);

    /**
     * @notice Sets the whitelist status of an account in a given context
     * @param context The context to update
     * @param account The account to update
     * @param allowed The new status
     */
    function setWhitelisted(address context, address account, bool allowed) external;

    /**
     * @notice Sets the whitelist status of multiple accounts in a batch within a context
     * @param context The context to update
     * @param accounts Array of accounts to update
     * @param allowed Array of statuses corresponding to the accounts
     */
    function setWhitelistedBatch(address context, address[] calldata accounts, bool[] calldata allowed) external;

    /**
     * @notice Sets the whitelist open status for a given context
     * @param context The context to update
     * @param isOpen The new open status
     */
    function setWhitelistOpen(address context, bool isOpen) external;

}
