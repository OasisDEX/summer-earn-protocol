// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {IProtocolAccessManagerV2} from "@summerfi/access-contracts/interfaces/IProtocolAccessManagerV2.sol";

/**
 * @title MockAccessManager
 * @notice Mock implementation of AccessManager for testing
 */
contract MockAccessManager {
    mapping(address => bool) public governors;
    mapping(bytes32 => mapping(address => bool)) public roles;
    mapping(address => mapping(address => bool)) public whitelisted;
    mapping(address => bool) public whitelistOpen;

    constructor() {
        governors[msg.sender] = true;
    }

    function setGovernor(address governor, bool isGovernor) external {
        governors[governor] = isGovernor;
    }

    function hasRole(
        bytes32 role,
        address account
    ) external view returns (bool) {
        if (role == keccak256("GOVERNOR_ROLE")) {
            return governors[account];
        }
        return roles[role][account];
    }

    function setRole(bytes32 role, address account, bool _hasRole) external {
        roles[role][account] = _hasRole;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return
            interfaceId == type(IProtocolAccessManager).interfaceId ||
            interfaceId == type(IProtocolAccessManagerV2).interfaceId;
    }

    /*//////////////////////////////////////////////////////////////
                            WHITELIST LOGIC
    //////////////////////////////////////////////////////////////*/

    function isWhitelisted(
        address context,
        address account
    ) external view returns (bool) {
        return
            whitelistOpen[context] ||
            whitelisted[context][account];
    }

    function areWhitelisted(
        address context,
        address[] calldata accounts
    ) external view returns (bool[] memory statuses) {
        bool isOpen = whitelistOpen[context];
        statuses = new bool[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            statuses[i] = isOpen || whitelisted[context][accounts[i]];
        }
    }

    function isWhitelistOpen(address context) external view returns (bool) {
        return whitelistOpen[context];
    }

    function setWhitelisted(
        address context,
        address account,
        bool allowed
    ) external {
        whitelisted[context][account] = allowed;
    }

    function setWhitelistedBatch(
        address context,
        address[] calldata accounts,
        bool[] calldata allowed
    ) external {
        require(accounts.length == allowed.length, "Length mismatch");
        for (uint256 i = 0; i < accounts.length; i++) {
            whitelisted[context][accounts[i]] = allowed[i];
        }
    }

    function setWhitelistOpen(address context, bool isOpen) external {
        whitelistOpen[context] = isOpen;
    }

    // Add required functions from IProtocolAccessManager for completeness
    function isValidAdapter(address) external pure returns (bool) {
        return true; // Always return true for testing
    }

    function testSkipper() public {}
}
