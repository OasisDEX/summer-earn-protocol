// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "../src/VotingDecayLibrary.sol";
import "../src/VotingDecayManager.sol";

/*
 * @title ExampleGovernance
 * @notice This contract demonstrates how to integrate VotingDecayManager into a governance system
 */
contract ExampleGovernance {
    VotingDecayManager public decayManager;

    /*
     * @dev Struct to store voter information
     * @param baseVotingPower The initial voting power of the voter
     * @param isRegistered Boolean indicating if the voter is registered
     */
    struct Voter {
        uint256 baseVotingPower;
        bool isRegistered;
    }

    mapping(address => Voter) public voters;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => uint256) public proposalVotes;

    uint256 public constant INITIAL_DECAY_RATE = 0.1e27; // 10% annual decay (using RAY)
    uint256 public constant INITIAL_DECAY_FREE_WINDOW = 30 days;
    uint256 public proposalCounter;

    event VoterRegistered(address indexed voter, uint256 baseVotingPower);
    event Voted(
        address indexed voter,
        uint256 indexed proposalId,
        uint256 votingPower
    );
    event ProposalCreated(uint256 indexed proposalId);

    /*
     * @notice Constructor that initializes the VotingDecayManager
     */
    constructor() {
        decayManager = new VotingDecayManager();
    }

    /*
     * @notice Register a new voter with a given base voting power
     * @param baseVotingPower The initial voting power of the voter
     */
    function registerVoter(uint256 baseVotingPower) external {
        require(!voters[msg.sender].isRegistered, "Voter already registered");
        voters[msg.sender] = Voter({
            baseVotingPower: baseVotingPower,
            isRegistered: true
        });
        decayManager.setDecayRate(msg.sender, INITIAL_DECAY_RATE);
        decayManager.setDecayFreeWindow(msg.sender, INITIAL_DECAY_FREE_WINDOW);
        emit VoterRegistered(msg.sender, baseVotingPower);
    }

    /*
     * @notice Update the base voting power of a registered voter
     * @param newBaseVotingPower The new base voting power
     */
    function updateVotingPower(uint256 newBaseVotingPower) external {
        require(voters[msg.sender].isRegistered, "Voter not registered");
        decayManager.resetDecay(msg.sender);
        voters[msg.sender].baseVotingPower = newBaseVotingPower;
    }

    /*
     * @notice Get the current voting power of a voter, considering decay and delegations
     * @param voter The address of the voter
     * @return The current aggregate voting power
     */
    function getAggregateVotingPower(
        address voter
    ) public view returns (uint256) {
        Voter memory voterData = voters[voter];
        require(voterData.isRegistered, "Voter not registered");

        uint256 aggregateBaseVotingPower = voterData.baseVotingPower;

        address[] memory delegators = decayManager.getDelegators(voter);
        for (uint256 i = 0; i < delegators.length; i++) {
            Voter memory delegator = voters[delegators[i]];
            if (delegator.isRegistered) {
                aggregateBaseVotingPower += delegator.baseVotingPower;
            }
        }

        return decayManager.getVotingPower(voter, aggregateBaseVotingPower);
    }

    /*
     * @notice Create a new proposal
     * @return The ID of the newly created proposal
     */
    function createProposal() external returns (uint256) {
        proposalCounter++;
        emit ProposalCreated(proposalCounter);
        return proposalCounter;
    }

    /*
     * @notice Vote on a proposal
     * @param proposalId The ID of the proposal to vote on
     */
    function vote(uint256 proposalId) external {
        require(voters[msg.sender].isRegistered, "Not a registered voter");
        require(
            !hasVoted[proposalId][msg.sender],
            "Already voted on this proposal"
        );
        uint256 votingPower = getAggregateVotingPower(msg.sender);
        proposalVotes[proposalId] += votingPower;
        hasVoted[proposalId][msg.sender] = true;
        decayManager.resetDecay(msg.sender);
        emit Voted(msg.sender, proposalId, votingPower);
    }

    /*
     * @notice Delegate voting power to another address
     * @param to The address to delegate to
     */
    function delegate(address to) external {
        require(voters[msg.sender].isRegistered, "Not a registered voter");
        require(voters[to].isRegistered, "Delegate is not a registered voter");
        decayManager.delegate(msg.sender, to);
    }

    /*
     * @notice Remove delegation of voting power
     */
    function undelegate() external {
        require(voters[msg.sender].isRegistered, "Not a registered voter");
        decayManager.undelegate(msg.sender);
    }

    /*
     * @notice Set a new decay rate for the caller
     * @param newRate The new decay rate to set
     */
    function setDecayRate(uint256 newRate) external {
        require(voters[msg.sender].isRegistered, "Not a registered voter");
        decayManager.setDecayRate(msg.sender, newRate);
    }

    /*
     * @notice Refresh the decay for the caller
     */
    function refreshDecay() external {
        require(voters[msg.sender].isRegistered, "Not a registered voter");
        decayManager.resetDecay(msg.sender);
    }

    /*
     * @notice Set a new decay-free window for the caller
     * @param window The new decay-free window duration
     */
    function setDecayFreeWindow(uint256 window) external {
        require(voters[msg.sender].isRegistered, "Not a registered voter");
        decayManager.setDecayFreeWindow(msg.sender, window);
    }

    /*
     * @notice Get the decay information for a voter
     * @param voter The address of the voter
     * @return The DecayInfo struct for the voter
     */
    function getDecayInfo(
        address voter
    ) external view returns (VotingDecayLibrary.DecayInfo memory) {
        require(voters[voter].isRegistered, "Voter not registered");
        return decayManager.getDecayInfo(voter);
    }
}
