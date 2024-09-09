// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {IERC6372} from "@openzeppelin/contracts/interfaces/IERC6372.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import {ISummerGovernor} from "../interfaces/ISummerGovernor.sol";
import {ISummerGovernorErrors} from "../errors/ISummerGovernorErrors.sol";

contract SummerGovernor is
    ISummerGovernor,
    ISummerGovernorErrors,
    GovernorTimelockControl,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotesQuorumFraction,
    Pausable
{
    // ===============================================
    // Constants
    // ===============================================
    uint256 public constant MIN_PROPOSAL_THRESHOLD = 1000e18; // 1,000 Tokens
    uint256 public constant MAX_PROPOSAL_THRESHOLD = 100000e18; // 100,000 Tokens

    // ===============================================
    // State Variables
    // ===============================================
    struct GovernorConfig {
        mapping(address => uint256) whitelistAccountExpirations;
        address whitelistGuardian;
    }

    GovernorConfig public config;

    // ===============================================
    // Constructor
    // ===============================================
    struct GovernorParams {
        IVotes token;
        TimelockController timelock;
        uint48 votingDelay;
        uint32 votingPeriod;
        uint256 proposalThreshold;
        uint256 quorumFraction;
    }

    /**
     * @dev Constructor for the SummerGovernor contract.
     * @param params A struct containing all necessary parameters for initializing the governor.
     */
    constructor(
        GovernorParams memory params
    )
        Governor("SummerGovernor")
        GovernorSettings(
            params.votingDelay,
            params.votingPeriod,
            params.proposalThreshold
        )
        GovernorVotes(params.token)
        GovernorVotesQuorumFraction(params.quorumFraction)
        GovernorTimelockControl(params.timelock)
        Pausable()
    {
        if (
            params.proposalThreshold < MIN_PROPOSAL_THRESHOLD ||
            params.proposalThreshold > MAX_PROPOSAL_THRESHOLD
        ) {
            revert SummerGovernorInvalidProposalThreshold(
                params.proposalThreshold,
                MIN_PROPOSAL_THRESHOLD,
                MAX_PROPOSAL_THRESHOLD
            );
        }
    }

    // ===============================================
    // Core Governance Functions
    // ===============================================
    /**
     * @dev Pauses the governor contract. Can only be called by governance.
     */
    function pause() public override onlyGovernance {
        _pause();
    }

    /**
     * @dev Unpauses the governor contract. Can only be called by governance.
     */
    function unpause() public override onlyGovernance {
        _unpause();
    }

    /**
     * @dev Proposes a new governance action.
     * @param targets The addresses of the contracts to call.
     * @param values The ETH values to send with the calls.
     * @param calldatas The call data for each contract call.
     * @param description A description of the proposal.
     * @return The ID of the newly created proposal.
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override(Governor, IGovernor) returns (uint256) {
        address proposer = _msgSender();
        // Use block.number - 1 to get the proposer's voting power from the previous block.
        // This ensures we're using a finalized state and prevents potential same-block manipulations,
        // aligning with OpenZeppelin's recommended practice for governance contracts.
        uint256 proposerVotes = getVotes(proposer, block.number - 1);

        if (proposerVotes < proposalThreshold() && !isWhitelisted(proposer)) {
            revert SummerGovernorProposerBelowThresholdAndNotWhitelisted(
                proposer,
                proposerVotes,
                proposalThreshold()
            );
        }

        return _propose(targets, values, calldatas, description, proposer);
    }

    /**
     * @dev Cancels an existing proposal.
     * @param targets The addresses of the contracts to call.
     * @param values The ETH values to send with the calls.
     * @param calldatas The call data for each contract call.
     * @param descriptionHash The hash of the proposal description.
     * @return The ID of the cancelled proposal.
     */
    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public override(Governor, IGovernor) returns (uint256) {
        uint256 proposalId = hashProposal(
            targets,
            values,
            calldatas,
            descriptionHash
        );
        address proposer = proposalProposer(proposalId);
        if (
            _msgSender() != proposer &&
            getVotes(proposer, block.number - 1) >= proposalThreshold() &&
            _msgSender() != config.whitelistGuardian
        ) {
            revert SummerGovernorUnauthorizedCancellation(
                _msgSender(),
                proposer,
                getVotes(proposer, block.number - 1),
                proposalThreshold()
            );
        }
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    // ===============================================
    // Whitelist Management Functions
    // ===============================================
    /**
     * @dev Checks if an account is whitelisted.
     * @param account The address to check.
     * @return True if the account is whitelisted, false otherwise.
     */
    function isWhitelisted(
        address account
    ) public view override returns (bool) {
        return (config.whitelistAccountExpirations[account] > block.timestamp);
    }

    /**
     * @dev Sets the expiration time for a whitelisted account.
     * @param account The address to whitelist.
     * @param expiration The timestamp when the whitelist status expires.
     */
    function setWhitelistAccountExpiration(
        address account,
        uint256 expiration
    ) external override onlyGovernance {
        config.whitelistAccountExpirations[account] = expiration;
        emit WhitelistAccountExpirationSet(account, expiration);
    }

    /**
     * @dev Sets the whitelist guardian address.
     * @param _whitelistGuardian The new whitelist guardian address.
     */
    function setWhitelistGuardian(
        address _whitelistGuardian
    ) external override onlyGovernance {
        if (_whitelistGuardian == address(0)) {
            revert ISummerGovernorErrors.SummerGovernorInvalidWhitelistGuardian(
                _whitelistGuardian
            );
        }
        config.whitelistGuardian = _whitelistGuardian;
        emit WhitelistGuardianSet(_whitelistGuardian);
    }

    // ===============================================
    // Getter Functions
    // ===============================================
    /**
     * @dev Gets the expiration time for a whitelisted account.
     * @param account The address to check.
     * @return The expiration timestamp for the account's whitelist status.
     */
    function getWhitelistAccountExpiration(
        address account
    ) public view returns (uint256) {
        return config.whitelistAccountExpirations[account];
    }

    /**
     * @dev Gets the current whitelist guardian address.
     * @return The address of the current whitelist guardian.
     */
    function getWhitelistGuardian() public view returns (address) {
        return config.whitelistGuardian;
    }

    // ===============================================
    // Override Functions
    // ===============================================
    /**
     * @dev This section contains override functions that are necessary to resolve conflicts
     * between the various OpenZeppelin governance modules we're inheriting from.
     * These overrides ensure that the correct implementation is used for each function,
     * considering the specific requirements of our governance model (e.g., timelocking,
     * dynamic settings, etc.).
     */

    /**
     * @dev Internal function to cancel a proposal.
     * @param targets The addresses of the contracts to call.
     * @param values The ETH values to send with the calls.
     * @param calldatas The call data for each contract call.
     * @param descriptionHash The hash of the proposal description.
     * @return The ID of the cancelled proposal.
     */
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return
            GovernorTimelockControl._cancel(
                targets,
                values,
                calldatas,
                descriptionHash
            );
    }

    /**
     * @dev Returns the address of the executor (timelock).
     * @return The address of the executor.
     */
    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return GovernorTimelockControl._executor();
    }

    /**
     * @dev Returns the current proposal threshold.
     * @return The current proposal threshold.
     */
    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings, IGovernor)
        returns (uint256)
    {
        return GovernorSettings.proposalThreshold();
    }

    /**
     * @dev Returns the state of a proposal.
     * @param proposalId The ID of the proposal.
     * @return The current state of the proposal.
     */
    function state(
        uint256 proposalId
    )
        public
        view
        override(Governor, GovernorTimelockControl, IGovernor)
        returns (ProposalState)
    {
        return GovernorTimelockControl.state(proposalId);
    }

    /**
     * @dev Checks if the contract supports an interface.
     * @param interfaceId The interface identifier.
     * @return True if the contract supports the interface, false otherwise.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(Governor, IERC165) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Internal function to execute proposal operations.
     * @param proposalId The ID of the proposal.
     * @param targets The addresses of the contracts to call.
     * @param values The ETH values to send with the calls.
     * @param calldatas The call data for each contract call.
     * @param descriptionHash The hash of the proposal description.
     */
    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        GovernorTimelockControl._executeOperations(
            proposalId,
            targets,
            values,
            calldatas,
            descriptionHash
        );
    }

    /**
     * @dev Internal function to queue proposal operations.
     * @param proposalId The ID of the proposal.
     * @param targets The addresses of the contracts to call.
     * @param values The ETH values to send with the calls.
     * @param calldatas The call data for each contract call.
     * @param descriptionHash The hash of the proposal description.
     * @return The timestamp at which the proposal will be executable.
     */
    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return
            GovernorTimelockControl._queueOperations(
                proposalId,
                targets,
                values,
                calldatas,
                descriptionHash
            );
    }

    /**
     * @dev Checks if a proposal needs queuing.
     * @param proposalId The ID of the proposal.
     * @return True if the proposal needs queuing, false otherwise.
     */
    function proposalNeedsQueuing(
        uint256 proposalId
    )
        public
        view
        override(Governor, GovernorTimelockControl, IGovernor)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    /**
     * @dev Returns the clock mode used by the contract.
     * @return A string describing the clock mode.
     */
    function CLOCK_MODE()
        public
        view
        override(Governor, GovernorVotes, IERC6372)
        returns (string memory)
    {
        return super.CLOCK_MODE();
    }

    /**
     * @dev Returns the current clock value used by the contract.
     * @return The current clock value.
     */
    function clock()
        public
        view
        override(Governor, GovernorVotes, IERC6372)
        returns (uint48)
    {
        return super.clock();
    }

    /**
     * @dev Calculates the quorum for a specific timepoint.
     * @param timepoint The timepoint to calculate the quorum for.
     * @return The quorum value.
     */
    function quorum(
        uint256 timepoint
    )
        public
        view
        override(Governor, GovernorVotesQuorumFraction, IGovernor)
        returns (uint256)
    {
        return super.quorum(timepoint);
    }

    /**
     * @dev Returns the current voting delay.
     * @return The current voting delay in blocks.
     */
    function votingDelay()
        public
        view
        override(Governor, GovernorSettings, IGovernor)
        returns (uint256)
    {
        return super.votingDelay();
    }

    /**
     * @dev Returns the current voting period.
     * @return The current voting period in blocks.
     */
    function votingPeriod()
        public
        view
        override(Governor, GovernorSettings, IGovernor)
        returns (uint256)
    {
        return super.votingPeriod();
    }
}
