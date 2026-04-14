// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IWhitelist} from "./IWhitelist.sol";
import {NotWhitelisted} from "./IWhitelistErrors.sol";
import {IProtocolAccessManagerV2} from "@summerfi/access-contracts/interfaces/IProtocolAccessManagerV2.sol";

/**
 * @title Whitelist
 * @notice Inheritable whitelist utility that delegates to a central ProtocolAccessManagerV2.
 * @dev All whitelisting state is now centralized and scoped by a context (e.g. the vault itself).
 *      Inheriting contracts must implement `_getAccessManager()`.
 */
abstract contract Whitelist is IWhitelist {
    /**
     * MODIFIERS
     */

    /**
     * @notice Ensures `account` is whitelisted in `context`, otherwise reverts.
     * @param context The context for which the account status is checked.
     * @param account The account to check.
     */
    modifier onlyWhitelisted(address context, address account) {
        _revertIfNotWhitelisted(context, account);
        _;
    }

    /**
     * VIRTUAL HOOK
     */

    /**
     * @notice Returns the address of the access manager to delegate to.
     * @dev Must be implemented by the inheriting contract.
     */
    function _getAccessManager() internal view virtual returns (address);

    /**
     * PUBLIC FUNCTIONS
     */

    ///@inheritdoc IWhitelist
    function isWhitelisted(
        address context,
        address account
    ) external view returns (bool) {
        return _isWhitelisted(context, account);
    }

    ///@inheritdoc IWhitelist
    function isWhitelistOpen(
        address context
    ) public view virtual returns (bool) {
        return _isWhitelistOpen(context);
    }

    /**
     * INTERNAL VIEW / VALIDATION
     */

    /**
     * @notice Returns true if the whitelist for a specific context is globally open
     */
    function _isWhitelistOpen(address context) internal view returns (bool) {
        return
            IProtocolAccessManagerV2(_getAccessManager()).isWhitelistOpen(
                context
            );
    }

    /**
     * @notice Returns true if `account` is whitelisted in `context`.
     */
    function _isWhitelisted(
        address context,
        address account
    ) internal view returns (bool) {
        return
            IProtocolAccessManagerV2(_getAccessManager()).isWhitelisted(
                context,
                account
            );
    }

    /**
     * @notice Reverts with NotWhitelisted if `account` is not whitelisted in `context`.
     */
    function _revertIfNotWhitelisted(
        address context,
        address account1
    ) internal view {
        if (!_isWhitelisted(context, account1)) {
            revert NotWhitelisted(context, account1);
        }
    }
    /**
     * @notice Reverts with NotWhitelisted if `account` is not whitelisted in `context`.
     */
    function _revertIfNotWhitelisted(
        address context,
        address account1,
        address account2
    ) internal view {
        address[] memory accounts = new address[](2);
        accounts[0] = account1;
        accounts[1] = account2;
        _revertIfNotWhitelisted(context, accounts);
    }

    /**
     * @notice Reverts with NotWhitelisted if `account` is not whitelisted in `context`.
     */
    function _revertIfNotWhitelisted(
        address context,
        address account1,
        address account2,
        address account3
    ) internal view {
        address[] memory accounts = new address[](3);
        accounts[0] = account1;
        accounts[1] = account2;
        accounts[2] = account3;
        _revertIfNotWhitelisted(context, accounts);
    }
    /**
     * @notice Reverts if any of the `accounts` is not whitelisted in `context`.
     * @dev Optimized with a single external batch call relative to `context`.
     */
    function _revertIfNotWhitelisted(
        address context,
        address[] memory accounts
    ) internal view {
        IProtocolAccessManagerV2 am = IProtocolAccessManagerV2(
            _getAccessManager()
        );

        bool[] memory statuses = am.areWhitelisted(context, accounts);
        for (uint256 i = 0; i < accounts.length; i++) {
            if (!statuses[i]) {
                revert NotWhitelisted(context, accounts[i]);
            }
        }
    }
}
