// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IAccessControlErrors} from "./interfaces/IAccessControlErrors.sol";
import {ContractSpecificRoles, IProtocolAccessManagerWhitelist} from "./interfaces/IProtocolAccessManagerWhitelist.sol";

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title ProtocolAccessManaged
 * @notice This contract provides role-based access control functionality for protocol contracts
 * by interfacing with a central ProtocolAccessManager.
 *
 * @dev This contract is meant to be inherited by other protocol contracts that need
 * role-based access control. It provides modifiers and utilities to check various roles.
 *
 * The contract supports several key roles through modifiers:
 * 1. GOVERNOR_ROLE: System-wide administrators
 * 2. KEEPER_ROLE: Routine maintenance operators (contract-specific)
 * 3. SUPER_KEEPER_ROLE: Advanced maintenance operators (global)
 * 4. CURATOR_ROLE: Fleet-specific managers
 * 5. GUARDIAN_ROLE: Emergency response operators
 * 6. DECAY_CONTROLLER_ROLE: Specific role for decay management
 * 7. ADMIRALS_QUARTERS_ROLE: Specific role for admirals quarters bundler contract
 *
 * Usage:
 * - Inherit from this contract to gain access to role-checking modifiers
 * - Use modifiers like onlyGovernor, onlyKeeper, etc. to protect functions
 * - Access the internal _accessManager to perform custom role checks
 *
 * Security Considerations:
 * - The contract validates the access manager address during construction
 * - All role checks are performed against the immutable access manager instance
 * - Contract-specific roles are generated using the contract's address to prevent conflicts
 */
contract ProtocolAccessManagedWhitelist is IAccessControlErrors, Context {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Role identifier for protocol governors - highest privilege level with admin capabilities
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    /// @notice Role identifier for super keepers who can globally perform fleet maintanence roles
    bytes32 public constant SUPER_KEEPER_ROLE = keccak256("SUPER_KEEPER_ROLE");

    /**
     * @notice Role identifier for admirals quarters bundler contract
     * @dev This role allows Admirals Quarters to unstake and withdraw assets from fleets, on behalf of users
     * @dev Withdrawn tokens go straight to users wallet, lowering the risk of manipulation if the role is compromised
     */
    bytes32 public constant ADMIRALS_QUARTERS_ROLE =
        keccak256("ADMIRALS_QUARTERS_ROLE");

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The ProtocolAccessManager instance used for access control
    IProtocolAccessManagerWhitelist internal immutable _accessManager;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the ProtocolAccessManaged contract
     * @param accessManager Address of the ProtocolAccessManager contract
     * @dev Validates the provided accessManager address and initializes the _accessManager
     */
    constructor(address accessManager) {
        if (accessManager == address(0)) {
            revert InvalidAccessManagerAddress(address(0));
        }

        // if (
        //     !IERC165(accessManager).supportsInterface(
        //         type(IProtocolAccessManagerWhitelist).interfaceId
        //     )
        // ) {
        //     revert InvalidAccessManagerAddress(accessManager);
        // }

        _accessManager = IProtocolAccessManagerWhitelist(accessManager);
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Modifier to restrict access to governors only
     *
     * @dev Modifier to check that the caller has the Governor role
     * @custom:internal-logic
     * - Checks if the caller has the GOVERNOR_ROLE in the access manager
     * @custom:effects
     * - Reverts if the caller doesn't have the GOVERNOR_ROLE
     * - Allows the function to proceed if the caller has the role
     * @custom:security-considerations
     * - Ensures that only authorized governors can access critical functions
     * - Relies on the correct setup of the access manager
     */
    modifier onlyGovernor() {
        if (!_accessManager.hasRole(GOVERNOR_ROLE, msg.sender)) {
            revert CallerIsNotGovernor(msg.sender);
        }
        _;
    }

    modifier onlyWhitelisted(address fleetCommanderAddress) {
        if (
            !_accessManager.hasRole(
                generateRole(
                    ContractSpecificRoles.WHITELISTED_ROLE,
                    fleetCommanderAddress
                ),
                msg.sender
            )
        ) {
            revert CallerIsNotWhitelisted(msg.sender);
        }
        _;
    }
    /**
     * @notice Modifier to restrict access to keepers only
     * @dev Modifier to check that the caller has the Keeper role
     * @custom:internal-logic
     * - Checks if the caller has either the contract-specific KEEPER_ROLE or the SUPER_KEEPER_ROLE
     * @custom:effects
     * - Reverts if the caller doesn't have either of the required roles
     * - Allows the function to proceed if the caller has one of the roles
     * @custom:security-considerations
     * - Ensures that only authorized keepers can access maintenance functions
     * - Allows for both contract-specific and super keepers
     * @custom:gas-considerations
     * - Performs two role checks, which may impact gas usage
     */
    modifier onlyKeeper() {
        if (
            !_accessManager.hasRole(
                generateRole(ContractSpecificRoles.KEEPER_ROLE, address(this)),
                msg.sender
            ) && !_accessManager.hasRole(SUPER_KEEPER_ROLE, msg.sender)
        ) {
            revert CallerIsNotKeeper(msg.sender);
        }
        _;
    }

    /**
     * @notice Modifier to restrict access to super keepers only
     * @dev Modifier to check that the caller has the Super Keeper role
     * @custom:internal-logic
     * - Checks if the caller has the SUPER_KEEPER_ROLE in the access manager
     * @custom:effects
     * - Reverts if the caller doesn't have the SUPER_KEEPER_ROLE
     * - Allows the function to proceed if the caller has the role
     * @custom:security-considerations
     * - Ensures that only authorized super keepers can access advanced maintenance functions
     * - Relies on the correct setup of the access manager
     */
    modifier onlySuperKeeper() {
        if (!_accessManager.hasRole(SUPER_KEEPER_ROLE, msg.sender)) {
            revert CallerIsNotSuperKeeper(msg.sender);
        }
        _;
    }

    /**
     * @notice Modifier to restrict access to curators only
     * @param fleetAddress The address of the fleet to check the curator role for
     * @dev Checks if the caller has the contract-specific CURATOR_ROLE
     */
    modifier onlyCurator(address fleetAddress) {
        if (
            fleetAddress == address(0) ||
            !_accessManager.hasRole(
                generateRole(ContractSpecificRoles.CURATOR_ROLE, fleetAddress),
                msg.sender
            )
        ) {
            revert CallerIsNotCurator(msg.sender);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Generates a role identifier for a specific contract and role
     * @param roleName The name of the role
     * @param roleTargetContract The address of the contract the role is for
     * @return The generated role identifier
     * @dev This function is used to create unique role identifiers for contract-specific roles
     */
    function generateRole(
        ContractSpecificRoles roleName,
        address roleTargetContract
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(roleName, roleTargetContract));
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Helper function to check if an address has the Governor role
     * @param account The address to check
     * @return bool True if the address has the Governor role
     */
    function _isGovernor(address account) internal view returns (bool) {
        return _accessManager.hasRole(GOVERNOR_ROLE, account);
    }
}
