// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ISummerGovernor} from "../interfaces/ISummerGovernor.sol";
import {MessagingFee, OApp, Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {GovernorTimelockControl, TimelockController} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {Governor, GovernorVotes, IVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorVotesQuorumFraction} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {IERC6372} from "@openzeppelin/contracts/interfaces/IERC6372.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {VotingDecayManager} from "@summerfi/voting-decay/src/VotingDecayManager.sol";

/*
 * @title SummerGovernor
 * @dev This contract implements the governance mechanism for the Summer protocol.
 * It extends various OpenZeppelin governance modules and includes custom functionality
 * such as whitelisting and voting decay.
 *
 * TODO: Fully integrate voting decay once cross-chain messaging is tested
 * see https://github.com/OasisDEX/summer-earn-protocol/blob/0b6b338ef4ccb8efa209b9cf6226b3669917f0d2/packages/voting-decay/test/ExampleGovernor.sol#L76
 */
contract SummerGovernor is
    ISummerGovernor,
    GovernorTimelockControl,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotesQuorumFraction,
    VotingDecayManager,
    OApp
{
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MIN_PROPOSAL_THRESHOLD = 1000e18; // 1,000 Tokens
    uint256 public constant MAX_PROPOSAL_THRESHOLD = 100000e18; // 100,000 Tokens
    uint32 public immutable proposalChainId;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /*
     * @dev Configuration structure for the governor
     * @param whitelistAccountExpirations Mapping of account addresses to their whitelist expiration timestamps
     * @param whitelistGuardian Address of the account with special privileges for managing the whitelist
     */
    struct GovernorConfig {
        mapping(address => uint256) whitelistAccountExpirations;
        address whitelistGuardian;
    }

    GovernorConfig public config;

    mapping(uint32 chainId => address trustedRemote) public trustedRemotes;

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyProposalChain() {
        if (block.chainid != proposalChainId) {
            revert SummerGovernorInvalidChain(block.chainid, proposalChainId);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

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
            params.initialDecayFunction,
            address(this)
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

        _setWhitelistGuardian(params.initialWhitelistGuardian);
        proposalChainId = params.proposalChainId;
    }

    /*//////////////////////////////////////////////////////////////
                        CROSS-CHAIN MESSAGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISummerGovernor
    function sendProposalToTargetChain(
        uint32 _dstEid,
        address[] memory _dstTargets,
        uint256[] memory _dstValues,
        bytes[] memory _dstCalldatas,
        bytes32 _dstDescriptionHash,
        bytes calldata _options
    ) external onlyGovernance {
        _sendProposalToTargetChain(
            _dstEid,
            _dstTargets,
            _dstValues,
            _dstCalldatas,
            _dstDescriptionHash,
            _options
        );
    }

    /**
     * @dev Internal function to send a proposal to another chain.
     * @param _dstEid The destination endpoint ID.
     * @param _dstTargets The target addresses for the proposal.
     * @param _dstValues The values for the proposal.
     * @param _dstCalldatas The calldata for the proposal.
     * @param _dstDescriptionHash The description hash for the proposal.
     * @param _options Message execution options.
     */
    function _sendProposalToTargetChain(
        uint32 _dstEid,
        address[] memory _dstTargets,
        uint256[] memory _dstValues,
        bytes[] memory _dstCalldatas,
        bytes32 _dstDescriptionHash,
        bytes calldata _options
    ) internal {
        uint256 dstProposalId = hashProposal(
            _dstTargets,
            _dstValues,
            _dstCalldatas,
            _dstDescriptionHash
        );

        bytes memory payload = abi.encode(
            dstProposalId,
            _dstTargets,
            _dstValues,
            _dstCalldatas,
            _dstDescriptionHash
        );

        MessagingFee memory fee = _quote(_dstEid, payload, _options, false);

        _lzSend(
            _dstEid,
            payload,
            _options,
            MessagingFee(fee.nativeFee + 100000, 0),
            payable(address(this))
        );

        emit ProposalSentCrossChain(dstProposalId, _dstEid);
    }

    // Receive function to allow the contract to receive ETH from LayerZero
    receive() external payable override {}

    /**
     * @dev Receives a proposal from another chain and executes it.
     * @param _origin The origin of the message.
     * @param // _guid The global packet identifier.
     * @param payload The encoded message payload.
     * @param // executor_ The Executor address.
     * @param // _extraData Arbitrary data appended by the Executor.
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32,
        bytes calldata payload,
        address,
        bytes calldata
    ) internal override {
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 descriptionHash
        ) = abi.decode(
                payload,
                (uint256, address[], uint256[], bytes[], bytes32)
            );

        emit ProposalReceivedCrossChain(proposalId, _origin.srcEid);

        address trustedRemote = trustedRemotes[_origin.srcEid];
        address originSender = address(uint160(uint256(_origin.sender)));

        if (originSender != trustedRemote) {
            revert SummerGovernorInvalidSender(originSender);
        }

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

    /*//////////////////////////////////////////////////////////////
                            GOVERNANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISummerGovernor
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    )
        public
        override(Governor, ISummerGovernor)
        onlyProposalChain
        returns (uint256)
    {
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
        _updateDecayFactor(proposer);
        return _propose(targets, values, calldatas, description, proposer);
    }

    /// @inheritdoc ISummerGovernor
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        public
        payable
        override(Governor, ISummerGovernor)
        onlyProposalChain
        returns (uint256)
    {
        return super.execute(targets, values, calldatas, descriptionHash);
    }

    /// @inheritdoc ISummerGovernor
    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        public
        override(Governor, ISummerGovernor)
        onlyProposalChain
        returns (uint256)
    {
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
        _updateDecayFactor(proposer);
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    /*//////////////////////////////////////////////////////////////
                        WHITELIST MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISummerGovernor
    function isWhitelisted(
        address account
    ) public view override returns (bool) {
        return (config.whitelistAccountExpirations[account] > block.timestamp);
    }

    /// @inheritdoc ISummerGovernor
    function setWhitelistAccountExpiration(
        address account,
        uint256 expiration
    ) external override onlyGovernance {
        config.whitelistAccountExpirations[account] = expiration;
        emit WhitelistAccountExpirationSet(account, expiration);
    }

    /// @inheritdoc ISummerGovernor
    function setWhitelistGuardian(
        address _whitelistGuardian
    ) external override onlyGovernance {
        _setWhitelistGuardian(_whitelistGuardian);
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISummerGovernor
    function getWhitelistAccountExpiration(
        address account
    ) public view returns (uint256) {
        return config.whitelistAccountExpirations[account];
    }

    /// @inheritdoc ISummerGovernor
    function getWhitelistGuardian() public view returns (address) {
        return config.whitelistGuardian;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Internal function to pay the native fee for LayerZero messaging.
     * @param _nativeFee The amount of native tokens to pay for the fee.
     * @return nativeFee The amount of native tokens to pay for the fee.
     */

    function _payNative(
        uint256 _nativeFee
    ) internal view override returns (uint256 nativeFee) {
        if (address(this).balance < _nativeFee) {
            revert NotEnoughNative(address(this).balance);
        }
        return _nativeFee;
    }

    function _setWhitelistGuardian(address _whitelistGuardian) internal {
        if (_whitelistGuardian == address(0)) {
            revert SummerGovernorInvalidWhitelistGuardian(_whitelistGuardian);
        }
        config.whitelistGuardian = _whitelistGuardian;
        emit WhitelistGuardianSet(_whitelistGuardian);
    }

    function _getDelegateTo(
        address account
    ) internal view override returns (address) {
        return token().delegates(account);
    }

    /*//////////////////////////////////////////////////////////////
                            OVERRIDE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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

    /// @inheritdoc ISummerGovernor
    function setTrustedRemote(
        uint32 _chainId,
        address _trustedRemote
    ) external virtual onlyGovernance {
        if (_trustedRemote == address(0)) {
            revert SummerGovernorInvalidTrustedRemote(_trustedRemote);
        }
        trustedRemotes[_chainId] = _trustedRemote;
        emit TrustedRemoteSet(_chainId, _trustedRemote);
    }
}
