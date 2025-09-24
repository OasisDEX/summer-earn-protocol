// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISummerGovernorErrors} from "../errors/ISummerGovernorErrors.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {SummerTimelockController} from "../contracts/SummerTimelockController.sol";
import {ISummerToken} from "./ISummerToken.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {IVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
/**
 * @title ISummerGovernorV2 Interface
 * @notice Governance V2 hub-and-satellite interface extending OZ Governor. Voting occurs on the hub with xSUMR.
 *         Finalized proposals may be distributed cross-chain to satellites via LayerZero and queued for execution.
 * @dev Key behaviors:
 *      - Hub-only: propose, castVote, execute, cancel. Satellite-only: receive and queue cross-chain proposals.
 *      - ETH receive is restricted to LayerZero endpoint or timelock executors to avoid accidental funding.
 *      - Guardians (via ProtocolAccessManager) can propose below threshold and have scoped cancellation privileges.
 */
interface ISummerGovernorV2 is IGovernor, ISummerGovernorErrors {
    /*
     * @dev Struct for the governor parameters
     * @param token The token contract address
     * @param timelock The timelock controller contract address
     * @param accessManager The access manager contract address
     * @param votingDelay The voting delay in seconds
     * @param votingPeriod The voting period in seconds
     * @param proposalThreshold The proposal threshold in tokens
     * @param quorumFraction The quorum fraction
     * @param endpoint The LayerZero endpoint address
     * @param hubChainId The hub chain ID
     * @param initialOwner The initial owner of the contract
     */
    /**
     * @notice Deployment parameters for the governor.
     * @dev `proposalThreshold` is validated within [MIN_PROPOSAL_THRESHOLD; MAX_PROPOSAL_THRESHOLD].
     */
    struct GovernorParams {
        IVotes token;
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
     * @notice Emitted when a proposal is sent cross-chain to a destination endpoint.
     * @param proposalId Proposal ID on the destination chain (hash of destination data)
     * @param dstEid Destination LayerZero Endpoint ID
     */
    event ProposalSentCrossChain(
        uint256 indexed proposalId,
        uint32 indexed dstEid
    );

    /**
     * @notice Emitted when a cross-chain proposal is received via LayerZero.
     * @param proposalId Proposal ID computed from destination payload
     * @param srcEid Source LayerZero Endpoint ID
     */
    event ProposalReceivedCrossChain(
        uint256 indexed proposalId,
        uint32 indexed srcEid
    );

    /**
     * @notice Casts a vote for a proposal on the hub chain.
     * @param proposalId The proposal to vote on
     * @param support 0 = Against, 1 = For, 2 = Abstain
     * @return proposalId The proposal ID (echo)
     */
    function castVote(
        uint256 proposalId,
        uint8 support
    ) external returns (uint256);

    /**
     * @notice Creates a new proposal. Hub-only.
     * @param targets Call targets
     * @param values ETH values for each call
     * @param calldatas Calldata payloads
     * @param description Human-readable description
     * @return proposalId New proposal ID
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external override(IGovernor) returns (uint256 proposalId);

    /**
     * @notice Executes a successful proposal from the hub chain. Timelock-enforced.
     * @param targets Call targets
     * @param values ETH values
     * @param calldatas Calldata payloads
     * @param descriptionHash EIP-712 description hash
     * @return proposalId Executed proposal ID
     */
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external payable override(IGovernor) returns (uint256 proposalId);

    /**
     * @notice Cancels a proposal. Hub-only. Guardians have scoped privileges.
     * @param targets Call targets
     * @param values ETH values
     * @param calldatas Calldata payloads
     * @param descriptionHash EIP-712 description hash
     * @return proposalId Cancelled proposal ID
     */
    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external override(IGovernor) returns (uint256 proposalId);

    /**
     * @notice Sends a finalized proposal to a satellite for queuing and execution via LayerZero.
     * @param _dstEid Destination Endpoint ID
     * @param _dstTargets Targets for destination chain
     * @param _dstValues ETH values for destination chain
     * @param _dstCalldatas Calldata payloads for destination chain
     * @param _dstDescriptionHash EIP-712 description hash for destination chain
     * @param _options LayerZero executor options
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
     * @notice Returns whether an account is an active guardian according to the ProtocolAccessManager.
     * @param account Address to query
     * @return isGuardian True if the account is an active guardian
     */
    function isActiveGuardian(
        address account
    ) external view returns (bool isGuardian);
}
