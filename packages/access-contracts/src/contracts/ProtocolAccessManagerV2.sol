// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ContractSpecificRoles} from "../interfaces/IProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../interfaces/IProtocolAccessManager.sol";
import {IProtocolAccessManagerV2} from "../interfaces/IProtocolAccessManagerV2.sol";
import {ProtocolAccessManager} from "./ProtocolAccessManager.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title ProtocolAccessManagerV2
 * @notice This contract extends ProtocolAccessManager with a new Operator role and Whitelisting logic.
 * @dev Replaces the original ProtocolAccessManager for new Fleet variants (Whitelist/Institution)
 *      that require restricted entry/exit gateways.
 */
contract ProtocolAccessManagerV2 is
    IProtocolAccessManagerV2,
    ProtocolAccessManager
{
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Maximum number of accounts that can be whitelisted in a single batch.
     */
    uint256 public constant MAX_WHITELIST_BATCH_SIZE = 200;

    /// @notice Role identifier for whitelist managers who can update the global whitelist status
    bytes32 public constant WHITELIST_MANAGER_ROLE =
        keccak256("WHITELIST_MANAGER_ROLE");

    /*//////////////////////////////////////////////////////////////
                                  STATE
    //////////////////////////////////////////////////////////////*/

    /// @dev Internal mapping for whitelist status: context => account => allowed.
    mapping(address => mapping(address => bool)) private _whitelisted;

    /// @dev Internal mapping for "Whitelist Open" status: context => isOpen.
    mapping(address => bool) private _isWhitelistOpen;

    /**
     * @notice Initializes the ProtocolAccessManagerV2 contract
     * @param governor Address of the initial governor
     */
    constructor(address governor) ProtocolAccessManager(governor) {
        _grantRole(WHITELIST_MANAGER_ROLE, governor);
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IProtocolAccessManagerV2).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IProtocolAccessManagerV2
    function grantOperatorRole(
        address fleetCommanderAddress,
        address account
    ) public onlyGovernor {
        grantContractSpecificRole(
            ContractSpecificRoles.OPERATOR_ROLE,
            fleetCommanderAddress,
            account
        );
    }

    /// @inheritdoc IProtocolAccessManagerV2
    function revokeOperatorRole(
        address fleetCommanderAddress,
        address account
    ) public onlyGovernor {
        revokeContractSpecificRole(
            ContractSpecificRoles.OPERATOR_ROLE,
            fleetCommanderAddress,
            account
        );
    }

    /// @inheritdoc IProtocolAccessManagerV2
    function isWhitelisted(
        address context,
        address account
    ) public view returns (bool) {
        return
            _isWhitelistOpen[context] ||
            _whitelisted[context][account];
    }

    /// @inheritdoc IProtocolAccessManagerV2
    function areWhitelisted(
        address context,
        address[] calldata accounts
    ) external view returns (bool[] memory statuses) {
        bool isOpen = _isWhitelistOpen[context];
        statuses = new bool[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            statuses[i] = isOpen || _whitelisted[context][accounts[i]];
        }
    }

    /// @inheritdoc IProtocolAccessManagerV2
    function isWhitelistOpen(address context) external view returns (bool) {
        return _isWhitelistOpen[context];
    }

    /// @inheritdoc IProtocolAccessManagerV2
    function grantWhitelistManagerRole(address account) external onlyGovernor {
        _grantRole(WHITELIST_MANAGER_ROLE, account);
    }

    /// @inheritdoc IProtocolAccessManagerV2
    function revokeWhitelistManagerRole(address account) external onlyGovernor {
        _revokeRole(WHITELIST_MANAGER_ROLE, account);
    }

    /// @inheritdoc IProtocolAccessManagerV2
    function setWhitelisted(
        address context,
        address account,
        bool allowed
    ) external onlyRole(WHITELIST_MANAGER_ROLE) {
        _setWhitelisted(context, account, allowed);
    }

    /// @inheritdoc IProtocolAccessManagerV2
    function setWhitelistedBatch(
        address context,
        address[] calldata accounts,
        bool[] calldata allowed
    ) external onlyRole(WHITELIST_MANAGER_ROLE) {
        if (accounts.length == 0 || accounts.length != allowed.length) {
            revert Whitelist_LengthMismatch();
        }
        if (accounts.length > MAX_WHITELIST_BATCH_SIZE) {
            revert Whitelist_BatchTooLarge();
        }
        for (uint256 i = 0; i < accounts.length; i++) {
            _setWhitelisted(context, accounts[i], allowed[i]);
        }
    }

    /// @inheritdoc IProtocolAccessManagerV2
    function setWhitelistOpen(
        address context,
        bool isOpen
    ) external onlyRole(WHITELIST_MANAGER_ROLE) {
        if (_isWhitelistOpen[context] != isOpen) {
            _isWhitelistOpen[context] = isOpen;
            emit WhitelistOpenUpdated(context, isOpen);
        }
    }

    /**
     * @dev Idempotent internal setter for whitelist status
     * @param context The context for which to update the status
     * @param account The account to update
     * @param allowed The new status
     */
    function _setWhitelisted(
        address context,
        address account,
        bool allowed
    ) internal {
        if (_whitelisted[context][account] != allowed) {
            _whitelisted[context][account] = allowed;
            emit WhitelistStatusUpdated(context, account, allowed);
        }
    }
}
