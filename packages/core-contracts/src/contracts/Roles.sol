// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/**
 * @title Roles
 * @dev Contract for defining and managing system roles.
 */
contract Roles {
    /**
     * @dev Admin role has the highest level of access, capable of managing all other roles.
     */
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /**
     * @dev The Governor role is in charge of setting the parameters of the system
     *      and also has the power to manage the different Fleet Commander roles.
     */
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    /**
     * @dev The Keeper role is in charge of rebalancing the funds between the different
     *         Arks through the Fleet Commander
     */
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
}
