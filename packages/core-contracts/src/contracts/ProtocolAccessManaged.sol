// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ProtocolAccessManager} from "./ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../interfaces/IProtocolAccessManager.sol";
import "../errors/AccessControlErrors.sol";

// TODO: Make upgradeable

/**
 * @custom:see IAccessManaged
 */
contract ProtocolAccessManaged {
    ProtocolAccessManager internal _accessManager;

    constructor(address accessManager) {
        if (accessManager == address(0)) {
            revert InvalidAccessManagerAddress(address(0));
        }

        IProtocolAccessManager manager = IProtocolAccessManager(accessManager);

        try manager.isValidAccessManager() returns (bool result) {
            if (!result) {
                revert InvalidAccessManagerAddress(accessManager);
            }
        } catch {
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
}
