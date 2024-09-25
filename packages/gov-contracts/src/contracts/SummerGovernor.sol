// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ISummerGovernorErrors} from "../errors/ISummerGovernorErrors.sol";
import {ISummerGovernor} from "../interfaces/ISummerGovernor.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {GovernorTimelockControl, TimelockController} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {Governor, GovernorVotes, IVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorVotesQuorumFraction} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {IERC6372} from "@openzeppelin/contracts/interfaces/IERC6372.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/src/VotingDecayLibrary.sol";
import {VotingDecayManager} from "@summerfi/voting-decay/src/VotingDecayManager.sol";
import {OApp, Origin, MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*
 * @title SummerGovernor
 * @dev This contract implements the governance mechanism for the Summer protocol.
 * It extends various OpenZeppelin governance modules and includes custom functionality
 * such as whitelisting and voting decay.
 */
contract SummerGovernor is
    ISummerGovernor,
    ISummerGovernorErrors,
    GovernorTimelockControl,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotesQuorumFraction,
    VotingDecayManager,
    OApp
{
    // ===============================================
    // Constants
    // ===============================================
    uint256 public constant MIN_PROPOSAL_THRESHOLD = 1000e18; // 1,000 Tokens
    uint256 public constant MAX_PROPOSAL_THRESHOLD = 100000e18; // 100,000 Tokens

    // ===============================================
    // State Variables
    // ===============================================
    /*
     * @dev Configuration structure for the governor
     * @param whitelistAccountExpirations Mapping of account addresses to their whitelist expiration timestamps
     * @param whitelistGuardian Address of the account with special privileges for managing the whitelist
     */
    struct GovernorConfig {
        mapping(address => uint256) whitelistAccountExpirations;
        address whitelistGuardian;
    }

    struct CrossChainProposal {
        uint32 dstEid;
        address[] dstTargets;
        uint256[] dstValues;
        bytes[] dstCalldatas;
        bytes32 dstDescriptionHash;
        bool sent;
    }

    GovernorConfig public config;

    mapping(uint256 proposalId => CrossChainProposal)
        public queuedCrossChainProposals;

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
        address initialWhitelistGuardian;
        uint40 initialDecayFreeWindow;
        uint256 initialDecayRate;
        VotingDecayLibrary.DecayFunction initialDecayFunction;
        address endpoint;
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
        VotingDecayManager(
            params.initialDecayFreeWindow,
            params.initialDecayRate,
            params.initialDecayFunction
        )
        OApp(params.endpoint, address(this))
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

        // Initialize the whitelistGuardian with the provided address
        _setWhitelistGuardian(params.initialWhitelistGuardian);
    }

    // ===============================================
    // Cross-Chain Messaging Functions
    // ===============================================
    /**
     * @dev Queues a proposal for execution on another chain.
     * @param _dstEid The destination endpoint ID.
     * @param _dstTargets The target addresses for the proposal.
     * @param _dstValues The values for the proposal.
     * @param _dstCalldatas The calldata for the proposal.
     */
    function queueCrossChainProposal(
        uint32 _dstEid,
        address[] memory _dstTargets,
        uint256[] memory _dstValues,
        bytes[] memory _dstCalldatas,
        bytes32 _dstDescriptionHash
    ) public onlyGovernance {
        uint256 dstProposalId = hashProposal(
            _dstTargets,
            _dstValues,
            _dstCalldatas,
            _dstDescriptionHash
        );
        queuedCrossChainProposals[dstProposalId] = CrossChainProposal(
            _dstEid,
            _dstTargets,
            _dstValues,
            _dstCalldatas,
            _dstDescriptionHash,
            false
        );

        emit ProposalQueuedCrossChain(dstProposalId, _dstEid);
    }

    /**
     * @dev Sends a proposal to another chain for execution.
     * @param _srcTargets The target addresses for the proposal.
     * @param _srcValues The values for the proposal.
     * @param _srcCalldatas The calldata for the proposal.
     * @param _srcDescriptionHash The hash of the proposal description.
     * @param _options Message execution options.
     */
    function sendCrossChainProposal(
        address[] memory _srcTargets,
        uint256[] memory _srcValues,
        bytes[] memory _srcCalldatas,
        bytes32 _srcDescriptionHash,
        bytes calldata _options
    ) external payable {
        if (_srcCalldatas.length == 0) {
            revert SummerGovernorInvalidCrossChainProposalData();
        }

        (
            uint32 dstEid,
            address[] memory dstTargets,
            uint256[] memory dstValues,
            bytes[] memory dstCalldatas,
            bytes32 dstDescriptionHash
        ) = _decodeCrossChainProposalData(_srcCalldatas[0]);

        if (dstEid == 0) {
            revert SummerGovernorInvalidCrossChainProposalData();
        }

        // Generate source proposalId
        uint256 srcProposalId = hashProposal(
            _srcTargets,
            _srcValues,
            _srcCalldatas,
            _srcDescriptionHash
        );

        // Check if the source proposal has been executed on the source chain
        if (state(srcProposalId) != ProposalState.Executed) {
            revert SummerGovernorOnlyExecutedProposalsCanBeSentCrossChain(
                srcProposalId
            );
        }

        uint256 dstProposalId = hashProposal(
            dstTargets,
            dstValues,
            dstCalldatas,
            dstDescriptionHash
        );

        // Check if the proposal has been queued cross-chain
        if (queuedCrossChainProposals[dstProposalId].dstEid == 0) {
            revert SummerGovernorProposalNotQueuedCrossChain(dstProposalId);
        }

        if (queuedCrossChainProposals[dstProposalId].sent) {
            revert SummerGovernorProposalAlreadySentCrossChain(dstProposalId);
        }

        // Used it get CrossChainProposal from mapping
        CrossChainProposal memory dstProposal = queuedCrossChainProposals[
            dstProposalId
        ];

        bytes memory payload = _generateCrossChainPayload(
            srcProposalId,
            dstProposal,
            _srcDescriptionHash
        );

        queuedCrossChainProposals[dstProposalId].sent = true;

        _lzSend(
            dstProposal.dstEid,
            payload,
            _options,
            MessagingFee(msg.value, 0),
            // Refund to the governor contract because
            // we refund the full msg.value to the sender anyway
            payable(address(this))
        );

        if (msg.value > 0) {
            (bool success, ) = payable(msg.sender).call{value: msg.value}("");
            if (!success) {
                revert SummerGovernorRefundFailed(msg.sender, msg.value);
            }
        }

        emit ProposalSentCrossChain(
            srcProposalId,
            dstProposalId,
            dstProposal.dstEid
        );
    }

    function _decodeCrossChainProposalData(
        bytes memory data
    )
        internal
        pure
        returns (
            uint32 dstEid,
            address[] memory dstTargets,
            uint256[] memory dstValues,
            bytes[] memory dstCalldatas,
            bytes32 descriptionHash
        )
    {
        return
            abi.decode(data, (uint32, address[], uint256[], bytes[], bytes32));
    }

    /**
     * @dev Quotes the fee for sending a cross-chain message.
     * Is required to call prior to calling sendCrossChainProposal
     * To determine the correct msg.value to send
     * @param _srcTargets The target addresses for the proposal.
     * @param _srcValues The values for the proposal.
     * @param _srcCalldatas The calldata for the proposal.
     * @param _srcDescriptionHash The hash of the proposal description.
     * @param _options The message execution options.
     * @return fee The messaging fee structure containing native and LZ token fees.
     */
    function quote(
        address[] memory _srcTargets,
        uint256[] memory _srcValues,
        bytes[] memory _srcCalldatas,
        bytes32 _srcDescriptionHash,
        bytes memory _options
    ) public view returns (MessagingFee memory fee) {
        uint256 proposalId = hashProposal(
            _srcTargets,
            _srcValues,
            _srcCalldatas,
            _srcDescriptionHash
        );

        CrossChainProposal memory proposal = queuedCrossChainProposals[
            proposalId
        ];

        bytes memory payload = _generateCrossChainPayload(
            proposalId,
            proposal,
            _srcDescriptionHash
        );

        return _quote(proposal.dstEid, payload, _options, false);
    }

    /**
     * @dev Generates the payload for cross-chain messaging.
     * @param _proposalId The ID of the proposal.
     * @param _proposal The CrossChainProposal struct.
     * @param _srcDescriptionHash The hash of the proposal description.
     * @return payload The generated payload.
     */
    function _generateCrossChainPayload(
        uint256 _proposalId,
        CrossChainProposal memory _proposal,
        bytes32 _srcDescriptionHash
    ) internal view returns (bytes memory payload) {
        bytes32 messageId = _generateMessageId(
            block.chainid,
            address(this),
            _proposalId,
            _proposal.dstTargets,
            _proposal.dstValues,
            _proposal.dstCalldatas,
            _srcDescriptionHash
        );

        return
            abi.encode(
                messageId,
                _proposalId,
                _proposal.dstTargets,
                _proposal.dstValues,
                _proposal.dstCalldatas,
                _srcDescriptionHash
            );
    }

    /**
     * @dev Receives a proposal from another chain and executes it.
     * @param _origin The origin of the message.
     * @param /// _guid The global packet identifier.
     * @param payload The encoded message payload.
     * @param /// executor_ The Executor address.
     * @param ///_extraData Arbitrary data appended by the Executor.
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32,
        bytes calldata payload,
        address,
        bytes calldata
    ) internal override {
        (
            bytes32 messageId,
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 descriptionHash
        ) = abi.decode(
                payload,
                (bytes32, uint256, address[], uint256[], bytes[], bytes32)
            );

        emit ProposalReceivedCrossChain(proposalId, _origin.srcEid, messageId);

        // Verify the message origin
        // We rely on CREATE2 to ensure that the contract address is deterministic across chains
        // This allows us to use the contract's own address as a trusted sender
        address originSender = address(uint160(uint256(_origin.sender)));
        if (originSender != address(this)) {
            revert SummerGovernorInvalidSender(originSender);
        }

        // Note: Both checks above rely on the fact that this contract is deployed using CREATE2
        // with the same salt and init code on all chains, ensuring its address is consistent
        // across the network. This allows for secure cross-chain communication without additional
        // trusted parties or complex verification schemes.

        // Verify the messageId
        bytes32 expectedMessageId = _generateMessageId(
            _origin.srcEid,
            originSender,
            proposalId,
            targets,
            values,
            calldatas,
            descriptionHash
        );

        if (messageId != expectedMessageId) {
            revert SummerGovernorInvalidMessageId(messageId, expectedMessageId);
        }

        // Execute the proposal
        _executeCrossChainProposal(
            proposalId,
            targets,
            values,
            calldatas,
            descriptionHash
        );
    }

    /**
     * @dev Internal function to execute a proposal.
     * @dev It's important to note that the proposalId will marry up with the source proposalId
     * but the targets, values and calldatas will be the nested proposal that's executed on the target chain
     * @param proposalId The ID of the proposal to execute.
     * @param targets The target addresses for the proposal.
     * @param values The values for the proposal.
     * @param calldatas The calldata for the proposal.
     * @param descriptionHash The description hash for the proposal.
     */
    function _executeCrossChainProposal(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal returns (uint256) {
        _executeCrossChainOperations(
            proposalId,
            targets,
            values,
            calldatas,
            descriptionHash
        );

        emit ProposalExecuted(proposalId);

        return proposalId;
    }

    // /**
    //  * @dev Quotes the fee for sending a cross-chain message.
    //  * @param _dstEid The destination endpoint ID.
    //  * @param _message The message payload being sent.
    //  * @param _options The message execution options.
    //  * @param _payInLzToken Boolean indicating whether to pay in LZ token.
    //  * @return nativeFee The native fee for the message.
    //  * @return lzTokenFee The LZ token fee for the message.
    //  */
    // function _quote(
    //     uint32 _dstEid,
    //     bytes memory _message,
    //     bytes memory _options,
    //     bool _payInLzToken
    // ) internal view returns (uint256 nativeFee, uint256 lzTokenFee) {
    //     MessagingFee memory fee = _quote(
    //         _dstEid,
    //         _message,
    //         _options,
    //         _payInLzToken
    //     );
    //     return (fee.nativeFee, fee.lzTokenFee);
    // }

    /**
     * @dev Internal function to execute cross-chain proposal operations.
     * @param proposalId The ID of the proposal.
     * @param targets The addresses of the contracts to call on the destination chain.
     * @param values The ETH values to send with the calls on the destination chain.
     * @param calldatas The call data for each contract call on the destination chain.
     * @param descriptionHash The hash of the proposal description.
     *
     * This function is used for executing proposals that have been received from another chain.
     * It bypasses the timelock and directly executes the operations using the base Governor's
     * _executeOperations function. This is necessary because the proposal has already been
     * executed on the source chain and we want to avoid double-queueing.
     */
    function _executeCrossChainOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal {
        Governor._executeOperations(
            proposalId,
            targets,
            values,
            calldatas,
            descriptionHash
        );
    }

    /**
     * @dev Generates a unique message ID for cross-chain proposals.
     * @param srcChainId The source chain ID.
     * @param srcAddress The source contract address.
     * @param proposalId The ID of the proposal.
     * @param targets The target addresses for the proposal.
     * @param values The values for the proposal.
     * @param calldatas The calldata for the proposal.
     * @param descriptionHash The description hash for the proposal.
     * @return A unique bytes32 message ID.
     */
    function _generateMessageId(
        uint256 srcChainId,
        address srcAddress,
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    srcChainId,
                    srcAddress,
                    proposalId,
                    targets,
                    values,
                    calldatas,
                    descriptionHash
                )
            );
    }

    // ===============================================
    // Existing Functions
    // ===============================================
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
        _setWhitelistGuardian(_whitelistGuardian);
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

    /*
     * @dev Overrides the internal cancellation function to use the timelocked version
     * @param targets The addresses of the contracts to call
     * @param values The ETH values to send with the calls
     * @param calldatas The call data for each contract call
     * @param descriptionHash The hash of the proposal description
     * @return The ID of the cancelled proposal
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

    /*
     * @dev Internal function to set the whitelist guardian
     * @param _whitelistGuardian The address of the new whitelist guardian
     */
    function _setWhitelistGuardian(address _whitelistGuardian) internal {
        if (_whitelistGuardian == address(0)) {
            revert ISummerGovernorErrors.SummerGovernorInvalidWhitelistGuardian(
                _whitelistGuardian
            );
        }
        config.whitelistGuardian = _whitelistGuardian;
        emit WhitelistGuardianSet(_whitelistGuardian);
    }

    /*
     * @dev Internal function to get the delegate of an account
     * @param account The address of the account to check
     * @return The address of the delegate for the given account
     */
    function _getDelegateTo(
        address account
    ) internal view override returns (address) {
        return token().delegates(account);
    }
}
