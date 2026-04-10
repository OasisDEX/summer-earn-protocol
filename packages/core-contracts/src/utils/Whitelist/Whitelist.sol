// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IWhitelist} from "./IWhitelist.sol";
import {NotWhitelisted} from "./IWhitelistErrors.sol";
import {IProtocolAccessManagerV2} from "@summerfi/access-contracts/interfaces/IProtocolAccessManagerV2.sol";

/**
 * @title Whitelist
 * @notice Inheritable whitelist utility that delegates to a central ProtocolAccessManagerV2.
 * @dev All whitelisting state is now centralized. This contract acts as an adapter.
 *      Inheriting contracts must implement `_getAccessManager()` to point to the AM.
 */
abstract contract Whitelist is IWhitelist {
    /**
     * MODIFIERS
     */

    /**
     * @notice Ensures `account` is whitelisted, otherwise reverts.
     * @param account The account to check.
     */
    modifier onlyWhitelisted(address account) {
        _revertIfNotWhitelisted(account);
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
    function isWhitelisted(address account) external view returns (bool) {
        return _isWhitelisted(account);
    }

    ///@inheritdoc IWhitelist
    function setWhitelisted(address account, bool allowed) public virtual {
        IProtocolAccessManagerV2(_getAccessManager()).setWhitelisted(
            account,
            allowed
        );
    }

    ///@inheritdoc IWhitelist
    function setWhitelistedBatch(
        address[] memory accounts,
        bool[] memory allowed
    ) public virtual {
        if (accounts.length == 0 || accounts.length != allowed.length) {
            revert IProtocolAccessManagerV2.Whitelist_LengthMismatch();
        }
        if (accounts.length > 200) {
            revert IProtocolAccessManagerV2.Whitelist_BatchTooLarge();
        }
        IProtocolAccessManagerV2(_getAccessManager()).setWhitelistedBatch(
            accounts,
            allowed
        );
    }

    /**
     * INTERNAL VIEW / VALIDATION
     */

    /**
     * @notice Returns true if `account` is whitelisted.
     */
    function _isWhitelisted(address account) internal view returns (bool) {
        return
            IProtocolAccessManagerV2(_getAccessManager()).isWhitelisted(
                account
            );
    }

    /**
     * @notice Reverts with NotWhitelisted if `account` is not whitelisted.
     */
    function _revertIfNotWhitelisted(address account) internal view {
        if (!_isWhitelisted(account)) {
            revert NotWhitelisted(account);
        }
    }
}
