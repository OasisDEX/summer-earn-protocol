// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";

/**
 * @title MockAccessManager
 * @notice Mock implementation of AccessManager for testing
 */
contract MockAccessManager {
    mapping(address => bool) public governors;
    mapping(bytes32 => mapping(address => bool)) public roles;

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
        return interfaceId == type(IProtocolAccessManager).interfaceId;
    }

    // Add required functions from IProtocolAccessManager for completeness
    function isValidAdapter(address) external pure returns (bool) {
        return true; // Always return true for testing
    }

    function testSkipper() public {}
}
