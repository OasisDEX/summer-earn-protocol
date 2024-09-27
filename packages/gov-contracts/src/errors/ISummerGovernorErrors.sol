// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

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

    /* @notice Error thrown when a proposer is below the threshold and not whitelisted
     * @param proposer The address of the proposer
     * @param votes The number of votes the proposer has
     * @param threshold The required threshold for proposing
     */
    error SummerGovernorProposerBelowThresholdAndNotWhitelisted(
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

    /* @notice Error thrown when the whitelist guardian is not set
     * @param whitelistGuardian The address of the whitelist guardian
     */
    error SummerGovernorInvalidWhitelistGuardian(address whitelistGuardian);

    /* @notice Error thrown when the sender is invalid
     * @param originSender The invalid sender
     */
    error SummerGovernorInvalidSender(address originSender);

    /* @notice Error thrown when the message ID is invalid
     * @param messageId The invalid message ID
     * @param expectedMessageId The expected message ID
     */
    error SummerGovernorInvalidMessageId(
        bytes32 messageId,
        bytes32 expectedMessageId
    );

    /* @notice Error thrown when the trusted remote is invalid
     * @param trustedRemote The invalid trusted remote
     */
    error SummerGovernorInvalidTrustedRemote(address trustedRemote);
}
