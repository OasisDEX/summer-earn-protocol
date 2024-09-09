// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IProtocolAccessManager} from "../interfaces/IProtocolAccessManager.sol";
import {ProtocolAccessManager} from "./ProtocolAccessManager.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IAccessControlErrors} from "../errors/IAccessControlErrors.sol";

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
        if (!_accessManager.hasRole(_accessManager.KEEPER_ROLE(), msg.sender)) {
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
}
