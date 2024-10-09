// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {ContractSpecificRoles, IProtocolAccessManager} from "../interfaces/IProtocolAccessManager.sol";
import {LimitedAccessControl} from "./LimitedAccessControl.sol";

/**
 * @title ProtocolAccessManager
 * @notice Central contract for managing access control across the protocol
 * @dev Implements IProtocolAccessManager interface and extends LimitedAccessControl
 */
contract ProtocolAccessManager is IProtocolAccessManager, LimitedAccessControl {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IProtocolAccessManager
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    /// @inheritdoc IProtocolAccessManager
    bytes32 public constant SUPER_KEEPER_ROLE = keccak256("SUPER_KEEPER_ROLE");

    /// @inheritdoc IProtocolAccessManager
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the ProtocolAccessManager contract
     * @param governor Address of the initial governor
     * @dev Grants the governor address the DEFAULT_ADMIN_ROLE, GOVERNOR_ROLE, and GUARDIAN_ROLE
     */
    constructor(address governor) {
        _grantRole(DEFAULT_ADMIN_ROLE, governor);
        _grantRole(GOVERNOR_ROLE, governor);
        _grantRole(GUARDIAN_ROLE, governor);
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Modifier to check that the caller has the Admin role
     */
    modifier onlyAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert CallerIsNotAdmin(msg.sender);
        }
        _;
    }

    /**
     * @dev Modifier to check that the caller has the Governor role
     */
    modifier onlyGovernor() {
        if (!hasRole(GOVERNOR_ROLE, msg.sender)) {
            revert CallerIsNotGovernor(msg.sender);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks if the contract supports a given interface
     * @dev Overrides the supportsInterface function from AccessControl
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @return bool True if the contract supports the interface, false otherwise
     *
     * This function supports:
     * - IProtocolAccessManager interface
     * - All interfaces supported by the parent AccessControl contract
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return
            interfaceId == type(IProtocolAccessManager).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IProtocolAccessManager
    function grantAdminRole(address account) external onlyAdmin {
        _grantRole(DEFAULT_ADMIN_ROLE, account);
    }

    /// @inheritdoc IProtocolAccessManager
    function revokeAdminRole(address account) external onlyAdmin {
        _revokeRole(DEFAULT_ADMIN_ROLE, account);
    }

    /// @inheritdoc IProtocolAccessManager
    function grantGovernorRole(address account) external onlyAdmin {
        _grantRole(GOVERNOR_ROLE, account);
    }

    /// @inheritdoc IProtocolAccessManager
    function revokeGovernorRole(address account) external onlyAdmin {
        _revokeRole(GOVERNOR_ROLE, account);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL GOVERNOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IProtocolAccessManager
    function grantSuperKeeperRole(address account) external onlyGovernor {
        _grantRole(SUPER_KEEPER_ROLE, account);
    }

    /// @inheritdoc IProtocolAccessManager
    function grantGuardianRole(address account) external onlyGovernor {
        _grantRole(GUARDIAN_ROLE, account);
    }

    /// @inheritdoc IProtocolAccessManager
    function revokeGuardianRole(address account) external onlyGovernor {
        _revokeRole(GUARDIAN_ROLE, account);
    }

    /// @inheritdoc IProtocolAccessManager
    function revokeSuperKeeperRole(address account) external onlyGovernor {
        _revokeRole(SUPER_KEEPER_ROLE, account);
    }

    /// @inheritdoc IProtocolAccessManager
    function grantContractSpecificRole(
        ContractSpecificRoles roleName,
        address roleTargetContract,
        address roleOwner
    ) public onlyGovernor {
        bytes32 role = generateRole(roleName, roleTargetContract);
        _grantRole(role, roleOwner);
    }

    /// @inheritdoc IProtocolAccessManager
    function revokeContractSpecificRole(
        ContractSpecificRoles roleName,
        address roleTargetContract,
        address roleOwner
    ) public onlyGovernor {
        bytes32 role = generateRole(roleName, roleTargetContract);
        _revokeRole(role, roleOwner);
    }

    /// @inheritdoc IProtocolAccessManager
    function grantCuratorRole(
        address fleetAddress,
        address account
    ) public onlyGovernor {
        grantContractSpecificRole(
            ContractSpecificRoles.CURATOR_ROLE,
            fleetAddress,
            account
        );
    }

    /// @inheritdoc IProtocolAccessManager
    function revokeCuratorRole(
        address fleetAddress,
        address account
    ) public onlyGovernor {
        revokeContractSpecificRole(
            ContractSpecificRoles.CURATOR_ROLE,
            fleetAddress,
            account
        );
    }

    /// @inheritdoc IProtocolAccessManager
    function grantKeeperRole(
        address fleetAddress,
        address account
    ) public onlyGovernor {
        grantContractSpecificRole(
            ContractSpecificRoles.KEEPER_ROLE,
            fleetAddress,
            account
        );
    }

    /// @inheritdoc IProtocolAccessManager
    function revokeKeeperRole(
        address fleetAddress,
        address account
    ) public onlyGovernor {
        revokeContractSpecificRole(
            ContractSpecificRoles.KEEPER_ROLE,
            fleetAddress,
            account
        );
    }

    /// @inheritdoc IProtocolAccessManager
    function grantCommanderRole(
        address arkAddress,
        address account
    ) public onlyGovernor {
        grantContractSpecificRole(
            ContractSpecificRoles.COMMANDER_ROLE,
            arkAddress,
            account
        );
    }

    /// @inheritdoc IProtocolAccessManager
    function revokeCommanderRole(
        address arkAddress,
        address account
    ) public onlyGovernor {
        revokeContractSpecificRole(
            ContractSpecificRoles.COMMANDER_ROLE,
            arkAddress,
            account
        );
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IProtocolAccessManager
    function selfRevokeContractSpecificRole(
        ContractSpecificRoles roleName,
        address roleTargetContract
    ) public {
        bytes32 role = generateRole(roleName, roleTargetContract);
        if (!hasRole(role, msg.sender)) {
            revert CallerIsNotContractSpecificRole(msg.sender, role);
        }
        _revokeRole(role, msg.sender);
    }

    /// @inheritdoc IProtocolAccessManager
    function generateRole(
        ContractSpecificRoles roleName,
        address roleTargetContract
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(roleName, roleTargetContract));
    }
}
