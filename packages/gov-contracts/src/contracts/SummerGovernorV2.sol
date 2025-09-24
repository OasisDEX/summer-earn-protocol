// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISummerGovernorV2} from "../interfaces/ISummerGovernorV2.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {IERC6372} from "@openzeppelin/contracts/interfaces/IERC6372.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {MessagingFee, OApp, Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

import {Governor, GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {GovernorTimelockControl} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {GovernorVotesQuorumFraction} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*
 * @title SummerGovernorV2
 * @dev Governance V2 with hub-and-satellite architecture. Voting happens on the hub with xSUMR; finalized proposals
 *      can be sent cross-chain to satellites via LayerZero for queuing and timed execution. Guardianship and proposal
 *      thresholds are enforced; ETH receive is hardened to only accept funds from LayerZero endpoint or timelock.
 */
contract SummerGovernorV2 is
    ISummerGovernorV2,
    GovernorTimelockControl,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotesQuorumFraction,
    OApp
{
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MIN_PROPOSAL_THRESHOLD = 1000e18; // 1,000 Tokens
    uint256 public constant MAX_PROPOSAL_THRESHOLD = 100000e18; // 100,000 Tokens
    uint32 public immutable HUB_CHAIN_ID;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public immutable ACCESS_MANAGER;

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
        if (block.chainid != HUB_CHAIN_ID) {
            revert SummerGovernorNotHubChain(block.chainid, HUB_CHAIN_ID);
        }
        _;
    }

    /**
     * @dev Modifier to restrict certain functions to only be called on satellite chains (non-hub chains).
     * This ensures that certain operations can only happen on spoke chains that receive and execute
     * proposals from the hub chain.
     */
    modifier onlySatelliteChain() {
        if (block.chainid == HUB_CHAIN_ID) {
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
        Governor("SummerGovernorV2")
        GovernorSettings(
            params.votingDelay,
            params.votingPeriod,
            params.proposalThreshold
        )
        GovernorVotes(params.token)
        GovernorVotesQuorumFraction(params.quorumFraction)
        GovernorTimelockControl(params.timelock)
        OApp(params.endpoint, address(params.initialOwner))
        Ownable(address(params.initialOwner))
    {
        ACCESS_MANAGER = params.accessManager;
        _validateProposalThreshold(params.proposalThreshold);
        HUB_CHAIN_ID = params.hubChainId;
    }

    /*//////////////////////////////////////////////////////////////
                        CROSS-CHAIN MESSAGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISummerGovernorV2
    function sendProposalToTargetChain(
        uint32 _dstEid,
        address[] memory _dstTargets,
        uint256[] memory _dstValues,
        bytes[] memory _dstCalldatas,
        bytes32 _dstDescriptionHash,
        bytes calldata _options
    ) external onlyGovernance onlyHubChain {
        // Restrict cross-chain dispatch to governance flow and hub chain
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
     * @notice Encodes and sends a proposal to a target chain via LayerZero.
     * @dev Computes `dstProposalId = hashProposal(targets, values, calldatas, descriptionHash)` on the destination chain.
     *      Quotes messaging fees and sends using native token. Emits `ProposalSentCrossChain`.
     *      Hub-only and governance-only.
     * @param _dstEid Destination LayerZero endpoint ID
     * @param _dstTargets Target addresses on destination chain
     * @param _dstValues ETH values for each call
     * @param _dstCalldatas Calldata payloads for each call
     * @param _dstDescriptionHash EIP-712 compatible description hash
     * @param _options LayerZero executor options
     */
    function _sendProposalToTargetChain(
        uint32 _dstEid,
        address[] memory _dstTargets,
        uint256[] memory _dstValues,
        bytes[] memory _dstCalldatas,
        bytes32 _dstDescriptionHash,
        bytes calldata _options
    ) internal {
        // Compute proposalId as it will be known on the destination chain
        uint256 dstProposalId = hashProposal(
            _dstTargets,
            _dstValues,
            _dstCalldatas,
            _dstDescriptionHash
        );

        // Prepare payload for LayerZero transport
        bytes memory payload = abi.encode(
            dstProposalId,
            _dstTargets,
            _dstValues,
            _dstCalldatas,
            _dstDescriptionHash
        );

        // Quote and pay native execution fee in the contract's native balance
        MessagingFee memory fee = _quote(_dstEid, payload, _options, false);

        _lzSend(
            _dstEid,
            payload,
            _options,
            MessagingFee(fee.nativeFee, 0),
            payable(address(this))
        );

        emit ProposalSentCrossChain(dstProposalId, _dstEid);
    }

    /**
     * @dev Receive function to allow the contract to receive ETH from LayerZero
     * @dev Accepts ETH only from LayerZero endpoint or the timelock executor.
     * @dev Prevents accidental or malicious direct funding by other addresses.
     */
    receive() external payable override {
        // Allow deposits from LayerZero endpoint or timelock
        if (msg.sender != address(endpoint) && msg.sender != timelock()) {
            revert GovernorDisabledDeposit();
        }
    }

    /**
     * @notice Queues a received cross-chain proposal into the local timelock.
     * @dev Satellite-only. Returns proposalId and emits `ProposalQueued` with eta.
     * @param proposalId Proposal identifier (must match destination chain hash)
     * @param targets Target addresses for queued operations
     * @param values ETH values for queued operations
     * @param calldatas Calldata for queued operations
     * @param descriptionHash Description hash
     */
    function _queueCrossChainProposal(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal onlySatelliteChain returns (uint256) {
        // Satellite-only queueing of received operations into the local timelock controller
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
     * @notice LayerZero receive hook: decodes cross-chain proposal and queues it locally.
     * @dev Emits `ProposalReceivedCrossChain`. Trust boundary is the LayerZero endpoint configuration.
     * @param _origin Origin metadata (contains srcEid)
     * @param payload ABI-encoded (proposalId, targets[], values[], calldatas[], descriptionHash)
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32,
        bytes calldata payload,
        address,
        bytes calldata
    ) internal override {
        // Decode the cross-chain proposal payload
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

        // Queue operations for later execution per local timelock settings
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

    /// @inheritdoc ISummerGovernorV2
    function castVote(
        uint256 proposalId,
        uint8 support
    )
        public
        override(ISummerGovernorV2, Governor)
        onlyHubChain
        returns (uint256)
    {
        // Vote is hub-only; OZ Governor handles voting power checks via token snapshots
        address voter = _msgSender();
        return _castVote(proposalId, voter, support, "");
    }

    /// @inheritdoc ISummerGovernorV2
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    )
        public
        override(Governor, ISummerGovernorV2)
        onlyHubChain
        returns (uint256)
    {
        // Enforce proposer threshold, with guardian override via access manager
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

    /// @inheritdoc ISummerGovernorV2
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        public
        payable
        override(Governor, ISummerGovernorV2)
        onlyHubChain
        returns (uint256)
    {
        // Timelock-controlled execution path from OZ GovernorTimelockControl
        return super.execute(targets, values, calldatas, descriptionHash);
    }

    /// @inheritdoc ISummerGovernorV2
    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        public
        override(Governor, ISummerGovernorV2)
        onlyHubChain
        returns (uint256)
    {
        // Anyone may cancel if proposer is below threshold; guardians may have extra cancellation powers
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

    /// @inheritdoc ISummerGovernorV2
    function isActiveGuardian(address account) public view returns (bool) {
        // Delegate guardian status to the shared ProtocolAccessManager
        return IProtocolAccessManager(ACCESS_MANAGER).isActiveGuardian(account);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Pays LayerZero native execution fee.
     * @dev Reverts if contract native balance is insufficient. Caller must ensure funding.
     * @param _nativeFee Quoted native fee amount
     * @return nativeFee Echoed native fee amount
     */
    function _payNative(
        uint256 _nativeFee
    ) internal view override returns (uint256 nativeFee) {
        // Ensure the contract is pre-funded to cover executor fee; avoids trapping proposals mid-flight
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
