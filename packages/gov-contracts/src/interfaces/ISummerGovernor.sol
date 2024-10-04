// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "@openzeppelin/contracts/governance/IGovernor.sol";
import {ISummerGovernorErrors} from "../errors/ISummerGovernorErrors.sol";
/* @title ISummerGovernor Interface
 * @notice Interface for the SummerGovernor contract, extending OpenZeppelin's IGovernor
 */
interface ISummerGovernor is IGovernor, ISummerGovernorErrors {
    /* @notice Emitted when a whitelisted account's expiration is set
     * @param account The address of the whitelisted account
     * @param expiration The timestamp when the account's whitelist status expires
     */
    event WhitelistAccountExpirationSet(
        address indexed account,
        uint256 expiration
    );

    /* @notice Emitted when a new whitelist guardian is set
     * @param newGuardian The address of the new whitelist guardian
     */
    event WhitelistGuardianSet(address indexed newGuardian);

    /* @notice Emitted when a proposal is sent cross-chain
     * @param proposalId The ID of the proposal
     * @param dstEid The destination endpoint ID
     */
    event ProposalSentCrossChain(
        uint256 indexed proposalId,
        uint32 indexed dstEid
    );

    /* @notice Emitted when a proposal is received cross-chain
     * @param proposalId The ID of the proposal
     * @param srcEid The source endpoint ID
     */
    event ProposalReceivedCrossChain(
        uint256 indexed proposalId,
        uint32 indexed srcEid
    );

    /**
     * @dev Proposes a new governance action.
     * @param targets The addresses of the contracts to call.
     * @param values The ETH values to send with the calls.
     * @param calldatas The call data for each contract call.
     * @param description A description of the proposal.
     * @return proposalId The ID of the newly created proposal.
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external override(IGovernor) returns (uint256 proposalId);

    /**
     * @dev Executes a proposal. Only callable on the proposal chain.
     * Crosschain proposals are executed using LayerZero. Check _lzReceive for the execution logic.
     * @param targets The addresses of the contracts to call.
     * @param values The ETH values to send with the calls.
     * @param calldatas The call data for each contract call.
     * @param descriptionHash The hash of the proposal description.
     * @return proposalId The ID of the executed proposal.
     */
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external payable override(IGovernor) returns (uint256 proposalId);

    /**
     * @dev Cancels an existing proposal.
     * @param targets The addresses of the contracts to call.
     * @param values The ETH values to send with the calls.
     * @param calldatas The call data for each contract call.
     * @param descriptionHash The hash of the proposal description.
     * @return proposalId The ID of the cancelled proposal.
     */
    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external override(IGovernor) returns (uint256 proposalId);

    /**
     * @dev Sends a proposal to another chain for execution.
     * @param _dstEid The destination Endpoint ID.
     * @param _dstTargets The target addresses for the proposal.
     * @param _dstValues The values for the proposal.
     * @param _dstCalldatas The calldata for the proposal.
     * @param _dstDescriptionHash The description hash for the proposal.
     * @param _options Message execution options.
     */
    function sendProposalToTargetChain(
        uint32 _dstEid,
        address[] memory _dstTargets,
        uint256[] memory _dstValues,
        bytes[] memory _dstCalldatas,
        bytes32 _dstDescriptionHash,
        bytes calldata _options
    ) external;

    /* @notice Checks if an account is whitelisted
     * @param account The address to check
     * @return bool True if the account is whitelisted, false otherwise
     */
    function isWhitelisted(address account) external view returns (bool);

    /* @notice Sets the expiration time for a whitelisted account
     * @param account The address of the account to whitelist
     * @param expiration The timestamp when the account's whitelist status expires
     */
    function setWhitelistAccountExpiration(
        address account,
        uint256 expiration
    ) external;

    /* @notice Sets a new whitelist guardian
     * @param _whitelistGuardian The address of the new whitelist guardian
     */
    function setWhitelistGuardian(address _whitelistGuardian) external;

    /* @notice Sets a trusted remote for a specific chain ID
     * @param _chainId The chain ID to set the trusted remote for
     * @param _trustedRemote The address of the trusted remote on the specified chain
     */
    function setTrustedRemote(uint32 _chainId, address _trustedRemote) external;

    /**
     * @dev Gets the expiration time for a whitelisted account.
     * @param account The address to check.
     * @return The expiration timestamp for the account's whitelist status.
     */
    function getWhitelistAccountExpiration(
        address account
    ) external view returns (uint256);

    /**
     * @dev Gets the current whitelist guardian address.
     * @return The address of the current whitelist guardian.
     */
    function getWhitelistGuardian() external view returns (address);
}
