// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/* @title ISummerGovernorErrors
 * @notice Interface defining custom errors for the SummerGovernor contract
 */
interface ISummerGovernorErrors {
    /* @notice Error thrown when the proposal threshold is invalid
     * @param proposalThreshold The invalid proposal threshold
     * @param minThreshold The minimum allowed threshold
     * @param maxThreshold The maximum allowed threshold
     */
    error SummerGovernorInvalidProposalThreshold(
        uint256 proposalThreshold,
        uint256 minThreshold,
        uint256 maxThreshold
    );

    /* @notice Error thrown when a proposer is below the threshold and not a guardian
     * @param proposer The address of the proposer
     * @param votes The number of votes the proposer has
     * @param threshold The required threshold for proposing
     */
    error SummerGovernorProposerBelowThresholdAndNotGuardian(
        address proposer,
        uint256 votes,
        uint256 threshold
    );

    /* @notice Error thrown when an unauthorized cancellation is attempted
     * @param caller The address attempting to cancel the proposal
     * @param proposer The address of the original proposer
     * @param votes The number of votes the proposer has
     * @param threshold The required threshold for proposing
     */
    error SummerGovernorUnauthorizedCancellation(
        address caller,
        address proposer,
        uint256 votes,
        uint256 threshold
    );

    /* @notice Error thrown when the trusted remote is invalid
     * @param trustedRemote The invalid trusted remote
     */
    error SummerGovernorInvalidTrustedRemote(address trustedRemote);

    /* @notice Error thrown when the chain id is invalid
     * @param chainId The invalid chain id
     * @param hubChainId The valid chain id
     */
    error SummerGovernorNotHubChain(uint256 chainId, uint256 hubChainId);

    /* @notice Error thrown when an attempt is made to execute on the hub chain
     */
    error SummerGovernorCannotExecuteOnHubChain();

    /* @notice Error thrown when the governor is not set
     */
    error GovernorNotSet();

    /* @notice Error thrown when the caller is not the rewards manager */
    error SummerGovernorInvalidCaller();

    /* @notice Error thrown when the peer arrays are invalid */
    error SummerGovernorInvalidPeerArrays();
}
