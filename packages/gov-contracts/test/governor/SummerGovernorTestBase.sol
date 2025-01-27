// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Origin, SummerGovernor} from "../../src/contracts/SummerGovernor.sol";
import {ISummerGovernorErrors} from "../../src/errors/ISummerGovernorErrors.sol";
import {SummerTokenTestBase} from "../token/SummerTokenTestBase.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {IOAppSetPeer, TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {ISummerGovernor} from "../../src/interfaces/ISummerGovernor.sol";

contract SummerGovernorTestBase is SummerTokenTestBase, ISummerGovernorErrors {
    using OptionsBuilder for bytes;

    ExposedSummerGovernor public governorA;
    ExposedSummerGovernor public governorB;

    uint48 public constant VOTING_DELAY = 1 days;
    uint32 public constant VOTING_PERIOD = 1 weeks;
    uint256 public constant PROPOSAL_THRESHOLD = 100000e18;
    uint256 public constant QUORUM_FRACTION = 4;

    address public alice = address(0x111);
    address public bob = address(0x112);
    address public charlie = address(0x113);
    address public david = address(0x114);
    address public guardian = address(0x115);

    function setUp() public virtual override {
        initializeTokenTests();

        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
        vm.label(david, "David");

        vm.label(address(aSummerToken), "chain a token");
        vm.label(address(bSummerToken), "chain b token");

        SummerGovernor.GovernorParams memory paramsA = ISummerGovernor
            .GovernorParams({
                token: aSummerToken,
                timelock: timelockA,
                accessManager: address(accessManagerA),
                votingDelay: VOTING_DELAY,
                votingPeriod: VOTING_PERIOD,
                proposalThreshold: PROPOSAL_THRESHOLD,
                quorumFraction: QUORUM_FRACTION,
                endpoint: lzEndpointA,
                hubChainId: 31337,
                initialOwner: address(timelockA)
            });
        SummerGovernor.GovernorParams memory paramsB = ISummerGovernor
            .GovernorParams({
                token: bSummerToken,
                timelock: timelockB,
                accessManager: address(accessManagerB),
                votingDelay: VOTING_DELAY,
                votingPeriod: VOTING_PERIOD,
                proposalThreshold: PROPOSAL_THRESHOLD,
                quorumFraction: QUORUM_FRACTION,
                endpoint: lzEndpointB,
                hubChainId: 31337,
                initialOwner: address(timelockB)
            });
        governorA = new ExposedSummerGovernor(paramsA);
        governorB = new ExposedSummerGovernor(paramsB);

        vm.prank(address(timelockA));
        accessManagerA.grantDecayControllerRole(address(governorA));

        vm.prank(address(timelockB));
        accessManagerB.grantDecayControllerRole(address(governorB));

        vm.label(address(governorA), "SummerGovernor");
        vm.label(address(governorB), "SummerGovernor");

        vm.label(address(timelockA), "Timelock A");
        vm.label(address(timelockB), "Timelock B");

        vm.prank(owner);
        enableTransfers();
        changeTokensOwnership(address(timelockA), address(timelockB));

        timelockA.grantRole(timelockA.PROPOSER_ROLE(), address(governorA));
        timelockA.grantRole(timelockA.CANCELLER_ROLE(), address(governorA));
        timelockB.grantRole(timelockB.PROPOSER_ROLE(), address(governorB));
        timelockB.grantRole(timelockB.CANCELLER_ROLE(), address(governorB));

        // Wire the governors (if needed)
        address[] memory governors = new address[](2);
        governors[0] = address(governorA);
        governors[1] = address(governorB);

        IOAppSetPeer aOApp = IOAppSetPeer(address(governorA));
        IOAppSetPeer bOApp = IOAppSetPeer(address(governorB));

        // Connect governorA to governorB
        // vm.prank(address(governorA));
        uint32 bEid_ = (bOApp.endpoint()).eid();
        vm.prank(address(timelockA));
        aOApp.setPeer(bEid_, addressToBytes32(address(bOApp)));

        // Connect governorB to governorA
        // vm.prank(address(governorB));
        uint32 aEid_ = (aOApp.endpoint()).eid();
        vm.prank(address(timelockB));
        bOApp.setPeer(aEid_, addressToBytes32(address(aOApp)));
    }

    /*
     * @dev Creates a proposal for testing purposes.
     * @return proposalId The ID of the created proposal.
     * @return descriptionHash The hash of the proposal description.
     */
    function createProposal() internal returns (uint256, bytes32) {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams(address(aSummerToken));

        // Add a unique identifier to the description to ensure unique proposals
        description = string(
            abi.encodePacked(description, " - ", block.number)
        );

        uint256 proposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        return (proposalId, hashDescription(description));
    }

    /*
     * @dev Creates parameters for a proposal.
     * @return targets The target addresses for the proposal.
     * @return values The values to be sent with the proposal.
     * @return calldatas The function call data for the proposal.
     * @return description The description of the proposal.
     */
    function createProposalParams(
        address tokenAddress
    )
        internal
        view
        returns (
            address[] memory,
            uint256[] memory,
            bytes[] memory,
            string memory
        )
    {
        address[] memory targets = new address[](1);
        targets[0] = tokenAddress;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            bob,
            100
        );
        string memory description = "Transfer 100 tokens to Bob";

        return (targets, values, calldatas, description);
    }

    function createAndExecuteProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) internal {
        // Give Alice enough tokens to meet proposal threshold
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        // Create proposal
        vm.prank(alice);
        uint256 proposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        // Give Alice enough tokens to meet quorum
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.quorum(block.timestamp - 1));
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);

        advanceTimeForVotingDelay();

        // Vote on proposal
        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        advanceTimeForVotingPeriod();

        // Queue and execute the proposal
        governorA.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        advanceTimeForTimelockMinDelay();

        governorA.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );
    }

    /*
     * @dev Hashes the description of a proposal.
     * @param description The description to hash.
     * @return The keccak256 hash of the description.
     */
    function hashDescription(
        string memory description
    ) internal pure returns (bytes32) {
        return keccak256(bytes(description));
    }

    // For immediate operations (propose, vote, etc)
    function advanceTimeAndBlock() internal {
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);
    }

    function advanceTimeForPeriod(uint256 extraTime) internal {
        vm.warp(block.timestamp + extraTime);
        vm.roll(block.number + 1);
    }

    function advanceTimeForTimelockMinDelay() internal {
        vm.warp(block.timestamp + timelockA.getMinDelay() + 1);
        vm.roll(block.number + 1);
    }

    function advanceTimeForVotingPeriod() internal {
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + 1);
    }

    function advanceTimeForVotingDelay() internal {
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + 1);
    }
}

contract ExposedSummerGovernor is SummerGovernor {
    constructor(GovernorParams memory params) SummerGovernor(params) {}

    function exposedSendProposalToTargetChain(
        uint32 _dstEid,
        address[] memory _dstTargets,
        uint256[] memory _dstValues,
        bytes[] memory _dstCalldatas,
        bytes32 _dstDescriptionHash,
        bytes calldata _options
    ) public {
        _sendProposalToTargetChain(
            _dstEid,
            _dstTargets,
            _dstValues,
            _dstCalldatas,
            _dstDescriptionHash,
            _options
        );
    }

    // Test skipper function
    function test() public {}

    function forceUpdateDecay(address account) public updateDecay(account) {}
}
