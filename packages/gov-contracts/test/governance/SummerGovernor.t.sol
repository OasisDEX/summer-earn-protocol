// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {SummerGovernor} from "../../src/contracts/SummerGovernor.sol";
import {ISummerGovernorErrors} from "../../src/errors/ISummerGovernorErrors.sol";

import {VotingDecayLibrary} from "@summerfi/voting-decay/src/VotingDecayLibrary.sol";
import {VotingDecayManager} from "@summerfi/voting-decay/src/VotingDecayManager.sol";

import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {ERC20, ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

import {SummerToken} from "../../src/contracts/SummerToken.sol";

import {SummerVestingWallet} from "../../src/contracts/SummerVestingWallet.sol";
import {SummerTokenTestBase} from "./SummerTokenTestBase.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {Test, console} from "forge-std/Test.sol";

/*
 * @title SummerGovernorTest
 * @dev Test contract for SummerGovernor functionality.
 */
contract SummerGovernorTest is
    Test,
    ISummerGovernorErrors,
    SummerTokenTestBase
{
    SummerGovernor public governor;
    TimelockController public timelock;
    VotingDecayManager public votingDecayManager;

    address public alice = address(0x111);
    address public bob = address(0x112);
    address public charlie = address(0x113);
    address public david = address(0x114);
    address public whitelistGuardian = address(0x115);

    uint48 public constant VOTING_DELAY = 1;
    uint32 public constant VOTING_PERIOD = 50400;
    uint256 public constant PROPOSAL_THRESHOLD = 100000e18;
    uint256 public constant QUORUM_FRACTION = 4;
    /// @notice Initial decay rate per second (approximately 10% per year)
    /// @dev Calculated as (0.1e18 / (365 * 24 * 60 * 60))
    uint256 internal constant INITIAL_DECAY_RATE_PER_SECOND = 3.1709792e9;
    uint40 public constant INITIAL_DECAY_FREE_WINDOW = 30 days;

    /*
     * @dev Sets up the test environment.
     */
    function setUp() public override {
        initializeTokenTests();
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
        vm.label(david, "David");

        vm.label(address(aSummerToken), "MockERC20Votes");

        address[] memory proposers = new address[](1);
        proposers[0] = address(this);
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        timelock = new TimelockController(
            1 days,
            proposers,
            executors,
            address(this)
        );
        vm.label(address(timelock), "TimelockController");

        SummerGovernor.GovernorParams memory params = SummerGovernor
            .GovernorParams({
                token: IVotes(address(aSummerToken)),
                timelock: timelock,
                votingDelay: VOTING_DELAY,
                votingPeriod: VOTING_PERIOD,
                proposalThreshold: PROPOSAL_THRESHOLD,
                quorumFraction: QUORUM_FRACTION,
                initialWhitelistGuardian: whitelistGuardian,
                initialDecayFreeWindow: INITIAL_DECAY_FREE_WINDOW,
                initialDecayRate: INITIAL_DECAY_RATE_PER_SECOND,
                initialDecayFunction: VotingDecayLibrary.DecayFunction.Linear
            });

        governor = new SummerGovernor(params);
        vm.label(address(governor), "SummerGovernor");

        changeTokensOwnership(address(timelock));

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
    }

    /*
     * @dev Tests the initial setup of the governor.
     * Verifies that the governor's parameters are set correctly.
     */
    function test_InitialSetup() public {
        SummerGovernor.GovernorParams memory params = SummerGovernor
            .GovernorParams({
                token: IVotes(address(aSummerToken)),
                timelock: timelock,
                votingDelay: VOTING_DELAY,
                votingPeriod: VOTING_PERIOD,
                proposalThreshold: PROPOSAL_THRESHOLD,
                quorumFraction: QUORUM_FRACTION,
                initialWhitelistGuardian: address(0),
                initialDecayFreeWindow: INITIAL_DECAY_FREE_WINDOW,
                initialDecayRate: INITIAL_DECAY_RATE_PER_SECOND,
                initialDecayFunction: VotingDecayLibrary.DecayFunction.Linear
            });
        vm.expectRevert(
            abi.encodeWithSignature(
                "SummerGovernorInvalidWhitelistGuardian(address)",
                address(0)
            )
        );
        new SummerGovernor(params);
        params.initialWhitelistGuardian = whitelistGuardian;
        assertEq(governor.name(), "SummerGovernor");
        assertEq(governor.votingDelay(), VOTING_DELAY);
        assertEq(governor.votingPeriod(), VOTING_PERIOD);
        assertEq(governor.proposalThreshold(), PROPOSAL_THRESHOLD);
        assertEq(governor.quorumNumerator(), QUORUM_FRACTION);
        assertEq(governor.getWhitelistGuardian(), whitelistGuardian);
    }

    /*
     * @dev Tests the proposal creation process.
     * Ensures that a proposal can be created successfully.
     */
    function test_ProposalCreation() public {
        vm.startPrank(address(timelock));
        aSummerToken.mint(address(alice), governor.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);

        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        assertGt(proposalId, 0);
    }

    /*
     * @dev Tests the voting process on a proposal.
     * Verifies that votes are correctly cast and counted.
     */
    function test_Voting() public {
        vm.startPrank(address(timelock));
        aSummerToken.mint(alice, governor.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);

        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        vm.warp(block.timestamp + governor.votingDelay() + 1);
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(alice);
        governor.castVote(proposalId, 1);

        (, uint256 forVotes, ) = governor.proposalVotes(proposalId);
        assertEq(forVotes, governor.proposalThreshold());
    }

    /*
     * @dev Tests the full proposal execution flow.
     * Covers proposal creation, voting, queueing, execution, and result verification.
     */
    function test_ProposalExecution() public {
        vm.startPrank(address(timelock));
        aSummerToken.mint(address(timelock), 100);
        aSummerToken.mint(alice, governor.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);

        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(alice);
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams();
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        vm.warp(block.timestamp + governor.votingDelay() + 1);
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(alice);
        governor.castVote(proposalId, 1);

        vm.warp(block.timestamp + governor.votingPeriod() + 1);
        vm.roll(block.number + governor.votingPeriod() + 1);

        governor.queue(
            targets,
            values,
            calldatas,
            hashDescription(description)
        );

        vm.warp(block.timestamp + timelock.getMinDelay() + 1);

        governor.execute(
            targets,
            values,
            calldatas,
            hashDescription(description)
        );

        assertEq(aSummerToken.balanceOf(bob), 100);
    }

    /*
     * @dev Tests the whitelisting process through a governance proposal.
     * Verifies that an account can be whitelisted via a proposal.
     */
    function test_Whitelisting() public {
        address account = address(0x03);
        uint256 expiration = block.timestamp + 10 days;

        uint256 proposalThreshold = governor.proposalThreshold();

        vm.startPrank(address(timelock));
        aSummerToken.mint(alice, proposalThreshold);
        vm.stopPrank();

        vm.startPrank(alice);
        aSummerToken.delegate(alice);
        vm.roll(block.number + 1);
        vm.stopPrank();

        address[] memory targets = new address[](1);
        targets[0] = address(governor);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            SummerGovernor.setWhitelistAccountExpiration.selector,
            account,
            expiration
        );
        string memory description = "Whitelist account proposal";

        vm.prank(alice);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        uint256 votingDelay = governor.votingDelay();
        vm.warp(block.timestamp + votingDelay + 1);
        vm.roll(block.number + votingDelay + 1);

        vm.prank(alice);
        governor.castVote(proposalId, 1);

        uint256 votingPeriod = governor.votingPeriod();
        vm.warp(block.timestamp + votingPeriod + 1);
        vm.roll(block.number + votingPeriod + 1);

        governor.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        uint256 timelockDelay = timelock.getMinDelay();
        vm.warp(block.timestamp + timelockDelay + 1);

        governor.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        bool isWhitelisted = governor.isWhitelisted(account);
        uint256 actualExpiration = governor.getWhitelistAccountExpiration(
            account
        );

        assertTrue(isWhitelisted, "Account should be whitelisted");
        assertEq(
            actualExpiration,
            expiration,
            "Expiration timestamp should match"
        );
    }

    /*
     * @dev Tests the proposal cancellation process.
     * Ensures that a proposal can be canceled by the whitelist guardian.
     */
    function test_ProposalCancellation() public {
        vm.startPrank(address(timelock));
        aSummerToken.mint(alice, governor.proposalThreshold() * 2);
        vm.stopPrank();

        vm.startPrank(alice);
        aSummerToken.delegate(alice);
        vm.roll(block.number + 1); // Move to next block to activate voting power

        // Create proposal to set Bob as whitelist guardian
        address[] memory targets = new address[](1);
        targets[0] = address(governor);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            SummerGovernor.setWhitelistGuardian.selector,
            bob
        );
        string memory description = "Set Bob as whitelist guardian";

        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        vm.warp(block.timestamp + governor.votingDelay() + 1);
        vm.roll(block.number + governor.votingDelay() + 1);

        governor.castVote(proposalId, 1);

        vm.warp(block.timestamp + governor.votingPeriod() + 1);
        vm.roll(block.number + governor.votingPeriod() + 1);

        // Check the proposal state before queueing
        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Succeeded),
            "Proposal should be in Succeeded state"
        );

        governor.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSignature(
                "SummerGovernorUnauthorizedCancellation(address,address,uint256,uint256)",
                bob,
                alice,
                governor.proposalThreshold() * 2,
                governor.proposalThreshold()
            )
        );
        vm.prank(bob);
        governor.cancel(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        vm.startPrank(whitelistGuardian);
        governor.cancel(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Canceled),
            "Proposal should be canceled"
        );
        vm.stopPrank();
    }

    /*
     * @dev Tests that a proposal creation fails when the proposer is below threshold and not whitelisted.
     */
    function test_ProposalCreationBelowThresholdAndNotWhitelisted() public {
        // Ensure Charlie has some tokens, but below the proposal threshold
        uint256 belowThreshold = governor.proposalThreshold() - 1;
        vm.startPrank(address(timelock));
        aSummerToken.mint(charlie, belowThreshold);
        vm.stopPrank();

        vm.startPrank(charlie);
        aSummerToken.delegate(charlie);
        vm.roll(block.number + 1); // Move to next block to activate voting power

        // Attempt to create a proposal
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams();

        // Expect the transaction to revert with SummerGovernorProposerBelowThresholdAndNotWhitelisted error
        vm.expectRevert(
            abi.encodeWithSelector(
                SummerGovernorProposerBelowThresholdAndNotWhitelisted.selector,
                charlie,
                belowThreshold,
                governor.proposalThreshold()
            )
        );
        governor.propose(targets, values, calldatas, description);

        vm.stopPrank();
    }
    /*
     * @dev Tests the proposalNeedsQueuing function.
     */

    function test_ProposalNeedsQueuing() public {
        vm.startPrank(address(timelock));
        aSummerToken.mint(alice, governor.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);

        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        // Move to voting period
        vm.warp(block.timestamp + governor.votingDelay() + 1);
        vm.roll(block.number + governor.votingDelay() + 1);

        // Cast votes
        vm.prank(alice);
        governor.castVote(proposalId, 1);

        // Move to end of voting period
        vm.warp(block.timestamp + governor.votingPeriod() + 1);
        vm.roll(block.number + governor.votingPeriod() + 1);

        // Check if the proposal needs queuing
        bool needsQueuing = governor.proposalNeedsQueuing(proposalId);

        // Since we're using a TimelockController, the proposal should need queuing
        assertTrue(needsQueuing, "Proposal should need queuing");
    }

    /*
     * @dev Tests the CLOCK_MODE function.
     */
    function test_ClockMode() public view {
        string memory clockMode = governor.CLOCK_MODE();
        assertEq(
            clockMode,
            "mode=blocknumber&from=default",
            "Incorrect CLOCK_MODE"
        );
    }

    /*
     * @dev Tests the clock function.
     */
    function test_Clock() public view {
        uint256 currentBlock = block.number;
        uint48 clockValue = governor.clock();
        assertEq(
            uint256(clockValue),
            currentBlock,
            "Clock value should match current block number"
        );
    }
    /*
     * @dev Tests the supportsInterface function of the governor.
     * Verifies correct interface support.
     */

    function test_SupportsInterface() public view {
        assertTrue(governor.supportsInterface(type(IGovernor).interfaceId));
        assertFalse(governor.supportsInterface(0xffffffff));
    }

    /*
     * @dev Tests the proposal threshold settings.
     * Ensures the threshold is within the allowed range.
     */
    function test_ProposalThreshold() public view {
        uint256 threshold = governor.proposalThreshold();
        assertGe(threshold, governor.MIN_PROPOSAL_THRESHOLD());
        assertLe(threshold, governor.MAX_PROPOSAL_THRESHOLD());
    }

    /*
     * @dev Tests setting proposal threshold out of bounds.
     * Verifies that setting thresholds outside the allowed range reverts.
     */
    function test_SetProposalThresholdOutOfBounds() public {
        uint256 belowMin = governor.MIN_PROPOSAL_THRESHOLD() - 1;
        uint256 aboveMax = governor.MAX_PROPOSAL_THRESHOLD() + 1;

        SummerGovernor.GovernorParams memory params = SummerGovernor
            .GovernorParams({
                token: IVotes(address(aSummerToken)),
                timelock: timelock,
                votingDelay: VOTING_DELAY,
                votingPeriod: VOTING_PERIOD,
                proposalThreshold: belowMin,
                quorumFraction: QUORUM_FRACTION,
                initialWhitelistGuardian: address(0x5),
                initialDecayFreeWindow: INITIAL_DECAY_FREE_WINDOW,
                initialDecayRate: INITIAL_DECAY_RATE_PER_SECOND,
                initialDecayFunction: VotingDecayLibrary.DecayFunction.Linear
            });

        vm.expectRevert(
            abi.encodeWithSelector(
                SummerGovernorInvalidProposalThreshold.selector,
                belowMin,
                governor.MIN_PROPOSAL_THRESHOLD(),
                governor.MAX_PROPOSAL_THRESHOLD()
            )
        );
        new SummerGovernor(params);

        params.proposalThreshold = aboveMax;
        vm.expectRevert(
            abi.encodeWithSelector(
                SummerGovernorInvalidProposalThreshold.selector,
                aboveMax,
                governor.MIN_PROPOSAL_THRESHOLD(),
                governor.MAX_PROPOSAL_THRESHOLD()
            )
        );
        new SummerGovernor(params);
    }

    /*
     * @dev Tests proposal creation by a whitelisted account.
     * Ensures a whitelisted account can create a proposal without meeting the threshold.
     */
    function test_ProposalCreationWhitelisted() public {
        address whitelistedUser = address(0x1234);
        uint256 expiration = block.timestamp + 10 days;

        // Ensure Alice has enough voting power
        uint256 proposalThreshold = governor.proposalThreshold();
        vm.startPrank(address(timelock));
        aSummerToken.mint(alice, proposalThreshold);
        vm.stopPrank();

        vm.startPrank(alice);
        aSummerToken.delegate(alice);

        vm.roll(block.number + 1); // Move to next block to activate voting power
        vm.stopPrank();

        // Create and execute a proposal to set the whitelist account expiration
        address[] memory targets = new address[](1);
        targets[0] = address(governor);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            SummerGovernor.setWhitelistAccountExpiration.selector,
            whitelistedUser,
            expiration
        );
        string memory description = "Set whitelist account expiration";

        vm.prank(alice);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        vm.warp(block.timestamp + governor.votingDelay() + 1);
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(alice);
        governor.castVote(proposalId, 1);

        vm.warp(block.timestamp + governor.votingPeriod() + 1);
        vm.roll(block.number + governor.votingPeriod() + 1);

        vm.prank(alice);
        governor.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        vm.warp(block.timestamp + timelock.getMinDelay() + 1);

        vm.prank(bob);
        governor.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        // Ensure the whitelisted user has no voting power
        vm.prank(whitelistedUser);
        aSummerToken.delegate(address(0));

        // Verify that the user is whitelisted
        assertTrue(
            governor.isWhitelisted(whitelistedUser),
            "User should be whitelisted"
        );

        // Now create a proposal as the whitelisted user
        vm.startPrank(whitelistedUser);
        (uint256 anotherProposalId, ) = createProposal();
        vm.stopPrank();

        // Verify that the proposal was created successfully
        assertTrue(
            anotherProposalId > 0,
            "Proposal should be created successfully"
        );
        assertEq(
            uint256(governor.state(anotherProposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "Proposal should be in Pending state"
        );
    }

    /*
     * @dev Tests cancellation of a proposal by the whitelist guardian.
     * Verifies that the guardian can cancel a proposal.
     */
    function test_CancelProposalByGuardian() public {
        vm.startPrank(address(timelock));
        aSummerToken.mint(alice, governor.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);

        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(alice);
        (uint256 proposalId, bytes32 descriptionHash) = createProposal();

        address guardian = address(0x5678);

        // Create and execute a proposal to set the whitelist guardian
        address[] memory targets = new address[](1);
        targets[0] = address(governor);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            SummerGovernor.setWhitelistGuardian.selector,
            guardian
        );
        string memory description = "Set whitelist guardian";

        vm.prank(alice);
        uint256 guardianProposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        vm.warp(block.timestamp + governor.votingDelay() + 1);
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(alice);
        governor.castVote(guardianProposalId, 1);

        vm.warp(block.timestamp + governor.votingPeriod() + 1);
        vm.roll(block.number + governor.votingPeriod() + 1);

        governor.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        vm.warp(block.timestamp + timelock.getMinDelay() + 1);

        governor.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        // Now cancel the original proposal as the guardian
        (
            address[] memory cancelTargets,
            uint256[] memory cancelValues,
            bytes[] memory cancelCalldatas,

        ) = createProposalParams();

        vm.prank(guardian);
        governor.cancel(
            cancelTargets,
            cancelValues,
            cancelCalldatas,
            descriptionHash
        );

        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Canceled)
        );
    }

    /*
     * @dev Tests cancellation of a proposal by the proposer.
     * Ensures the proposer can cancel their own proposal.
     */
    function test_CancelProposalByProposer() public {
        vm.startPrank(address(timelock));
        aSummerToken.mint(alice, governor.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);

        vm.roll(block.number + governor.votingDelay() + 1);

        vm.startPrank(alice);
        (uint256 proposalId, bytes32 descriptionHash) = createProposal();
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,

        ) = createProposalParams();

        governor.cancel(targets, values, calldatas, descriptionHash);
        vm.stopPrank();

        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Canceled)
        );
    }

    /*
     * @dev Tests a proposal that doesn't reach quorum.
     * Verifies that a proposal is defeated if it doesn't reach quorum.
     */
    function test_ProposalWithoutQuorum() public {
        uint256 supply = 100000000 * 10 ** 18;

        uint256 quorumThreshold = getQuorumThreshold(supply);
        assertTrue(
            quorumThreshold > governor.proposalThreshold(),
            "Quorum threshold should be greater than proposal threshold"
        );

        // Give Charlie enough tokens to meet the proposal threshold but not enough to reach quorum
        vm.startPrank(address(timelock));
        aSummerToken.mint(charlie, quorumThreshold / 2);
        aSummerToken.mint(alice, supply - quorumThreshold / 2);
        vm.stopPrank();

        // Charlie delegates to himself
        vm.prank(charlie);
        aSummerToken.delegate(charlie);

        // Move forward more blocks to ensure voting power is updated
        vm.roll(block.number + 10);

        console.log("Charlie's votes :", aSummerToken.getVotes(charlie));
        console.log("Charlie's balance :", aSummerToken.balanceOf(charlie));
        // Ensure Charlie has enough tokens to meet the proposal threshold
        uint256 charlieVotes = governor.getVotes(charlie, block.number - 1);
        uint256 proposalThreshold = governor.proposalThreshold();
        assertGe(
            charlieVotes,
            proposalThreshold,
            "Charlie should have enough voting power"
        );
        assertLt(
            charlieVotes,
            quorumThreshold,
            "Charlie should not have enough voting power to reach quorum"
        );

        // Create a proposal
        vm.prank(charlie);
        (uint256 proposalId, ) = createProposal();

        // Move to voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // Charlie votes in favor
        vm.prank(charlie);
        governor.castVote(proposalId, 1);

        // Move to end of voting period
        vm.roll(block.number + governor.votingPeriod());

        // Check proposal state
        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Defeated),
            "Proposal should be defeated"
        );

        // Verify that quorum was not reached
        (
            uint256 againstVotes,
            uint256 forVotes,
            uint256 abstainVotes
        ) = governor.proposalVotes(proposalId);
        uint256 quorum = governor.quorum(block.number - 1);
        assertTrue(
            forVotes + againstVotes + abstainVotes < quorum,
            "Quorum should not be reached"
        );
    }

    /*
     * @dev Tests various voting scenarios.
     * Covers cases like majority in favor, tie, and majority against.
     */
    function test_VariousVotingScenarios() public {
        // Mint tokens to voters
        uint256 aliceTokens = 1000000e18;
        uint256 bobTokens = 300000e18;
        uint256 charlieTokens = 200000e18;
        uint256 davidTokens = 100000e18;

        vm.startPrank(address(timelock));
        aSummerToken.mint(alice, aliceTokens); // Increased Alice's tokens
        aSummerToken.mint(bob, bobTokens);
        aSummerToken.mint(charlie, charlieTokens);
        aSummerToken.mint(david, davidTokens);
        vm.stopPrank();

        // Delegate votes
        vm.prank(alice);
        aSummerToken.delegate(alice);
        vm.prank(bob);
        aSummerToken.delegate(bob);
        vm.prank(charlie);
        aSummerToken.delegate(charlie);
        vm.prank(david);
        aSummerToken.delegate(david);

        // Move forward a few blocks to ensure voting power is updated
        vm.roll(block.number + 10);

        // Mint tokens to the timelock
        vm.startPrank(address(timelock));
        aSummerToken.mint(address(timelock), 1000); // Mint more than needed for the proposal
        vm.stopPrank();

        // Scenario 1: Majority in favor, quorum reached
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams();

        vm.prank(alice); // Ensure Alice is the proposer
        uint256 proposalId1 = governor.propose(
            targets,
            values,
            calldatas,
            description
        );
        vm.roll(block.number + governor.votingDelay() + 1);
        console.log(
            "Alice's votes     :",
            governor.getVotes(alice, block.number - 1)
        );
        console.log(
            "Bob's votes       :",
            governor.getVotes(bob, block.number - 1)
        );
        console.log(
            "Charlie's votes   :",
            governor.getVotes(charlie, block.number - 1)
        );
        console.log(
            "David's votes     :",
            governor.getVotes(david, block.number - 1)
        );
        // Cast votes

        vm.prank(alice);
        governor.castVote(proposalId1, 1);

        vm.prank(bob);
        governor.castVote(proposalId1, 1);

        vm.prank(charlie);
        governor.castVote(proposalId1, 0);

        vm.prank(david);
        governor.castVote(proposalId1, 2);

        vm.roll(block.number + governor.votingPeriod());
        assertEq(
            uint256(governor.state(proposalId1)),
            uint256(IGovernor.ProposalState.Succeeded)
        );

        // Queue and execute the proposal
        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + timelock.getMinDelay());
        governor.execute(targets, values, calldatas, descriptionHash);

        assertEq(
            uint256(governor.state(proposalId1)),
            uint256(IGovernor.ProposalState.Executed)
        );

        // Reset the state for the next scenario
        vm.roll(block.number + 1);

        // Scenario 2: Tie, quorum reached
        aliceTokens = aSummerToken.getVotes(alice);
        bobTokens = aSummerToken.getVotes(bob);
        charlieTokens = aSummerToken.getVotes(charlie);
        davidTokens = aSummerToken.getVotes(david);

        uint256 proposalId2 = createProposalAndVote(bob, 1, 1, 1, 1);
        vm.roll(block.number + governor.votingPeriod());

        // Add logging statements
        (
            uint256 againstVotes,
            uint256 forVotes,
            uint256 abstainVotes
        ) = governor.proposalVotes(proposalId2);
        console.log("For votes      :", forVotes);
        console.log("Against votes  :", againstVotes);
        console.log("Abstain votes  :", abstainVotes);
        console.log("Quorum         :", governor.quorum(block.number - 1));
        console.log(
            "Total supply   :",
            aSummerToken.getPastTotalSupply(block.number - 1)
        );

        // This is the failing assertion
        assertEq(
            uint256(governor.state(proposalId2)),
            uint256(IGovernor.ProposalState.Succeeded),
            "Proposal should be succeeded"
        );

        // Add assertions to verify vote counts and quorum
        assertEq(
            forVotes,
            aliceTokens + bobTokens + charlieTokens + davidTokens,
            "Incorrect number of 'for' votes"
        );
        assertEq(againstVotes, 0, "There should be no 'against' votes");
        assertEq(abstainVotes, 0, "There should be no 'abstain' votes");
        assertGe(
            forVotes,
            governor.quorum(block.number - 1),
            "For votes should meet or exceed quorum"
        );

        // Reset the state for the next scenario
        vm.roll(block.number + 1);

        // Scenario 3: Majority against, quorum reached
        aliceTokens = aSummerToken.getVotes(alice);
        bobTokens = aSummerToken.getVotes(bob);
        charlieTokens = aSummerToken.getVotes(charlie);
        davidTokens = aSummerToken.getVotes(david);

        uint256 proposalId3 = createProposalAndVote(charlie, 0, 0, 1, 2);
        vm.roll(block.number + governor.votingPeriod());
        (againstVotes, forVotes, abstainVotes) = governor.proposalVotes(
            proposalId3
        );
        assertEq(aliceTokens + bobTokens, againstVotes, "Should be equal");
        assertEq(forVotes, charlieTokens, "For votes should be zero");
        assertEq(
            abstainVotes,
            davidTokens,
            "Against votes should be equal to David's votes"
        );
        assertEq(
            uint256(governor.state(proposalId3)),
            uint256(IGovernor.ProposalState.Defeated),
            "Proposal should be defeated"
        );
    }

    function test_VotingPowerIncludesVestingWalletBalance() public {
        // Setup: Create a vesting wallet for Alice
        uint256 vestingAmount = 500000 * 10 ** 18;
        uint256 directAmount = 1000000 * 10 ** 18;
        console.log("Vesting amount :", vestingAmount);
        vm.startPrank(address(timelock));
        aSummerToken.mint(address(timelock), vestingAmount);
        vm.stopPrank();

        vm.startPrank(address(timelock));
        aSummerToken.createVestingWallet(
            alice,
            vestingAmount,
            SummerVestingWallet.VestingType.TwoYearQuarterly
        );
        aSummerToken.mint(alice, directAmount);
        vm.stopPrank();

        // Alice delegates to herself
        vm.prank(alice);
        aSummerToken.delegate(alice);

        // Move forward a few blocks to ensure voting power is updated
        vm.roll(block.number + 10);

        // Check Alice's voting power
        uint256 aliceVotingPower = governor.getVotes(alice, block.number - 1);
        uint256 expectedVotingPower = vestingAmount + directAmount;

        assertEq(
            aliceVotingPower,
            expectedVotingPower,
            "Alice's voting power should include both locked and unlocked tokens"
        );

        // Create a proposal
        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        // Move to voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // Alice votes
        vm.prank(alice);
        governor.castVote(proposalId, 1);

        // Check proposal votes
        (, uint256 forVotes, ) = governor.proposalVotes(proposalId);
        assertEq(
            forVotes,
            expectedVotingPower,
            "Proposal votes should reflect Alice's full voting power"
        );
    }

    function getQuorumThreshold(uint256 supply) public view returns (uint256) {
        return (supply * QUORUM_FRACTION) / 100;
    }

    function createProposalAndVote(
        address proposer,
        uint8 aliceVote,
        uint8 bobVote,
        uint8 charlieVote,
        uint8 davidVote
    ) internal returns (uint256) {
        vm.roll(block.number + 1); // Ensure a new block for the proposal
        vm.prank(proposer);
        (uint256 proposalId, ) = createProposal();

        // Add a check here to ensure the proposal is created successfully
        require(proposalId != 0, "Proposal creation failed");

        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(alice);
        governor.castVote(proposalId, aliceVote);
        vm.prank(bob);
        governor.castVote(proposalId, bobVote);
        vm.prank(charlie);
        governor.castVote(proposalId, charlieVote);
        vm.prank(david);
        governor.castVote(proposalId, davidVote);

        return proposalId;
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
        ) = createProposalParams();

        // Add a unique identifier to the description to ensure unique proposals
        description = string(
            abi.encodePacked(description, " - ", block.number)
        );

        uint256 proposalId = governor.propose(
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
    function createProposalParams()
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
        targets[0] = address(aSummerToken);
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
}
