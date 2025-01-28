// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {ISummerGovernor} from "@summerfi/earn-gov-contracts/interfaces/ISummerGovernor.sol";

contract MockSummerGovernor is ERC165 {
    mapping(bytes32 => mapping(address => bool)) private roles;

    constructor() {}

    function test_() public {}

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
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(ISummerGovernor).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
