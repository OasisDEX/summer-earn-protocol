// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {IProtocolAccessManagerV2} from "../interfaces/IProtocolAccessManagerV2.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ContractSpecificRoles} from "../interfaces/IProtocolAccessManager.sol";

/**
 * @title ProtocolAccessManagedV2
 * @notice Extends ProtocolAccessManaged to enforce IProtocolAccessManagerV2 support.
 * @dev Used by unified FleetCommander, AQ, and Rounds Vault which require V2 features (Whitelisting).
 * Arks and legacy components should continue to use the base ProtocolAccessManaged.
 */
abstract contract ProtocolAccessManagedV2 is ProtocolAccessManaged {
    /**
     * @notice Initializes the ProtocolAccessManagedV2 contract
     * @param accessManager Address of the ProtocolAccessManager contract
     * @dev The base ProtocolAccessManaged constructor already checked for V1 and address(0).
     * Now we strictly enforce that this AM also supports the V2 interface.
     */
    constructor(address accessManager) ProtocolAccessManaged(accessManager) {
        if (
            !IERC165(accessManager).supportsInterface(
                type(IProtocolAccessManagerV2).interfaceId
            )
        ) {
            revert InvalidAccessManagerAddress(accessManager);
        }
    }

    /**
     * @notice Modifier to restrict access to operators only
     * @dev Modifier to check that the caller has the Operator role.
     */
    modifier onlyOperator() {
        _revertIfNotOperator(msg.sender);
        _;
    }

    function _revertIfNotOperator(address account) internal view {
        if (!hasOperatorRole(account)) {
            revert CallerIsNotOperator(account);
        }
    }

    /**
     * @notice Checks if an account has the Operator role
     * @param account The address to check
     * @return bool True if the account has the Operator role
     */
    function hasOperatorRole(address account) public view returns (bool) {
        return
            _accessManager.hasRole(
                generateRole(
                    ContractSpecificRoles.OPERATOR_ROLE,
                    address(this)
                ),
                account
            );
    }

    /**
     * @notice Helper to get the access manager explicitly typed as V2
     * @return IProtocolAccessManagerV2 The V2 interface of the access manager
     */
    function _getAccessManagerV2()
        internal
        view
        returns (IProtocolAccessManagerV2)
    {
        return IProtocolAccessManagerV2(address(_accessManager));
    }
}
