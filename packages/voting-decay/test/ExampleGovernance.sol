// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "../src/VotingDecayLibrary.sol";
import "../src/VotingDecayManager.sol";

contract ExampleGovernance {
    VotingDecayManager public decayManager;

    struct Voter {
        uint256 baseValue;
        bool isRegistered;
    }

    mapping(address => Voter) public voters;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => uint256) public proposalVotes;

    // Define decay rate per second
    // 0.1e18 per year is approximately 3.168808781402895e9 per second
    // (0.1e18 / (365 * 24 * 60 * 60))
    uint256 internal constant INITIAL_DECAY_RATE_PER_SECOND = 3.1709792e9; // ~10% per year
    uint40 public constant INITIAL_DECAY_FREE_WINDOW = 30 days;
    uint256 public proposalCounter;

    event VoterRegistered(address indexed voter, uint256 baseValue);
    event Voted(address indexed voter, uint256 indexed proposalId, uint256 value);
    event ProposalCreated(uint256 indexed proposalId);

    constructor() {
        decayManager = new VotingDecayManager(
            INITIAL_DECAY_FREE_WINDOW,
            INITIAL_DECAY_RATE_PER_SECOND,
            VotingDecayLibrary.DecayFunction.Linear,
            address(this)
        );
    }

    function registerVoter(uint256 baseValue) external {
        require(!voters[msg.sender].isRegistered, "Voter already registered");
        voters[msg.sender] = Voter({baseValue: baseValue, isRegistered: true});
        decayManager.initializeAccount(msg.sender);
        emit VoterRegistered(msg.sender, baseValue);
    }

    function updateBaseValue(uint256 newBaseValue) external {
        require(voters[msg.sender].isRegistered, "Voter not registered");
        decayManager.updateDecay(msg.sender);
        voters[msg.sender].baseValue = newBaseValue;
    }

    function getAggregateValue(address voter) public view returns (uint256) {
        Voter memory voterData = voters[voter];
        require(voterData.isRegistered, "Voter not registered");

        uint256 aggregateBaseValue = voterData.baseValue;

        address[] memory delegators = decayManager.getDelegators(voter);
        for (uint256 i = 0; i < delegators.length; i++) {
            Voter memory delegator = voters[delegators[i]];
            if (delegator.isRegistered) {
                aggregateBaseValue += delegator.baseValue;
            }
        }

        return decayManager.getVotingPower(voter, aggregateBaseValue);
    }

    function createProposal() external returns (uint256) {
        proposalCounter++;
        emit ProposalCreated(proposalCounter);
        return proposalCounter;
    }

    function vote(uint256 proposalId) external {
        require(voters[msg.sender].isRegistered, "Not a registered voter");
        require(!hasVoted[proposalId][msg.sender], "Already voted on this proposal");
        uint256 votingPower = getAggregateValue(msg.sender);
        proposalVotes[proposalId] += votingPower;
        hasVoted[proposalId][msg.sender] = true;
        decayManager.updateDecay(msg.sender);
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

    function setDecayRatePerSecond(uint256 newRate) external {
        decayManager.setDecayRatePerSecond(newRate);
    }

    function refreshDecay() external {
        require(voters[msg.sender].isRegistered, "Not a registered voter");
        decayManager.resetDecay(msg.sender);
    }

    function setDecayFreeWindow(uint40 newWindow) external {
        decayManager.setDecayFreeWindow(newWindow);
    }

    function setDecayFunction(VotingDecayLibrary.DecayFunction newFunction) external {
        decayManager.setDecayFunction(newFunction);
    }

    function getDecayInfo(address voter) external view returns (VotingDecayLibrary.DecayInfo memory) {
        require(voters[voter].isRegistered, "Voter not registered");
        return decayManager.getDecayInfo(voter);
    }
}
