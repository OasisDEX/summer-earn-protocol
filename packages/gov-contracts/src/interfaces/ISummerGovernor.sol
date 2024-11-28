// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ISummerGovernorErrors} from "../errors/ISummerGovernorErrors.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/VotingDecayLibrary.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {ISummerToken} from "./ISummerToken.sol";

/**
 * @title ISummerGovernor Interface
 * @notice Interface for the SummerGovernor contract, extending OpenZeppelin's IGovernor
 */
interface ISummerGovernor is IGovernor, ISummerGovernorErrors {
    /*
     * @dev Struct for the governor parameters
     * @param token The token contract address
     * @param timelock The timelock controller contract address
     * @param votingDelay The voting delay in seconds
     * @param votingPeriod The voting period in seconds
     * @param proposalThreshold The proposal threshold in tokens
     * @param quorumFraction The quorum fraction in tokens
     * @param initialGuardian The initial whitelist guardian address
     * @param initialDecayFreeWindow The initial decay free window in seconds
     * @param initialDecayRate The initial decay rate
     * @param initialDecayFunction The initial decay function
     * @param endpoint The LayerZero endpoint address
     * @param hubChainId The hub chain ID
     * @param peerEndpointIds The peer endpoint IDs
     * @param peerAddresses The peer addresses
     */
    struct GovernorParams {
        ISummerToken token;
        TimelockController timelock;
        uint48 votingDelay;
        uint32 votingPeriod;
        uint256 proposalThreshold;
        uint256 quorumFraction;
        address initialGuardian;
        address endpoint;
        /// @dev On BASE chain (hubChainId == block.chainid), timelock owns the governor
        /// @dev On satellite chains, the governor owns itself
        uint32 hubChainId;
        uint32[] peerEndpointIds;
        address[] peerAddresses;
    }

    /**
     * @notice Emitted when a guardian's expiration is set
     * @param account The address of the guardian
     * @param expiration The timestamp when the guardian's whitelist status expires
     */
    event GuardianExpirationSet(address indexed account, uint256 expiration);

    /**
     * @notice Emitted when a new guardian is set
     * @param guardian The address of the new guardian
     */
    event GuardianSet(address indexed guardian);

    /**
     * @notice Emitted when a proposal is sent cross-chain
     * @param proposalId The ID of the proposal
     * @param dstEid The destination endpoint ID
     */
    event ProposalSentCrossChain(
        uint256 indexed proposalId,
        uint32 indexed dstEid
    );

    /**
     * @notice Emitted when a proposal is received cross-chain
     * @param proposalId The ID of the proposal
     * @param srcEid The source endpoint ID
     */
    event ProposalReceivedCrossChain(
        uint256 indexed proposalId,
        uint32 indexed srcEid
    );

    /**
     * @notice Casts a vote for a proposal
     * @param proposalId The ID of the proposal to vote on
     * @param support The support for the proposal (0 = against, 1 = for, 2 = abstain)
     * @return The proposal ID
     */
    function castVote(
        uint256 proposalId,
        uint8 support
    ) external returns (uint256);

    /**
     * @notice Proposes a new governance action
     * @param targets The addresses of the contracts to call
     * @param values The ETH values to send with the calls
     * @param calldatas The call data for each contract call
     * @param description A description of the proposal
     * @return proposalId The ID of the newly created proposal
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external override(IGovernor) returns (uint256 proposalId);

    /**
     * @notice Executes a proposal. Only callable on the proposal chain
     * @dev Crosschain proposals are executed using LayerZero. Check _lzReceive for the execution logic
     * @param targets The addresses of the contracts to call
     * @param values The ETH values to send with the calls
     * @param calldatas The call data for each contract call
     * @param descriptionHash The hash of the proposal description
     * @return proposalId The ID of the executed proposal
     */
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external payable override(IGovernor) returns (uint256 proposalId);

    /**
     * @notice Cancels an existing proposal
     * @param targets The addresses of the contracts to call
     * @param values The ETH values to send with the calls
     * @param calldatas The call data for each contract call
     * @param descriptionHash The hash of the proposal description
     * @return proposalId The ID of the cancelled proposal
     */
    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external override(IGovernor) returns (uint256 proposalId);

    /**
     * @notice Sends a proposal to another chain for execution
     * @param _dstEid The destination Endpoint ID
     * @param _dstTargets The target addresses for the proposal
     * @param _dstValues The values for the proposal
     * @param _dstCalldatas The calldata for the proposal
     * @param _dstDescriptionHash The description hash for the proposal
     * @param _options Message execution options
     */
    function sendProposalToTargetChain(
        uint32 _dstEid,
        address[] memory _dstTargets,
        uint256[] memory _dstValues,
        bytes[] memory _dstCalldatas,
        bytes32 _dstDescriptionHash,
        bytes calldata _options
    ) external;

    /**
     * @notice Checks if an account is whitelisted as a guardian
     * @dev Guardians have the ability to cancel both pending proposals and queued timelock proposals
     * @param account The address to check
     * @return bool True if the account is a guardian, false otherwise
     */
    function isGuardian(address account) external view returns (bool);

    /**
     * @notice Sets the expiration time for a whitelisted guardian account
     * @dev Guardians are trusted entities with the power to cancel malicious or erroneous proposals
     * @param account The address of the account to whitelist as guardian
     * @param expiration The timestamp when the account's guardian status expires
     */
    function setGuardian(address account, uint256 expiration) external;

    /**
     * @notice Gets the expiration time for a whitelisted guardian account
     * @dev After expiration, the account loses its guardian privileges to cancel proposals
     * @param account The address to check
     * @return The expiration timestamp for the account's guardian status
     */
    function getGuardianExpiration(
        address account
    ) external view returns (uint256);
}
