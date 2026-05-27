// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ContractSpecificRoles} from "../interfaces/IProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../interfaces/IProtocolAccessManager.sol";
import {IProtocolAccessManagerV2} from "../interfaces/IProtocolAccessManagerV2.sol";
import {ProtocolAccessManager} from "./ProtocolAccessManager.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title ProtocolAccessManagerV2
 *
 * @notice Extends `ProtocolAccessManager` with a per-contract `OPERATOR_ROLE`, a global
 *         `WHITELIST_MANAGER_ROLE`, and a per-context whitelist used to gate user interaction
 *         with institutional Fleet variants.
 *
 * @dev Role hierarchy:
 *      - Governor bootstraps every other role (including the Whitelist Manager) and is the only
 *        role that can grant or revoke contract-specific Operator roles.
 *      - Whitelist Manager owns mutations on the per-context whitelist (`setWhitelisted`,
 *        `setWhitelistedBatch`, `setWhitelistOpen`).
 *      - Operator (per contract, scoped via `generateRole(OPERATOR_ROLE, contract)`) is consulted
 *        by inheriting contracts (`ProtocolAccessManagedV2.hasOperatorRole`) and lets bundlers
 *        (e.g. AdmiralsQuartersWhitelist, RoundsVaultInput/Output) bypass a Fleet's user-side
 *        gateway when invoking it.
 *
 * @dev Whitelist semantics: `isWhitelisted(context, account)` returns `true` when either the
 *      context's whitelist has been globally opened (`setWhitelistOpen(context, true)`) or when
 *      the explicit `(context, account)` mapping is set. The context is typically the Fleet
 *      address performing the check — granting one whitelist record unblocks every entry path
 *      that uses that Fleet as its context.
 *
 * @dev Replaces `ProtocolAccessManager` for institutional Fleet variants; legacy components keep
 *      using the V1 manager.
 */
contract ProtocolAccessManagerV2 is
    IProtocolAccessManagerV2,
    ProtocolAccessManager
{
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Hard cap on the number of accounts a single `setWhitelistedBatch` call may touch.
    ///         Prevents unbounded loops and keeps per-call gas predictable.
    uint256 public constant MAX_WHITELIST_BATCH_SIZE = 200;

    /// @notice Role identifier for the global Whitelist Manager who may mutate the per-context
    ///         whitelist (`setWhitelisted`, `setWhitelistedBatch`, `setWhitelistOpen`).
    bytes32 public constant WHITELIST_MANAGER_ROLE =
        keccak256("WHITELIST_MANAGER_ROLE");

    /*//////////////////////////////////////////////////////////////
                                  STATE
    //////////////////////////////////////////////////////////////*/

    /// @dev Per-context, per-account whitelist record. Reads go through `isWhitelisted` /
    ///      `areWhitelisted`, which also consider the context's global-open flag.
    mapping(address => mapping(address => bool)) private _whitelisted;

    /// @dev Per-context flag that, when `true`, makes every account read as whitelisted for
    ///      that context regardless of the explicit `_whitelisted` record.
    mapping(address => bool) private _isWhitelistOpen;

    /**
     * @notice Initializes the access manager with `governor` as the initial Governor and seeds it
     *         with the `WHITELIST_MANAGER_ROLE` so the deployment can immediately manage whitelist
     *         state before any other Whitelist Manager is granted.
     * @param governor Initial Governor address (typically the protocol multisig).
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
        return _isWhitelistOpen[context] || _whitelisted[context][account];
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
     * @dev Idempotent setter: only writes and emits `WhitelistStatusUpdated` when the value
     *      actually changes. Used by both single and batch entry points.
     * @param context The context (e.g. a Fleet address) the status is scoped to
     * @param account The account to update
     * @param allowed The new status (`true` to whitelist, `false` to remove)
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
