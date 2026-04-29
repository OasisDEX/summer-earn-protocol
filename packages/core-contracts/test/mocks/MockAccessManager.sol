// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {IProtocolAccessManagerV2} from "@summerfi/access-contracts/interfaces/IProtocolAccessManagerV2.sol";

/**
 * @title MockAccessManager
 * @notice Mock implementation of AccessManager for testing
 */
contract MockAccessManager {
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant FOUNDATION_ROLE = keccak256("FOUNDATION_ROLE");

    mapping(bytes32 => mapping(address => bool)) public roles;
    mapping(address => mapping(address => bool)) public whitelisted;
    mapping(address => bool) public whitelistOpen;

    function hasRole(
        bytes32 role,
        address account
    ) external view returns (bool) {
        return roles[role][account];
    }

    function grantRole(bytes32 role, address account) external {
        roles[role][account] = true;
    }

    function revokeRole(bytes32 role, address account) external {
        roles[role][account] = false;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return
            interfaceId == type(IProtocolAccessManagerV2).interfaceId ||
            interfaceId == type(IProtocolAccessManager).interfaceId;
    }

    /*//////////////////////////////////////////////////////////////
                            WHITELIST LOGIC
    //////////////////////////////////////////////////////////////*/

    function isWhitelisted(
        address context,
        address account
    ) external view returns (bool) {
        return whitelistOpen[context] || whitelisted[context][account];
    }

    function areWhitelisted(
        address context,
        address[] calldata accounts
    ) external view returns (bool[] memory statuses) {
        statuses = new bool[](accounts.length);
        bool isOpen = whitelistOpen[context];
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
