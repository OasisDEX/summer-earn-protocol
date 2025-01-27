// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISummerGovernor} from "../interfaces/ISummerGovernor.sol";
import {ISummerToken} from "../interfaces/ISummerToken.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {IERC6372} from "@openzeppelin/contracts/interfaces/IERC6372.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {MessagingFee, OApp, Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

import {Governor, GovernorVotes, IVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {GovernorTimelockControl, TimelockController} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {GovernorVotesQuorumFraction} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {DecayController} from "./DecayController.sol";

/*
 * @title SummerGovernor
 * @dev This contract implements the governance mechanism for the Summer protocol.
 * It extends various OpenZeppelin governance modules and includes custom functionality
 * such as whitelisting and voting decay.
 */
contract SummerGovernor is
    ISummerGovernor,
    GovernorTimelockControl,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotesQuorumFraction,
    DecayController,
    OApp
{
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MIN_PROPOSAL_THRESHOLD = 1000e18; // 1,000 Tokens
    uint256 public constant MAX_PROPOSAL_THRESHOLD = 100000e18; // 100,000 Tokens
    uint32 public immutable hubChainId;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public immutable accessManager;

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Modifier to restrict certain functions to only be called on the hub chain.
     * This ensures that governance actions like proposing, executing, and canceling can only happen
     * on the designated hub chain, while other chains act as spokes that can only receive and execute
     * proposals that have been approved on the hub.
     */
    modifier onlyHubChain() {
        if (block.chainid != hubChainId) {
            revert SummerGovernorNotHubChain(block.chainid, hubChainId);
        }
        _;
    }

    /**
     * @dev Modifier to restrict certain functions to only be called on satellite chains (non-hub chains).
     * This ensures that certain operations can only happen on spoke chains that receive and execute
     * proposals from the hub chain.
     */
    modifier onlySatelliteChain() {
        if (block.chainid == hubChainId) {
            revert SummerGovernorCannotExecuteOnHubChain();
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
        OApp(params.endpoint, address(params.timelock))
        DecayController(address(params.token))
        Ownable(address(params.initialOwner))
    {
        accessManager = params.accessManager;
        _setRewardsManager(
            address(ISummerToken(params.token).rewardsManager())
        );
        _validateProposalThreshold(params.proposalThreshold);
        hubChainId = params.hubChainId;
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
    ) external onlyGovernance onlyHubChain {
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
    receive() external payable override {
        // Allow deposits from LayerZero endpoint or timelock
        if (msg.sender != address(endpoint) && msg.sender != timelock()) {
            revert GovernorDisabledDeposit();
        }
    }

    /**
     * @dev Internal function to queue a proposal received from another chain.
     * @param proposalId The ID of the proposal to queue.
     * @param targets The target addresses for the proposal.
     * @param values The values for the proposal.
     * @param calldatas The calldata for the proposal.
     * @param descriptionHash The description hash for the proposal.
     */
    function _queueCrossChainProposal(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal onlySatelliteChain returns (uint256) {
        uint48 eta = _queueOperations(
            proposalId,
            targets,
            values,
            calldatas,
            descriptionHash
        );

        emit ProposalQueued(proposalId, uint256(eta));

        return proposalId;
    }

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

        _queueCrossChainProposal(
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
    function castVote(
        uint256 proposalId,
        uint8 support
    )
        public
        override(ISummerGovernor, Governor)
        updateDecay(_msgSender())
        onlyHubChain
        returns (uint256)
    {
        address voter = _msgSender();
        return _castVote(proposalId, voter, support, "");
    }

    /// @inheritdoc ISummerGovernor
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    )
        public
        override(Governor, ISummerGovernor)
        updateDecay(_msgSender())
        onlyHubChain
        returns (uint256)
    {
        address proposer = _msgSender();
        uint256 proposerVotes = getVotes(proposer, block.timestamp - 1);

        if (
            proposerVotes < proposalThreshold() && !isActiveGuardian(proposer)
        ) {
            revert SummerGovernorProposerBelowThresholdAndNotGuardian(
                proposer,
                proposerVotes,
                proposalThreshold()
            );
        }

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
        updateDecay(_msgSender())
        onlyHubChain
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
        updateDecay(_msgSender())
        onlyHubChain
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
            getVotes(proposer, block.timestamp - 1) >= proposalThreshold() &&
            !isActiveGuardian(_msgSender())
        ) {
            revert SummerGovernorUnauthorizedCancellation(
                _msgSender(),
                proposer,
                getVotes(proposer, block.timestamp - 1),
                proposalThreshold()
            );
        }

        return _cancel(targets, values, calldatas, descriptionHash);
    }

    /*//////////////////////////////////////////////////////////////
                        WHITELIST MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISummerGovernor
    function isActiveGuardian(address account) public view returns (bool) {
        return IProtocolAccessManager(accessManager).isActiveGuardian(account);
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

    /**
     * @dev Internal function to validate the proposal threshold
     * @param thresholdToValidate The threshold value to validate against min/max bounds
     */
    function _validateProposalThreshold(
        uint256 thresholdToValidate
    ) internal pure {
        if (
            thresholdToValidate < MIN_PROPOSAL_THRESHOLD ||
            thresholdToValidate > MAX_PROPOSAL_THRESHOLD
        ) {
            revert SummerGovernorInvalidProposalThreshold(
                thresholdToValidate,
                MIN_PROPOSAL_THRESHOLD,
                MAX_PROPOSAL_THRESHOLD
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                            OVERRIDE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Override of GovernorCountingSimple._countVote to use decayed voting power
     */
    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256,
        bytes memory params
    )
        internal
        virtual
        override(Governor, GovernorCountingSimple)
        returns (uint256)
    {
        uint256 decayedWeight = ISummerToken(address(token())).getVotes(
            account
        );

        return
            super._countVote(
                proposalId,
                account,
                support,
                decayedWeight,
                params
            );
    }

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
     * @return The current voting delay
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
     * @return The current voting period
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
