// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IWhitelist} from "./IWhitelist.sol";
import {NotWhitelisted} from "./IWhitelistErrors.sol";

/**
 * @title Whitelist
 * @notice Inheritable whitelist utility with events and an optional "open" mode.
 * @dev Use `onlyWhitelisted(account)` to gate functions. Manage status via
 *      `_setWhitelisted` or `_setWhitelistedBatch`. If `address(0)` is set to
 *      allowed, the whitelist becomes open and all accounts are considered allowed.
 */
abstract contract Whitelist is IWhitelist {
    /**
     * STATE
     */

    /**
     * @notice Mapping indicating whether an account is whitelisted
     * @dev Special case: when `_whitelisted[address(0)] == true`, the whitelist is open and
     *      all addresses are treated as whitelisted.
     */
    mapping(address account => bool isWhitelisted) internal _whitelisted;

    /**
     * MODIFIERS
     */

    /**
     * @notice Ensures `account` is whitelisted, otherwise reverts.
     * @param account The account to check.
     * @dev No-op when the whitelist is open (i.e., `address(0)` is allowed).
     */
    modifier onlyWhitelisted(address account) {
        _revertIfNotWhitelisted(account);
        _;
    }

    ///@inheritdoc IWhitelist
    function isWhitelisted(address account) external view returns (bool) {
        return _isWhitelisted(account);
    }

    ///@inheritdoc IWhitelist
    function setWhitelisted(address account, bool allowed) external virtual {
        _setWhitelisted(account, allowed);
    }

    ///@inheritdoc IWhitelist
    function setWhitelistedBatch(
        address[] memory accounts,
        bool[] memory allowed
    ) external virtual {
        _setWhitelistedBatch(accounts, allowed);
    }

    /**
     * INTERNAL VIEW / VALIDATION
     */

    /**
     * @notice Returns true if `account` is whitelisted.
     * @dev Returns true for any account when the whitelist is open.
     */
    function _isWhitelisted(address account) internal view returns (bool) {
        return _isWhitelistOpen() || _whitelisted[account];
    }

    /**
     * @notice Reverts with NotWhitelisted if `account` is not whitelisted.
     * @dev No-op when the whitelist is open.
     */
    function _revertIfNotWhitelisted(address account) internal view {
        if (!_isWhitelisted(account)) {
            revert NotWhitelisted(account);
        }
    }

    /**
     * INTERNAL STATE CHANGE HELPERS
     * @dev Expose small helpers so inheriting contracts can control access.
     */

    /**
     * @notice Sets whitelist status for `account` to `allowed`.
     * @dev Access control must be added by the inheriting contract.
     *      Using `account = address(0)` toggles the open whitelist behavior for all accounts.
     */
    function _setWhitelisted(address account, bool allowed) internal {
        _whitelisted[account] = allowed;
        emit WhitelistStatusUpdated(account, allowed);
    }

    /**
     * @notice Batch set whitelist statuses.
     * @dev Lengths must match; access control in the inheriting contract. Including `address(0)`
     *      toggles the open whitelist behavior for all accounts.
     */
    function _setWhitelistedBatch(
        address[] memory accounts,
        bool[] memory allowed
    ) internal {
        uint256 length = accounts.length;
        require(length == allowed.length, "Whitelist: length mismatch");
        for (uint256 i = 0; i < length; i++) {
            _whitelisted[accounts[i]] = allowed[i];
            emit WhitelistStatusUpdated(accounts[i], allowed[i]);
        }
    }

    /**
     * @notice Returns true if the whitelist is in open mode.
     * @dev Open mode is enabled by whitelisting `address(0)`.
     */
    function _isWhitelistOpen() internal view returns (bool) {
        return _whitelisted[address(0)];
    }
}
