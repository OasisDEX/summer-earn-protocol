// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {ISummerGovernorErrors} from "../errors/ISummerGovernorErrors.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/src/VotingDecayLibrary.sol";
import {IVotingDecayManager} from "@summerfi/voting-decay/src/IVotingDecayManager.sol";
import {IVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";

/**
 * @title ISummerGovernor Interface
 * @notice Interface for the SummerGovernor contract, extending OpenZeppelin's IGovernor
 */
interface ISummerGovernor is
    IGovernor,
    IVotingDecayManager,
    ISummerGovernorErrors
{
    /*
     * @dev Struct for the governor parameters
     * @param token The token contract address
     * @param timelock The timelock controller contract address
     * @param votingDelay The voting delay in seconds
     * @param votingPeriod The voting period in seconds
     * @param proposalThreshold The proposal threshold in tokens
     * @param quorumFraction The quorum fraction in tokens
     * @param initialWhitelistGuardian The initial whitelist guardian address
     * @param initialDecayFreeWindow The initial decay free window in seconds
     * @param initialDecayRate The initial decay rate
     * @param initialDecayFunction The initial decay function
     * @param endpoint The LayerZero endpoint address
     * @param proposalChainId The proposal chain ID
     */
    struct GovernorParams {
        IVotes token;
        TimelockController timelock;
        uint48 votingDelay;
        uint32 votingPeriod;
        uint256 proposalThreshold;
        uint256 quorumFraction;
        address initialWhitelistGuardian;
        uint40 initialDecayFreeWindow;
        uint256 initialDecayRate;
        VotingDecayLibrary.DecayFunction initialDecayFunction;
        address endpoint;
        uint32 proposalChainId;
    }

    /**
     * @notice Emitted when a whitelisted account's expiration is set
     * @param account The address of the whitelisted account
     * @param expiration The timestamp when the account's whitelist status expires
     */
    event WhitelistAccountExpirationSet(
        address indexed account,
        uint256 expiration
    );

    /**
     * @notice Emitted when a new whitelist guardian is set
     * @param newGuardian The address of the new whitelist guardian
     */
    event WhitelistGuardianSet(address indexed newGuardian);

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
     * @notice Emitted when a trusted remote is set for a chain
     * @param chainId The chain ID for which the trusted remote is set
     * @param trustedRemote The address of the trusted remote on the specified chain
     */
    event TrustedRemoteSet(uint32 indexed chainId, address trustedRemote);

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
     * @notice Checks if an account is whitelisted
     * @param account The address to check
     * @return bool True if the account is whitelisted, false otherwise
     */
    function isWhitelisted(address account) external view returns (bool);

    /**
     * @notice Sets the expiration time for a whitelisted account
     * @param account The address of the account to whitelist
     * @param expiration The timestamp when the account's whitelist status expires
     */
    function setWhitelistAccountExpiration(
        address account,
        uint256 expiration
    ) external;

    /**
     * @notice Sets a new whitelist guardian
     * @param _whitelistGuardian The address of the new whitelist guardian
     */
    function setWhitelistGuardian(address _whitelistGuardian) external;

    /**
     * @notice Sets a trusted remote for a specific chain ID
     * @param _chainId The chain ID to set the trusted remote for
     * @param _trustedRemote The address of the trusted remote on the specified chain
     */
    function setTrustedRemote(uint32 _chainId, address _trustedRemote) external;

    /**
     * @notice Gets the expiration time for a whitelisted account
     * @param account The address to check
     * @return The expiration timestamp for the account's whitelist status
     */
    function getWhitelistAccountExpiration(
        address account
    ) external view returns (uint256);

    /**
     * @notice Gets the current whitelist guardian address
     * @return The address of the current whitelist guardian
     */
    function getWhitelistGuardian() external view returns (address);

    /**
     * @notice Updates the decay factor for an account
     * @param account The address of the account to update the decay factor for
     */
    function updateDecayFactor(address account) external;
}
