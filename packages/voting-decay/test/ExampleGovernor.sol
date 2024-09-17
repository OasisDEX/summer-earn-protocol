// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {GovernorVotes, Governor, IVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotesQuorumFraction} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {VotingDecayLibrary} from "../src/VotingDecayLibrary.sol";
import {VotingDecayManager} from "../src/VotingDecayManager.sol";
import {Test, console} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

// TODO: Refactor to only use VotingDecayManager when proposing or casting votes

/**
 * @title ExampleGovernance
 * @dev A basic governance contract that implements voting power decay using OpenZeppelin's Governor
 */
contract ExampleGovernor is
    VotingDecayManager,
    GovernorCountingSimple,
    GovernorVotesQuorumFraction
{
    bytes32 private constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    constructor(
        string memory name,
        IVotes token_,
        uint256 initialDecayFreeWindow,
        uint256 initialDecayRate,
        VotingDecayLibrary.DecayFunction initialDecayFunction
    )
        Governor(name)
        GovernorVotes(token_)
        GovernorVotesQuorumFraction(1)
        VotingDecayManager(
            uint40(initialDecayFreeWindow),
            initialDecayRate,
            initialDecayFunction
        )
    {}

    function votingDelay() public pure override returns (uint256) {
        return 1; // 1 block
    }

    function votingPeriod() public pure override returns (uint256) {
        return 45_818; // 1 week
    }

    /**
     * @dev Calculates the quorum for a specific timepoint.
     * @param timepoint The timepoint to calculate the quorum for.
     * @return The quorum value.
     */
    function quorum(
        uint256 timepoint
    )
        public
        view
        override(Governor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(timepoint);
    }

    /**
     * @dev Override getVotes to apply decay to the voting power
     * @param account The address to get votes for
     * @param timepoint The timepoint to get votes at
     */
    function getVotes(
        address account,
        uint256 timepoint
    ) public view virtual override(Governor) returns (uint256) {
        return _getVotes(account, timepoint, "");
    }

    /**
     * @dev Override _getVotes to apply decay to the voting power
     * @param account The address to get votes for
     * @param timepoint The timepoint to get votes at
     * @param ///params/// Additional parameters (unused in this implementation)
     */
    function _getVotes(
        address account,
        uint256 timepoint,
        bytes memory /*params*/
    )
        internal
        view
        virtual
        override(GovernorVotes, Governor)
        returns (uint256)
    {
        uint256 originalVotes = token().getPastVotes(account, timepoint);
        return getVotingPower(account, originalVotes);
    }

    function _castVote(
        uint256 proposalId,
        address account,
        uint8 support,
        string memory reason,
        bytes memory params
    ) internal override returns (uint256) {
        uint256 weight = super._castVote(
            proposalId,
            account,
            support,
            reason,
            params
        );
        uint256 decayedWeight = getVotingPower(account, weight);
        _updateDecayFactor(account);
        return decayedWeight;
    }

    function _getDelegateTo(
        address account
    ) internal view override returns (address) {
        return token().delegates(account);
    }

    // Define the custom error at the contract level
    error InvalidSignature(address signer, address account);
}
