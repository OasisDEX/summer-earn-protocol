// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {IAccessControlErrors} from "../errors/IAccessControlErrors.sol";
import {ContractSpecificRoles, IProtocolAccessManager} from "../interfaces/IProtocolAccessManager.sol";
import {ProtocolAccessManager} from "./ProtocolAccessManager.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
// import {Context} from "@openzeppelin/contracts/utils/Context.sol";

/**
 * @title ProtocolAccessManaged
 * @notice Defines shared modifiers for all managed contracts
 */
contract ProtocolAccessManaged is IAccessControlErrors {
    ProtocolAccessManager internal _accessManager;

    constructor(address accessManager) {
        if (accessManager == address(0)) {
            revert InvalidAccessManagerAddress(address(0));
        }

        if (
            !IERC165(accessManager).supportsInterface(
                type(IProtocolAccessManager).interfaceId
            )
        ) {
            revert InvalidAccessManagerAddress(accessManager);
        }

        _accessManager = ProtocolAccessManager(accessManager);
    }

    /**
     * @dev Modifier to check that the caller has the Governor role
     */
    modifier onlyGovernor() {
        if (
            !_accessManager.hasRole(_accessManager.GOVERNOR_ROLE(), msg.sender)
        ) {
            revert CallerIsNotGovernor(msg.sender);
        }
        _;
    }

    /**
     * @dev Modifier to check that the caller has the Keeper role
     */
    modifier onlyKeeper() {
        if (
            !_accessManager.hasRole(
                generateRole(ContractSpecificRoles.KEEPER_ROLE, address(this)),
                msg.sender
            ) &&
            !_accessManager.hasRole(
                _accessManager.SUPER_KEEPER_ROLE(),
                msg.sender
            )
        ) {
            revert CallerIsNotKeeper(msg.sender);
        }
        _;
    }

    /**
     * @dev Modifier to check that the caller has the Super Keeper role
     */
    modifier onlySuperKeeper() {
        if (
            !_accessManager.hasRole(
                _accessManager.SUPER_KEEPER_ROLE(),
                msg.sender
            )
        ) {
            revert CallerIsNotSuperKeeper(msg.sender);
        }
        _;
    }

    /**
     * @dev Modifier to check that the caller has the Curator role
     */
    modifier onlyCurator() {
        if (
            !_accessManager.hasRole(
                generateRole(ContractSpecificRoles.CURATOR_ROLE, address(this)),
                msg.sender
            )
        ) {
            revert CallerIsNotCurator(msg.sender);
        }
        _;
    }

    /* @inheritdoc IProtocolAccessControl */
    function generateRole(
        ContractSpecificRoles roleName,
        address roleTargetContract
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(roleName, roleTargetContract));
    }
}
