// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "../src/VotingDecay.sol";

contract MockGovernance {
    using VotingDecay for VotingDecay.Account;

    struct Voter {
        VotingDecay.Account account;
        uint256 baseVotingPower;
    }

    mapping(address => Voter) public voters;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => uint256) public proposalVotes;

    uint256 public constant INITIAL_DECAY_RATE = 0.1e18; // 10% annual decay
    uint256 public proposalCounter;

    event VoterRegistered(address indexed voter, uint256 baseVotingPower);
    event Voted(address indexed voter, uint256 indexed proposalId, uint256 votingPower);

    function registerVoter(uint256 baseVotingPower) external {
        require(voters[msg.sender].baseVotingPower == 0, "Voter already registered");

        Voter storage newVoter = voters[msg.sender];
        newVoter.baseVotingPower = baseVotingPower;
        newVoter.account.decayIndex = VotingDecay.PRECISION;
        newVoter.account.lastUpdateTimestamp = block.timestamp;
        newVoter.account.decayRate = INITIAL_DECAY_RATE;

        emit VoterRegistered(msg.sender, baseVotingPower);
    }

    function updateVotingPower(uint256 newBaseVotingPower) external {
        Voter storage voter = voters[msg.sender];
        require(voter.baseVotingPower > 0, "Voter not registered");

        voter.account.updateDecayIndex();
        voter.baseVotingPower = newBaseVotingPower;
    }

    function getCurrentVotingPower(address voter) public view returns (uint256) {
        Voter storage voterData = voters[voter];
        uint256 currentDecayIndex = voterData.account.getCurrentDecayIndex();
        return VotingDecay.applyDecayToVotingPower(voterData.baseVotingPower, currentDecayIndex);
    }

    function createProposal() external returns (uint256) {
        proposalCounter++;
        return proposalCounter;
    }

    function vote(uint256 proposalId) external {
        require(voters[msg.sender].baseVotingPower > 0, "Not a registered voter");
        require(!hasVoted[proposalId][msg.sender], "Already voted on this proposal");

        Voter storage voter = voters[msg.sender];
        voter.account.updateDecayIndex();

        uint256 votingPower = getCurrentVotingPower(msg.sender);
        proposalVotes[proposalId] += votingPower;
        hasVoted[proposalId][msg.sender] = true;

        emit Voted(msg.sender, proposalId, votingPower);
    }

    function delegate(address to) external {
        require(voters[msg.sender].baseVotingPower > 0, "Not a registered voter");
        require(voters[to].baseVotingPower > 0, "Delegate is not a registered voter");

        voters[msg.sender].account.delegate(voters[to].account);
    }

    function undelegate() external {
        require(voters[msg.sender].baseVotingPower > 0, "Not a registered voter");
        voters[msg.sender].account.undelegate(voters);
    }

    function setDecayRate(uint256 newRate) external {
        require(voters[msg.sender].baseVotingPower > 0, "Not a registered voter");
        voters[msg.sender].account.setDecayRate(newRate);
    }

    function refreshDecay() external {
        require(voters[msg.sender].baseVotingPower > 0, "Not a registered voter");
        voters[msg.sender].account.refreshDecay();
    }
}
