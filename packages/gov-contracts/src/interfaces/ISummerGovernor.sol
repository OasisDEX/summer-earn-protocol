// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/governance/IGovernor.sol";

/* @title ISummerGovernor Interface
 * @notice Interface for the SummerGovernor contract, extending OpenZeppelin's IGovernor
 */
interface ISummerGovernor is IGovernor {
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
}
