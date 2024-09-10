// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "../src/VotingDecayLibrary.sol";
import "../src/VotingDecayManager.sol";

/**
 * @title ExampleGovernance
 * @dev A sample governance contract that implements voting power decay
 * This contract demonstrates how to integrate the VotingDecayManager into a governance system.
 * It allows voters to register, vote on proposals, delegate their voting power, and manages
 * the decay of voting power over time.
 */
contract ExampleGovernance {
    /// @notice The VotingDecayManager instance that handles voting power decay
    VotingDecayManager public decayManager;

    /**
     * @dev Struct to store voter information
     * @param baseValue The initial voting power of the voter
     * @param isRegistered Boolean indicating if the voter is registered
     */
    struct Voter {
        uint256 baseValue;
        bool isRegistered;
    }

    /// @notice Mapping of voter addresses to their Voter struct
    mapping(address => Voter) public voters;

    /// @notice Mapping to track whether a voter has voted on a specific proposal
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    /// @notice Mapping to store the total votes for each proposal
    mapping(uint256 => uint256) public proposalVotes;

    /// @notice Initial decay rate per second (approximately 10% per year)
    /// @dev Calculated as (0.1e18 / (365 * 24 * 60 * 60))
    uint256 internal constant INITIAL_DECAY_RATE_PER_SECOND = 3.1709792e9;

    /// @notice Initial decay-free window duration
    uint40 public constant INITIAL_DECAY_FREE_WINDOW = 30 days;

    /// @notice Counter for proposal IDs
    uint256 public proposalCounter;

    /// @notice Event emitted when a new voter is registered
    event VoterRegistered(address indexed voter, uint256 baseValue);

    /// @notice Event emitted when a vote is cast
    event Voted(
        address indexed voter,
        uint256 indexed proposalId,
        uint256 value
    );

    /// @notice Event emitted when a new proposal is created
    event ProposalCreated(uint256 indexed proposalId);

    /**
     * @dev Constructor that initializes the VotingDecayManager
     * Sets up the decay manager with initial parameters
     */
    constructor() {
        decayManager = new VotingDecayManager(
            INITIAL_DECAY_FREE_WINDOW,
            INITIAL_DECAY_RATE_PER_SECOND,
            VotingDecayLibrary.DecayFunction.Linear,
            address(this)
        );
    }

    /**
     * @notice Register a new voter with a given base voting power
     * @param baseValue The initial voting power of the voter
     */
    function registerVoter(uint256 baseValue) external {
        require(!voters[msg.sender].isRegistered, "Voter already registered");
        voters[msg.sender] = Voter({baseValue: baseValue, isRegistered: true});
        decayManager.initializeAccount(msg.sender);
        emit VoterRegistered(msg.sender, baseValue);
    }

    /**
     * @notice Update the base voting power of a registered voter
     * @param newBaseValue The new base voting power
     */
    function updateBaseValue(uint256 newBaseValue) external {
        require(voters[msg.sender].isRegistered, "Voter not registered");
        decayManager.updateDecay(msg.sender);
        voters[msg.sender].baseValue = newBaseValue;
    }

    /**
     * @notice Get the current voting power of a voter, considering decay and delegations
     * @param voter The address of the voter
     * @return The current aggregate voting power
     */
    function getAggregateValue(address voter) public view returns (uint256) {
        Voter memory voterData = voters[voter];
        require(voterData.isRegistered, "Voter not registered");

        uint256 aggregateBaseValue = voterData.baseValue;

        // Add the base values of all delegators
        address[] memory delegators = decayManager.getDelegators(voter);
        for (uint256 i = 0; i < delegators.length; i++) {
            Voter memory delegator = voters[delegators[i]];
            if (delegator.isRegistered) {
                aggregateBaseValue += delegator.baseValue;
            }
        }

        // Apply decay to the aggregate value
        return decayManager.getVotingPower(voter, aggregateBaseValue);
    }

    /**
     * @notice Create a new proposal
     * @return The ID of the newly created proposal
     */
    function createProposal() external returns (uint256) {
        proposalCounter++;
        emit ProposalCreated(proposalCounter);
        return proposalCounter;
    }

    /**
     * @notice Vote on a proposal
     * @param proposalId The ID of the proposal to vote on
     */
    function vote(uint256 proposalId) external {
        require(voters[msg.sender].isRegistered, "Not a registered voter");
        require(
            !hasVoted[proposalId][msg.sender],
            "Already voted on this proposal"
        );
        uint256 votingPower = getAggregateValue(msg.sender);
        proposalVotes[proposalId] += votingPower;
        hasVoted[proposalId][msg.sender] = true;
        decayManager.updateDecay(msg.sender);
        emit Voted(msg.sender, proposalId, votingPower);
    }

    /**
     * @notice Delegate voting power to another address
     * @param to The address to delegate to
     */
    function delegate(address to) external {
        require(voters[msg.sender].isRegistered, "Not a registered voter");
        require(voters[to].isRegistered, "Delegate is not a registered voter");
        decayManager.delegate(msg.sender, to);
    }

    /**
     * @notice Remove delegation of voting power
     */
    function undelegate() external {
        require(voters[msg.sender].isRegistered, "Not a registered voter");
        decayManager.undelegate(msg.sender);
    }

    /**
     * @notice Set a new decay rate
     * @param newRate The new decay rate to set (in units per second)
     */
    function setDecayRatePerSecond(uint256 newRate) external {
        decayManager.setDecayRatePerSecond(newRate);
    }

    /**
     * @notice Refresh the decay for the caller
     */
    function refreshDecay() external {
        require(voters[msg.sender].isRegistered, "Not a registered voter");
        decayManager.resetDecay(msg.sender);
    }

    /**
     * @notice Set a new decay-free window for the system
     * @param newWindow The new decay-free window duration
     */
    function setDecayFreeWindow(uint40 newWindow) external {
        decayManager.setDecayFreeWindow(newWindow);
    }

    /**
     * @notice Set a new decay function
     * @param newFunction The new decay function to use
     */
    function setDecayFunction(
        VotingDecayLibrary.DecayFunction newFunction
    ) external {
        decayManager.setDecayFunction(newFunction);
    }

    /**
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
