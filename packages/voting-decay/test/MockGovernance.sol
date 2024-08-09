// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "../src/VotingDecayLibrary.sol";
import "../src/VotingDecayManager.sol";

contract MockGovernance {
    VotingDecayManager public decayManager;

    struct Voter {
        uint256 baseVotingPower;
        bool isRegistered;
    }

    mapping(address => Voter) public voters;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => uint256) public proposalVotes;

    uint256 public constant INITIAL_DECAY_RATE = 0.1e27; // 10% annual decay (using RAY)
    uint256 public proposalCounter;

    event VoterRegistered(address indexed voter, uint256 baseVotingPower);
    event Voted(address indexed voter, uint256 indexed proposalId, uint256 votingPower);

    constructor() {
        decayManager = new VotingDecayManager();
    }

    function registerVoter(uint256 baseVotingPower) external {
        require(!voters[msg.sender].isRegistered, "Voter already registered");

        voters[msg.sender] = Voter({
            baseVotingPower: baseVotingPower,
            isRegistered: true
        });

        decayManager.setDecayRate(msg.sender, INITIAL_DECAY_RATE);

        emit VoterRegistered(msg.sender, baseVotingPower);
    }

    function updateVotingPower(uint256 newBaseVotingPower) external {
        require(voters[msg.sender].isRegistered, "Voter not registered");

        decayManager.refreshDecay(msg.sender);
        voters[msg.sender].baseVotingPower = newBaseVotingPower;
    }

    function getCurrentVotingPower(address voter) public view returns (uint256) {
        Voter memory voterData = voters[voter];
        require(voterData.isRegistered, "Voter not registered");

        return decayManager.getVotingPower(voter, voterData.baseVotingPower);
    }

    function createProposal() external returns (uint256) {
        proposalCounter++;
        return proposalCounter;
    }

    function vote(uint256 proposalId) external {
        require(voters[msg.sender].isRegistered, "Not a registered voter");
        require(!hasVoted[proposalId][msg.sender], "Already voted on this proposal");

        uint256 votingPower = getCurrentVotingPower(msg.sender);
        proposalVotes[proposalId] += votingPower;
        hasVoted[proposalId][msg.sender] = true;

        decayManager.refreshDecay(msg.sender);

        emit Voted(msg.sender, proposalId, votingPower);
    }

    function delegate(address to) external {
        require(voters[msg.sender].isRegistered, "Not a registered voter");
        require(voters[to].isRegistered, "Delegate is not a registered voter");

        decayManager.delegate(msg.sender, to);
    }

    function undelegate() external {
        require(voters[msg.sender].isRegistered, "Not a registered voter");
        decayManager.undelegate(msg.sender);
    }

    function setDecayRate(uint256 newRate) external {
        require(voters[msg.sender].isRegistered, "Not a registered voter");
        decayManager.setDecayRate(msg.sender, newRate);
    }

    function refreshDecay() external {
        require(voters[msg.sender].isRegistered, "Not a registered voter");
        decayManager.refreshDecay(msg.sender);
    }

    function setDecayFreeWindow(uint256 window) external {
        require(voters[msg.sender].isRegistered, "Not a registered voter");
        decayManager.setDecayFreeWindow(msg.sender, window);
    }
}
