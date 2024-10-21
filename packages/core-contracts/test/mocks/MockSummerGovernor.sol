// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {ISummerGovernor} from "@summerfi/earn-gov-contracts/interfaces/ISummerGovernor.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {VotingDecayManager} from "@summerfi/voting-decay/src/VotingDecayManager.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/src/VotingDecayLibrary.sol";

contract MockSummerGovernor is ERC165, VotingDecayManager {
    mapping(bytes32 => mapping(address => bool)) private roles;

    constructor(
        uint40 initialDecayFreeWindow,
        uint256 initialDecayRate,
        VotingDecayLibrary.DecayFunction initialDecayFunction
    )
        VotingDecayManager(
            initialDecayFreeWindow,
            initialDecayRate,
            initialDecayFunction,
            address(this)
        )
    {}

    function initializeAccount(address account) external {
        _initializeAccountIfNew(account);
    }

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

    // Mock functions for governance
    function votingDelay() external pure returns (uint256) {
        return 1 days;
    }

    function votingPeriod() external pure returns (uint256) {
        return 1 weeks;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(ISummerGovernor).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function _getDelegateTo(
        address account
    ) internal pure override returns (address) {
        return account;
    }

    function updateDecayFactor(address account) external {
        _updateDecayFactor(account);
    }
}
