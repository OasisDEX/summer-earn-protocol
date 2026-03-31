// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IProtocolAccessManager} from "./IProtocolAccessManager.sol";

/**
 * @title IProtocolAccessManagerV2
 * @notice Defines system roles and provides role based remote-access control for
 *         contracts that inherit from ProtocolAccessManaged contract, including V2 features like Whitelisting.
 */
interface IProtocolAccessManagerV2 {
    /// @notice Emitted when the whitelist status of an account is updated
    event WhitelistStatusUpdated(address indexed account, bool isWhitelisted);

    /**
     * @notice Grants the Operator role to a given account
     * @param fleetCommanderAddress The address of the fleet commander to grant the role for
     * @param account The account to which the Operator role will be granted
     *
     * @dev The operator role is used to restrict usage of a particular contract to a particular
     *      address. In the context of the fleet commander, only the Operator could deposit and
     *      withdraw for example
     */
    function grantOperatorRole(
        address fleetCommanderAddress,
        address account
    ) external;

    /**
     * @notice Revokes the Operator role from a given account
     * @param fleetCommanderAddress The address of the fleet commander to revoke the role for
     * @param account The account from which the Operator role will be revoked
     */
    function revokeOperatorRole(
        address fleetCommanderAddress,
        address account
    ) external;

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
     * @notice Returns whether an account is whitelisted
     * @param account The account to check
     * @return bool True if whitelisted (or if address(0) is whitelisted for open access)
     */
    function isWhitelisted(address account) external view returns (bool);

    /**
     * @notice Sets the whitelist status of an account
     * @param account The account to update
     * @param allowed The new status
     */
    function setWhitelisted(address account, bool allowed) external;

    /**
     * @notice Sets the whitelist status of multiple accounts in a batch
     * @param accounts Array of accounts to update
     * @param allowed Array of statuses corresponding to the accounts
     */
    function setWhitelistedBatch(
        address[] calldata accounts,
        bool[] calldata allowed
    ) external;
}
