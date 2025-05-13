// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ProtocolAccessManaged, ContractSpecificRoles} from "./ProtocolAccessManaged.sol";

/**
 * @title ProtocolAccessManagedExt
 * @notice Contract that provides shared access control for governor and keeper roles
 * @dev This contract can be inherited by contracts that need governor and keeper access control
 */
abstract contract ProtocolAccessManagedExt is ProtocolAccessManaged {
    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Error thrown when caller is neither governor nor keeper
    error CallerIsNotGovernorOrKeeper(address caller);

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Modifier to restrict access to either governors or keepers
    modifier onlyGovernorOrKeeper() {
        if (
            !_accessManager.hasRole(GOVERNOR_ROLE, msg.sender) &&
            !_accessManager.hasRole(
                generateRole(ContractSpecificRoles.KEEPER_ROLE, address(this)),
                msg.sender
            ) &&
            !_accessManager.hasRole(SUPER_KEEPER_ROLE, msg.sender)
        ) {
            revert CallerIsNotGovernorOrKeeper(msg.sender);
        }
        _;
    }
}
