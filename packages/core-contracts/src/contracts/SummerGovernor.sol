// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/*
 * @title SummerGovernor
 * @dev This contract implements a governance system with additional features such as
 * whitelisting, pausing, and custom proposal thresholds.
 * It extends various OpenZeppelin Governor contracts to provide a comprehensive
 * governance solution.
 */
contract SummerGovernor is
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl,
    Pausable
{
    /* @dev Minimum number of tokens required to create a proposal */
    uint256 public constant MIN_PROPOSAL_THRESHOLD = 1000e18; // 1,000 Tokens
    /* @dev Maximum number of tokens allowed for proposal threshold */
    uint256 public constant MAX_PROPOSAL_THRESHOLD = 100000e18; // 100,000 Tokens

    /* @dev Mapping to store expiration timestamps for whitelisted accounts */
    mapping(address => uint256) public whitelistAccountExpirations;
    /* @dev Address of the whitelist guardian who can cancel proposals */
    address public whitelistGuardian;

    /*
     * @dev Constructor to initialize the SummerGovernor contract
     * @param _token The ERC20Votes token used for governance
     * @param _timelock The TimelockController used for executing proposals
     * @param _votingDelay The delay before voting on a proposal may take place, once proposed, in blocks
     * @param _votingPeriod The period of voting for a proposal, in blocks
     * @param _proposalThreshold The number of votes required in order for a voter to become a proposer
     * @param _quorumFraction The fraction of total supply that should be present when voting on proposals
     */
    constructor(
        IVotes _token,
        TimelockController _timelock,
        uint48 _votingDelay,
        uint32 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorumFraction
    )
        Governor("SummerGovernor")
        GovernorSettings(_votingDelay, _votingPeriod, _proposalThreshold)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(_quorumFraction)
        GovernorTimelockControl(_timelock)
        Pausable()
    {
        require(
            _proposalThreshold >= MIN_PROPOSAL_THRESHOLD &&
                _proposalThreshold <= MAX_PROPOSAL_THRESHOLD,
            "SummerEarnGovernor: invalid proposal threshold"
        );
    }

    /* @dev Pauses the contract. Can only be called by governance. */
    function pause() public onlyGovernance {
        _pause();
    }

    /* @dev Unpauses the contract. Can only be called by governance. */
    function unpause() public onlyGovernance {
        _unpause();
    }

    /*
     * @dev Proposes a new governance action
     * @param targets The ordered list of target addresses for calls to be made
     * @param values The ordered list of values (i.e. msg.value) to be passed to the calls to be made
     * @param calldatas The ordered list of function signatures to be called
     * @param description A human readable description of the proposal
     * @return The ID of the newly created proposal
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override(Governor) returns (uint256) {
        address proposer = _msgSender();
        uint256 proposerVotes = getVotes(proposer, block.number - 1);

        if (proposerVotes < proposalThreshold() && !isWhitelisted(proposer)) {
            revert(
                "SummerEarnGovernor: proposer votes below proposal threshold and not whitelisted"
            );
        }

        return _propose(targets, values, calldatas, description, proposer);
    }

    /*
     * @dev Executes a successful proposal
     * @param targets The ordered list of target addresses for calls to be made
     * @param values The ordered list of values (i.e. msg.value) to be passed to the calls to be made
     * @param calldatas The ordered list of function signatures to be called
     * @param descriptionHash The hash of the proposal description
     * @return The ID of the executed proposal
     */
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public payable override(Governor) returns (uint256) {
        return super.execute(targets, values, calldatas, descriptionHash);
    }

    /*
     * @dev Cancels a proposal
     * @param targets The ordered list of target addresses for calls to be made
     * @param values The ordered list of values (i.e. msg.value) to be passed to the calls to be made
     * @param calldatas The ordered list of function signatures to be called
     * @param descriptionHash The hash of the proposal description
     * @return The ID of the canceled proposal
     */
    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public override(Governor) returns (uint256) {
        uint256 proposalId = hashProposal(
            targets,
            values,
            calldatas,
            descriptionHash
        );
        address proposer = proposalProposer(proposalId);
        require(
            _msgSender() == proposer ||
                getVotes(proposer, block.number - 1) < proposalThreshold() ||
                _msgSender() == whitelistGuardian,
            "SummerGovernor: only proposer, whitelisted proposer below threshold, or guardian"
        );
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    /* @dev Internal function to cancel a proposal */
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    /* @dev Returns the address of the executor (timelock) */
    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }

    /* @dev Returns the current proposal threshold */
    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    /* @dev Returns the state of a proposal */
    function state(
        uint256 proposalId
    )
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    /* @dev Checks if the contract supports an interface */
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(Governor) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /* @dev Checks if an account is whitelisted */
    function isWhitelisted(address account) public view returns (bool) {
        return (whitelistAccountExpirations[account] > block.timestamp);
    }

    /*
     * @dev Sets the expiration for a whitelisted account
     * @param account The address to whitelist
     * @param expiration The timestamp when the whitelist expires
     */
    function setWhitelistAccountExpiration(
        address account,
        uint256 expiration
    ) external onlyGovernance {
        whitelistAccountExpirations[account] = expiration;
        emit WhitelistAccountExpirationSet(account, expiration);
    }

    /*
     * @dev Sets the whitelist guardian
     * @param _whitelistGuardian The address of the new whitelist guardian
     */
    function setWhitelistGuardian(
        address _whitelistGuardian
    ) external onlyGovernance {
        whitelistGuardian = _whitelistGuardian;
        emit WhitelistGuardianSet(_whitelistGuardian);
    }

    /* @dev Event emitted when a whitelist account expiration is set */
    event WhitelistAccountExpirationSet(
        address indexed account,
        uint256 expiration
    );
    /* @dev Event emitted when the whitelist guardian is set */
    event WhitelistGuardianSet(address indexed newGuardian);

    /*
     * @dev Internal function to execute proposal operations
     * Overrides to resolve conflicts between Governor and GovernorTimelockControl
     */
    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        return
            GovernorTimelockControl._executeOperations(
                proposalId,
                targets,
                values,
                calldatas,
                descriptionHash
            );
    }

    /*
     * @dev Internal function to queue proposal operations
     * Overrides to resolve conflicts between Governor and GovernorTimelockControl
     */
    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        // Directly call the GovernorTimelockControl implementation
        return
            GovernorTimelockControl._queueOperations(
                proposalId,
                targets,
                values,
                calldatas,
                descriptionHash
            );
    }

    /* @dev Checks if a proposal needs queuing */
    function proposalNeedsQueuing(
        uint256 proposalId
    ) public view override(Governor, GovernorTimelockControl) returns (bool) {
        return super.proposalNeedsQueuing(proposalId);
    }
}
