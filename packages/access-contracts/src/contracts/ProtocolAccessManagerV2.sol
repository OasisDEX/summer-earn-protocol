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

    /// @notice Role identifier for whitelist managers who can update the global whitelist status
    bytes32 public constant WHITELIST_MANAGER_ROLE =
        keccak256("WHITELIST_MANAGER_ROLE");

    /*//////////////////////////////////////////////////////////////
                                  STATE
    //////////////////////////////////////////////////////////////*/

    /// @dev Internal mapping for whitelist status. address(0) is a special key for "Globally Open".
    mapping(address => bool) private _whitelisted;

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

    // 3. Add Whitelist Logic

    /// @inheritdoc IProtocolAccessManagerV2
    function isWhitelisted(address account) public view returns (bool) {
        // If address(0) is whitelisted, the gateway is globally open
        return _whitelisted[address(0)] || _whitelisted[account];
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
        address account,
        bool allowed
    ) external onlyRole(WHITELIST_MANAGER_ROLE) {
        _setWhitelisted(account, allowed);
    }

    /// @inheritdoc IProtocolAccessManagerV2
    function setWhitelistedBatch(
        address[] calldata accounts,
        bool[] calldata allowed
    ) external onlyRole(WHITELIST_MANAGER_ROLE) {
        require(accounts.length == allowed.length, "Length mismatch");
        for (uint256 i = 0; i < accounts.length; i++) {
            _setWhitelisted(accounts[i], allowed[i]);
        }
    }

    /**
     * @dev Idempotent internal setter for whitelist status
     * @param account The account to update
     * @param allowed The new status
     */
    function _setWhitelisted(address account, bool allowed) internal {
        if (_whitelisted[account] != allowed) {
            _whitelisted[account] = allowed;
            emit WhitelistStatusUpdated(account, allowed);
        }
    }
}
