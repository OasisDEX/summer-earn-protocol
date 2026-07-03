// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ContractSpecificRoles} from "../interfaces/IProtocolAccessManager.sol";
import {IProtocolAccessManagerV2} from "../interfaces/IProtocolAccessManagerV2.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title ProtocolAccessManagedV2
 *
 * @notice Variant of `ProtocolAccessManaged` that enforces the configured access manager actually
 *         implements `IProtocolAccessManagerV2`. Inheritors gain the contract-specific Operator
 *         role hook (`hasOperatorRole`, `onlyOperator`) used by institutional FleetCommander, AQ,
 *         and rounds-vault contracts. Arks and legacy components continue to inherit from the
 *         base `ProtocolAccessManaged`.
 */
abstract contract ProtocolAccessManagedV2 is ProtocolAccessManaged {
    /**
     * @notice Wires this contract to the provided V2 access manager and validates support via
     *         ERC-165 introspection.
     * @dev The base `ProtocolAccessManaged` constructor has already checked that `accessManager`
     *      is non-zero and supports the V1 interface. This constructor additionally requires the
     *      V2 interface so that whitelist/operator features are guaranteed to work.
     * @param accessManager Address of the `ProtocolAccessManagerV2` instance.
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

    /// @notice Restricts the wrapped function to callers that hold the contract-specific Operator
    ///         role (`OPERATOR_ROLE` scoped to `address(this)`).
    modifier onlyOperator() {
        _revertIfNotOperator(_msgSender());
        _;
    }

    /**
     * @notice Reverts if the account does not hold the Operator role on this contract.
     * @dev Reverts with `CallerIsNotOperator(account)` if `account` does not hold the Operator
     *      role on this contract. Helper for `onlyOperator` and ad-hoc checks.
     * @param account The address to check.
     */
    function _revertIfNotOperator(address account) internal view {
        if (!hasOperatorRole(account)) {
            revert CallerIsNotOperator(account);
        }
    }

    /**
     * @notice Returns whether `account` holds the Operator role for this contract.
     * @dev Resolves to `_accessManager.hasRole(generateRole(OPERATOR_ROLE, address(this)), account)`.
     *      Used by inheriting contracts (e.g. FleetCommanderWhitelist) to let bundler/proxy
     *      contracts bypass user-side gateways.
     * @param account The address to check
     * @return `true` if `account` holds the Operator role for this contract.
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
}
