// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {GovernorVotes, Governor, IVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotesQuorumFraction} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {VotingDecayLibrary} from "../src/VotingDecayLibrary.sol";
import {VotingDecayManager} from "../src/VotingDecayManager.sol";

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

    // Add these constants
    uint256 public constant MIN_PROPOSAL_THRESHOLD = 1000e18; // 1,000 Tokens
    uint256 public constant MAX_PROPOSAL_THRESHOLD = 100000e18; // 100,000 Tokens

    // Add this state variable
    uint256 private _proposalThreshold;

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

    // Add these functions to expose internal functionality for testing
    function initializeAccount(address account) public {
        _initializeAccountIfNew(account);
    }

    function resetDecay(address account) public {
        _resetDecay(account);
    }

    /**
     * @dev Proposes a new governance action.
     * @param targets The addresses of the contracts to call.
     * @param values The ETH values to send with the calls.
     * @param calldatas The call data for each contract call.
     * @param description A description of the proposal.
     * @return The ID of the newly created proposal.
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public virtual override(Governor) returns (uint256) {
        address proposer = _msgSender();

        _initializeAccountIfNew(proposer);

        /* uint256 proposerVotes =*/ getVotes(proposer, block.number - 1);

        uint256 proposalId = super.propose(
            targets,
            values,
            calldatas,
            description
        );

        return proposalId;
    }

    function setDecayRatePerSecond(uint256 newRatePerSecond) external {
        _setDecayRatePerSecond(newRatePerSecond);
    }

    function setDecayFreeWindow(uint40 newWindow) external {
        _setDecayFreeWindow(newWindow);
    }

    function setDecayFunction(
        VotingDecayLibrary.DecayFunction newFunction
    ) external {
        _setDecayFunction(newFunction);
    }
}
