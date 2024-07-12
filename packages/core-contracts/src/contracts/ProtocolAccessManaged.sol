// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ProtocolAccessManager} from "./ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../interfaces/IProtocolAccessManager.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../errors/AccessControlErrors.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title ProtocolAccessManaged
 * @notice Defines shared modifiers for all managed contracts
 */
contract ProtocolAccessManaged is Initializable {
    ProtocolAccessManager internal _accessManager;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function __ProtocolAccessManaged_init(
        address accessManager
    ) internal onlyInitializing {
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
     * @dev Modifier to check that the caller has the Factory role
     */
    modifier onlyFactory() {
        if (
            !_accessManager.hasRole(_accessManager.FACTORY_ROLE(), msg.sender)
        ) {
            revert CallerIsNotFactory(msg.sender);
        }
        _;
    }
}
