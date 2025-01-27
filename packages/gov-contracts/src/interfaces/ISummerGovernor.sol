// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISummerGovernorErrors} from "../errors/ISummerGovernorErrors.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/VotingDecayLibrary.sol";
import {SummerTimelockController} from "../contracts/SummerTimelockController.sol";
import {ISummerToken} from "./ISummerToken.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
/**
 * @title ISummerGovernor Interface
 * @notice Interface for the SummerGovernor contract, extending OpenZeppelin's IGovernor
 */
interface ISummerGovernor is IGovernor, ISummerGovernorErrors {
    /*
     * @dev Struct for the governor parameters
     * @param token The token contract address
     * @param timelock The timelock controller contract address
     * @param accessManager The access manager contract address
     * @param votingDelay The voting delay in seconds
     * @param votingPeriod The voting period in seconds
     * @param proposalThreshold The proposal threshold in tokens
     * @param quorumFraction The quorum fraction in tokens
     * @param endpoint The LayerZero endpoint address
     * @param hubChainId The hub chain ID
     * @param initialOwner The initial owner of the contract
     */
    struct GovernorParams {
        ISummerToken token;
        SummerTimelockController timelock;
        address accessManager;
        uint48 votingDelay;
        uint32 votingPeriod;
        uint256 proposalThreshold;
        uint256 quorumFraction;
        address endpoint;
        uint32 hubChainId;
        address initialOwner;
    }

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
     * @notice Checks if an account is an active guardian for governance purposes
     * @dev Delegates check to ProtocolAccessManager
     * @param account The address to check
     * @return bool True if the account is an active guardian, false otherwise
     */
    function isActiveGuardian(address account) external view returns (bool);
}
