// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SummerGovernor} from "../src/contracts/SummerGovernor.sol";
import {ISummerGovernorErrors} from "../src/errors/ISummerGovernorErrors.sol";
import {ISummerGovernor} from "../src/interfaces/ISummerGovernor.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/src/VotingDecayLibrary.sol";
import {VotingDecayManager} from "@summerfi/voting-decay/src/VotingDecayManager.sol";

import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {ERC20, ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

import {TestHelperOz5, IOAppSetPeer} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {Test, console} from "forge-std/Test.sol";

/*
 * @title MockERC20Votes
 * @dev A mock ERC20 token with voting capabilities for testing purposes.
 */
contract MockERC20Votes is ERC20, ERC20Permit, ERC20Votes {
    constructor() ERC20("Mock Token", "MTK") ERC20Permit("Mock Token") {}

    /*
     * @dev Mints tokens to a specified address.
     * @param to The address to mint tokens to.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    /*
     * @dev Overrides the nonces function to resolve conflicts between ERC20Permit and Nonces.
     * @param owner The address to check nonces for.
     * @return The current nonce for the given address.
     */
    function nonces(
        address owner
    ) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    /*
     * @dev Internal function to update token balances.
     * @param from The address to transfer tokens from.
     * @param to The address to transfer tokens to.
     * @param amount The amount of tokens to transfer.
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._update(from, to, amount);
    }
}

/*
 * @title SummerGovernorTest
 * @dev Test contract for SummerGovernor functionality.
 */
contract SummerGovernorTest is TestHelperOz5, ISummerGovernorErrors {
    using OptionsBuilder for bytes;

    SummerGovernor public governorA;
    SummerGovernor public governorB;
    MockERC20Votes public tokenA;
    MockERC20Votes public tokenB;
    TimelockController public timelockA;
    TimelockController public timelockB;
    VotingDecayManager public votingDecayManagerA;
    VotingDecayManager public votingDecayManagerB;

    uint32 private aEid = 1;
    uint32 private bEid = 2;

    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);
    address public david = address(0x4);
    address public whitelistGuardian = address(0x5);

    uint256 public constant INITIAL_SUPPLY = 1000000e18;
    uint48 public constant VOTING_DELAY = 1;
    uint32 public constant VOTING_PERIOD = 50400;
    uint256 public constant PROPOSAL_THRESHOLD = 10000e18;
    uint256 public constant QUORUM_FRACTION = 4;
    /// @notice Initial decay rate per second (approximately 10% per year)
    /// @dev Calculated as (0.1e18 / (365 * 24 * 60 * 60))
    uint256 internal constant INITIAL_DECAY_RATE_PER_SECOND = 3.1709792e9;
    uint40 public constant INITIAL_DECAY_FREE_WINDOW = 30 days;

    /*
     * @dev Sets up the test environment.
     */
    function setUp() public override {
        super.setUp();

        setUpEndpoints(2, LibraryType.UltraLightNode);

        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
        vm.label(david, "David");

        tokenA = new MockERC20Votes();
        tokenB = new MockERC20Votes();
        vm.label(address(tokenA), "MockERC20Votes A");
        vm.label(address(tokenB), "MockERC20Votes B");

        tokenA.mint(alice, INITIAL_SUPPLY);
        tokenB.mint(alice, INITIAL_SUPPLY);

        address lzEndpointA = address(endpoints[aEid]);
        address lzEndpointB = address(endpoints[bEid]);
        vm.label(lzEndpointA, "LayerZero Endpoint A");
        vm.label(lzEndpointB, "LayerZero Endpoint B");

        // Set up TimelockController for both chains
        address[] memory proposers = new address[](1);
        proposers[0] = address(this);
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        timelockA = new TimelockController(
            1 days,
            proposers,
            executors,
            address(this)
        );
        timelockB = new TimelockController(
            1 days,
            proposers,
            executors,
            address(this)
        );
        vm.label(address(timelockA), "TimelockController A");
        vm.label(address(timelockB), "TimelockController B");

        // Set up SummerGovernor for both chains
        SummerGovernor.GovernorParams memory paramsA = SummerGovernor
            .GovernorParams({
                token: IVotes(address(tokenA)),
                timelock: timelockA,
                votingDelay: VOTING_DELAY,
                votingPeriod: VOTING_PERIOD,
                proposalThreshold: PROPOSAL_THRESHOLD,
                quorumFraction: QUORUM_FRACTION,
                initialWhitelistGuardian: whitelistGuardian,
                initialDecayFreeWindow: INITIAL_DECAY_FREE_WINDOW,
                initialDecayRate: INITIAL_DECAY_RATE_PER_SECOND,
                initialDecayFunction: VotingDecayLibrary.DecayFunction.Linear,
                endpoint: lzEndpointA
            });

        SummerGovernor.GovernorParams memory paramsB = SummerGovernor
            .GovernorParams({
                token: IVotes(address(tokenB)),
                timelock: timelockB,
                votingDelay: VOTING_DELAY,
                votingPeriod: VOTING_PERIOD,
                proposalThreshold: PROPOSAL_THRESHOLD,
                quorumFraction: QUORUM_FRACTION,
                initialWhitelistGuardian: whitelistGuardian,
                initialDecayFreeWindow: INITIAL_DECAY_FREE_WINDOW,
                initialDecayRate: INITIAL_DECAY_RATE_PER_SECOND,
                initialDecayFunction: VotingDecayLibrary.DecayFunction.Linear,
                endpoint: lzEndpointB
            });

        governorA = new SummerGovernor(paramsA);
        governorB = new SummerGovernor(paramsB);

        vm.label(address(governorA), "SummerGovernor A");
        vm.label(address(governorB), "SummerGovernor B");

        timelockA.grantRole(timelockA.PROPOSER_ROLE(), address(governorA));
        timelockA.grantRole(timelockA.CANCELLER_ROLE(), address(governorA));
        timelockB.grantRole(timelockB.PROPOSER_ROLE(), address(governorB));
        timelockB.grantRole(timelockB.CANCELLER_ROLE(), address(governorB));

        vm.prank(alice);
        tokenA.delegate(alice);
        vm.prank(alice);
        tokenB.delegate(alice);

        // Wire the governors (if needed)
        address[] memory governors = new address[](2);
        governors[0] = address(governorA);
        governors[1] = address(governorB);

        IOAppSetPeer aOApp = IOAppSetPeer(address(governorA));
        IOAppSetPeer bOApp = IOAppSetPeer(address(governorB));

        // Connect governorA to governorB
        vm.prank(address(governorB));
        uint32 bEid_ = (bOApp.endpoint()).eid();

        vm.prank(address(governorA));
        aOApp.setPeer(bEid_, addressToBytes32(address(bOApp)));

        // Connect governorB to governorA
        vm.prank(address(governorA));
        uint32 aEid_ = (aOApp.endpoint()).eid();

        vm.prank(address(governorB));
        bOApp.setPeer(aEid_, addressToBytes32(address(aOApp)));
    }

    /*
     * @dev Tests the initial setup of the governor.
     * Verifies that the governor's parameters are set correctly.
     */
    function test_InitialSetup() public {
        address lzEndpointA = address(endpoints[aEid]);

        SummerGovernor.GovernorParams memory params = SummerGovernor
            .GovernorParams({
                token: IVotes(address(tokenA)),
                timelock: timelockA,
                votingDelay: VOTING_DELAY,
                votingPeriod: VOTING_PERIOD,
                proposalThreshold: PROPOSAL_THRESHOLD,
                quorumFraction: QUORUM_FRACTION,
                initialWhitelistGuardian: address(0),
                initialDecayFreeWindow: INITIAL_DECAY_FREE_WINDOW,
                initialDecayRate: INITIAL_DECAY_RATE_PER_SECOND,
                initialDecayFunction: VotingDecayLibrary.DecayFunction.Linear,
                endpoint: lzEndpointA
            });
        vm.expectRevert(
            abi.encodeWithSignature(
                "SummerGovernorInvalidWhitelistGuardian(address)",
                address(0)
            )
        );
        new SummerGovernor(params);
        params.initialWhitelistGuardian = whitelistGuardian;
        assertEq(governorA.name(), "SummerGovernor");
        assertEq(governorA.votingDelay(), VOTING_DELAY);
        assertEq(governorA.votingPeriod(), VOTING_PERIOD);
        assertEq(governorA.proposalThreshold(), PROPOSAL_THRESHOLD);
        assertEq(governorA.quorumNumerator(), QUORUM_FRACTION);
        assertEq(governorA.getWhitelistGuardian(), whitelistGuardian);
    }

    /*
     * @dev Tests the proposal creation process.
     * Ensures that a proposal can be created successfully.
     */
    function test_ProposalCreation() public {
        deal(address(tokenA), alice, governorA.proposalThreshold());
        vm.roll(block.number + governorA.votingDelay() + 1);

        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        assertGt(proposalId, 0);
    }

    /*
     * @dev Tests the voting process on a proposal.
     * Verifies that votes are correctly cast and counted.
     */
    function test_Voting() public {
        deal(address(tokenA), alice, governorA.proposalThreshold());
        vm.roll(block.number + governorA.votingDelay() + 1);

        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        vm.warp(block.timestamp + governorA.votingDelay() + 1);
        vm.roll(block.number + governorA.votingDelay() + 1);

        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        (, uint256 forVotes, ) = governorA.proposalVotes(proposalId);
        assertEq(forVotes, INITIAL_SUPPLY);
    }

    /*
     * @dev Tests the full proposal execution flow.
     * Covers proposal creation, voting, queueing, execution, and result verification.
     */
    function test_ProposalExecution() public {
        deal(address(tokenA), address(timelockA), 100);
        deal(address(tokenA), alice, governorA.proposalThreshold());
        vm.roll(block.number + governorA.votingDelay() + 1);

        vm.prank(alice);
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams();
        uint256 proposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        vm.warp(block.timestamp + governorA.votingDelay() + 1);
        vm.roll(block.number + governorA.votingDelay() + 1);

        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        vm.warp(block.timestamp + governorA.votingPeriod() + 1);
        vm.roll(block.number + governorA.votingPeriod() + 1);

        governorA.queue(
            targets,
            values,
            calldatas,
            hashDescription(description)
        );

        vm.warp(block.timestamp + timelockA.getMinDelay() + 1);

        governorA.execute(
            targets,
            values,
            calldatas,
            hashDescription(description)
        );

        assertEq(tokenA.balanceOf(bob), 100);
    }

    /*
     * @dev Tests the whitelisting process through a governance proposal.
     * Verifies that an account can be whitelisted via a proposal.
     */
    function test_Whitelisting() public {
        address account = address(0x03);
        uint256 expiration = block.timestamp + 10 days;

        uint256 proposalThreshold = governorA.proposalThreshold();

        vm.prank(address(tokenA));
        deal(address(tokenA), alice, proposalThreshold);

        vm.startPrank(alice);
        tokenA.delegate(alice);
        vm.roll(block.number + 1);
        vm.stopPrank();

        address[] memory targets = new address[](1);
        targets[0] = address(governorA);
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
        uint256 proposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        uint256 votingDelay = governorA.votingDelay();
        vm.warp(block.timestamp + votingDelay + 1);
        vm.roll(block.number + votingDelay + 1);

        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        uint256 votingPeriod = governorA.votingPeriod();
        vm.warp(block.timestamp + votingPeriod + 1);
        vm.roll(block.number + votingPeriod + 1);

        governorA.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        uint256 timelockDelay = timelockA.getMinDelay();
        vm.warp(block.timestamp + timelockDelay + 1);

        governorA.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        bool isWhitelisted = governorA.isWhitelisted(account);
        uint256 actualExpiration = governorA.getWhitelistAccountExpiration(
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
        deal(address(tokenA), alice, governorA.proposalThreshold() * 2);

        vm.startPrank(alice);
        tokenA.delegate(alice);
        vm.roll(block.number + 1); // Move to next block to activate voting power

        // Create proposal to set Bob as whitelist guardian
        address[] memory targets = new address[](1);
        targets[0] = address(governorA);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            SummerGovernor.setWhitelistGuardian.selector,
            bob
        );
        string memory description = "Set Bob as whitelist guardian";

        uint256 proposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        vm.warp(block.timestamp + governorA.votingDelay() + 1);
        vm.roll(block.number + governorA.votingDelay() + 1);

        governorA.castVote(proposalId, 1);

        vm.warp(block.timestamp + governorA.votingPeriod() + 1);
        vm.roll(block.number + governorA.votingPeriod() + 1);

        // Check the proposal state before queueing
        assertEq(
            uint256(governorA.state(proposalId)),
            uint256(IGovernor.ProposalState.Succeeded),
            "Proposal should be in Succeeded state"
        );

        governorA.queue(
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
                1000000000000000000000000,
                governorA.proposalThreshold()
            )
        );
        vm.prank(bob);
        governorA.cancel(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        vm.startPrank(whitelistGuardian);
        governorA.cancel(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        assertEq(
            uint256(governorA.state(proposalId)),
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
        uint256 belowThreshold = governorA.proposalThreshold() - 1;
        deal(address(tokenA), charlie, belowThreshold);

        vm.startPrank(charlie);
        tokenA.delegate(charlie);
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
                governorA.proposalThreshold()
            )
        );
        governorA.propose(targets, values, calldatas, description);

        vm.stopPrank();
    }
    /*
     * @dev Tests the proposalNeedsQueuing function.
     */

    function test_ProposalNeedsQueuing() public {
        deal(address(tokenA), alice, governorA.proposalThreshold());
        vm.roll(block.number + governorA.votingDelay() + 1);

        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        // Move to voting period
        vm.warp(block.timestamp + governorA.votingDelay() + 1);
        vm.roll(block.number + governorA.votingDelay() + 1);

        // Cast votes
        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        // Move to end of voting period
        vm.warp(block.timestamp + governorA.votingPeriod() + 1);
        vm.roll(block.number + governorA.votingPeriod() + 1);

        // Check if the proposal needs queuing
        bool needsQueuing = governorA.proposalNeedsQueuing(proposalId);

        // Since we're using a TimelockController, the proposal should need queuing
        assertTrue(needsQueuing, "Proposal should need queuing");
    }

    /*
     * @dev Tests the CLOCK_MODE function.
     */
    function test_ClockMode() public view {
        string memory clockMode = governorA.CLOCK_MODE();
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
        uint48 clockValue = governorA.clock();
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
        assertTrue(governorA.supportsInterface(type(IGovernor).interfaceId));
        assertFalse(governorA.supportsInterface(0xffffffff));
    }

    /*
     * @dev Tests the proposal threshold settings.
     * Ensures the threshold is within the allowed range.
     */
    function test_ProposalThreshold() public view {
        uint256 threshold = governorA.proposalThreshold();
        assertGe(threshold, governorA.MIN_PROPOSAL_THRESHOLD());
        assertLe(threshold, governorA.MAX_PROPOSAL_THRESHOLD());
    }

    /*
     * @dev Tests setting proposal threshold out of bounds.
     * Verifies that setting thresholds outside the allowed range reverts.
     */
    function test_SetProposalThresholdOutOfBounds() public {
        uint256 belowMin = governorA.MIN_PROPOSAL_THRESHOLD() - 1;
        uint256 aboveMax = governorA.MAX_PROPOSAL_THRESHOLD() + 1;

        address lzEndpointA = address(endpoints[aEid]);

        SummerGovernor.GovernorParams memory params = SummerGovernor
            .GovernorParams({
                token: IVotes(address(tokenA)),
                timelock: timelockA,
                votingDelay: VOTING_DELAY,
                votingPeriod: VOTING_PERIOD,
                proposalThreshold: belowMin,
                quorumFraction: QUORUM_FRACTION,
                initialWhitelistGuardian: address(0x5),
                initialDecayFreeWindow: INITIAL_DECAY_FREE_WINDOW,
                initialDecayRate: INITIAL_DECAY_RATE_PER_SECOND,
                initialDecayFunction: VotingDecayLibrary.DecayFunction.Linear,
                endpoint: lzEndpointA
            });

        vm.expectRevert(
            abi.encodeWithSelector(
                SummerGovernorInvalidProposalThreshold.selector,
                belowMin,
                governorA.MIN_PROPOSAL_THRESHOLD(),
                governorA.MAX_PROPOSAL_THRESHOLD()
            )
        );
        new SummerGovernor(params);

        params.proposalThreshold = aboveMax;
        vm.expectRevert(
            abi.encodeWithSelector(
                SummerGovernorInvalidProposalThreshold.selector,
                aboveMax,
                governorA.MIN_PROPOSAL_THRESHOLD(),
                governorA.MAX_PROPOSAL_THRESHOLD()
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
        uint256 proposalThreshold = governorA.proposalThreshold();
        deal(address(tokenA), alice, proposalThreshold);

        vm.startPrank(alice);
        tokenA.delegate(alice);
        vm.roll(block.number + 1); // Move to next block to activate voting power
        vm.stopPrank();

        // Create and execute a proposal to set the whitelist account expiration
        address[] memory targets = new address[](1);
        targets[0] = address(governorA);
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
        uint256 proposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        vm.warp(block.timestamp + governorA.votingDelay() + 1);
        vm.roll(block.number + governorA.votingDelay() + 1);

        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        vm.warp(block.timestamp + governorA.votingPeriod() + 1);
        vm.roll(block.number + governorA.votingPeriod() + 1);

        vm.prank(alice);
        governorA.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        vm.warp(block.timestamp + timelockA.getMinDelay() + 1);

        vm.prank(bob);
        governorA.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        // Ensure the whitelisted user has no voting power
        vm.prank(whitelistedUser);
        tokenA.delegate(address(0));

        // Verify that the user is whitelisted
        assertTrue(
            governorA.isWhitelisted(whitelistedUser),
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
            uint256(governorA.state(anotherProposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "Proposal should be in Pending state"
        );
    }

    /*
     * @dev Tests cancellation of a proposal by the whitelist guardian.
     * Verifies that the guardian can cancel a proposal.
     */
    function test_CancelProposalByGuardian() public {
        deal(address(tokenA), alice, governorA.proposalThreshold());
        vm.roll(block.number + governorA.votingDelay() + 1);

        vm.prank(alice);
        (uint256 proposalId, bytes32 descriptionHash) = createProposal();

        address guardian = address(0x5678);

        // Create and execute a proposal to set the whitelist guardian
        address[] memory targets = new address[](1);
        targets[0] = address(governorA);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            SummerGovernor.setWhitelistGuardian.selector,
            guardian
        );
        string memory description = "Set whitelist guardian";

        vm.prank(alice);
        uint256 guardianProposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        vm.warp(block.timestamp + governorA.votingDelay() + 1);
        vm.roll(block.number + governorA.votingDelay() + 1);

        vm.prank(alice);
        governorA.castVote(guardianProposalId, 1);

        vm.warp(block.timestamp + governorA.votingPeriod() + 1);
        vm.roll(block.number + governorA.votingPeriod() + 1);

        governorA.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        vm.warp(block.timestamp + timelockA.getMinDelay() + 1);

        governorA.execute(
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
        governorA.cancel(
            cancelTargets,
            cancelValues,
            cancelCalldatas,
            descriptionHash
        );

        assertEq(
            uint256(governorA.state(proposalId)),
            uint256(IGovernor.ProposalState.Canceled)
        );
    }

    /*
     * @dev Tests cancellation of a proposal by the proposer.
     * Ensures the proposer can cancel their own proposal.
     */
    function test_CancelProposalByProposer() public {
        deal(address(tokenA), alice, governorA.proposalThreshold());
        vm.roll(block.number + governorA.votingDelay() + 1);

        vm.startPrank(alice);
        (uint256 proposalId, bytes32 descriptionHash) = createProposal();
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,

        ) = createProposalParams();

        governorA.cancel(targets, values, calldatas, descriptionHash);
        vm.stopPrank();

        assertEq(
            uint256(governorA.state(proposalId)),
            uint256(IGovernor.ProposalState.Canceled)
        );
    }

    /*
     * @dev Tests a proposal that doesn't reach quorum.
     * Verifies that a proposal is defeated if it doesn't reach quorum.
     */
    function test_ProposalWithoutQuorum() public {
        uint256 quorumThreshold = getQuorumThreshold();

        // Give Charlie enough tokens to meet the proposal threshold but not enough to reach quorum
        vm.startPrank(address(timelockA));
        tokenA.mint(charlie, quorumThreshold / 2);
        tokenA.mint(alice, quorumThreshold / 2);
        vm.stopPrank();

        // Charlie delegates to himself
        vm.prank(charlie);
        tokenA.delegate(charlie);

        // Move forward more blocks to ensure voting power is updated
        vm.roll(block.number + 10);

        // Ensure Charlie has enough tokens to meet the proposal threshold
        uint256 charlieVotes = governorA.getVotes(charlie, block.number - 1);
        uint256 proposalThreshold = governorA.proposalThreshold();
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
        vm.roll(block.number + governorA.votingDelay() + 1);

        // Charlie votes in favor
        vm.prank(charlie);
        governorA.castVote(proposalId, 1);

        // Move to end of voting period
        vm.roll(block.number + governorA.votingPeriod());

        // Check proposal state
        assertEq(
            uint256(governorA.state(proposalId)),
            uint256(IGovernor.ProposalState.Defeated),
            "Proposal should be defeated"
        );

        // Verify that quorum was not reached
        (
            uint256 againstVotes,
            uint256 forVotes,
            uint256 abstainVotes
        ) = governorA.proposalVotes(proposalId);
        uint256 quorum = governorA.quorum(block.number - 1);
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
        vm.startPrank(address(timelockA));
        tokenA.mint(alice, 1000000e18); // Increased Alice's tokens
        tokenA.mint(bob, 300000e18);
        tokenA.mint(charlie, 200000e18);
        tokenA.mint(david, 100000e18);
        vm.stopPrank();

        // Delegate votes
        vm.prank(alice);
        tokenA.delegate(alice);
        vm.prank(bob);
        tokenA.delegate(bob);
        vm.prank(charlie);
        tokenA.delegate(charlie);
        vm.prank(david);
        tokenA.delegate(david);

        // Move forward a few blocks to ensure voting power is updated
        vm.roll(block.number + 10);

        // Mint tokens to the timelock
        vm.startPrank(address(timelockA));
        tokenA.mint(address(timelockA), 1000); // Mint more than needed for the proposal
        vm.stopPrank();

        // Scenario 1: Majority in favor, quorum reached
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams();

        vm.prank(alice); // Ensure Alice is the proposer
        uint256 proposalId1 = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );
        vm.roll(block.number + governorA.votingDelay() + 1);

        // Cast votes
        vm.prank(alice);
        governorA.castVote(proposalId1, 1);
        vm.prank(bob);
        governorA.castVote(proposalId1, 1);
        vm.prank(charlie);
        governorA.castVote(proposalId1, 0);
        vm.prank(david);
        governorA.castVote(proposalId1, 2);

        vm.roll(block.number + governorA.votingPeriod());
        assertEq(
            uint256(governorA.state(proposalId1)),
            uint256(IGovernor.ProposalState.Succeeded)
        );

        // Queue and execute the proposal
        bytes32 descriptionHash = keccak256(bytes(description));
        governorA.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + timelockA.getMinDelay());
        governorA.execute(targets, values, calldatas, descriptionHash);

        assertEq(
            uint256(governorA.state(proposalId1)),
            uint256(IGovernor.ProposalState.Executed)
        );

        // Reset the state for the next scenario
        vm.roll(block.number + 1);

        // Scenario 2: Tie, quorum reached
        uint256 proposalId2 = createProposalAndVote(bob, 1, 1, 1, 1);
        vm.roll(block.number + governorA.votingPeriod());

        // Add logging statements
        (
            uint256 againstVotes,
            uint256 forVotes,
            uint256 abstainVotes
        ) = governorA.proposalVotes(proposalId2);
        console.log("For votes:", forVotes);
        console.log("Against votes:", againstVotes);
        console.log("Abstain votes:", abstainVotes);
        console.log("Quorum:", governorA.quorum(block.number - 1));
        console.log(
            "Total supply:",
            tokenA.getPastTotalSupply(block.number - 1)
        );

        // This is the failing assertion
        assertEq(
            uint256(governorA.state(proposalId2)),
            uint256(IGovernor.ProposalState.Succeeded)
        );

        // Add assertions to verify vote counts and quorum
        assertEq(
            forVotes,
            2600000000000000000000100,
            "Incorrect number of 'for' votes"
        );
        assertEq(againstVotes, 0, "There should be no 'against' votes");
        assertEq(abstainVotes, 0, "There should be no 'abstain' votes");
        assertGe(
            forVotes,
            governorA.quorum(block.number - 1),
            "For votes should meet or exceed quorum"
        );

        // Reset the state for the next scenario
        vm.roll(block.number + 1);

        // Scenario 3: Majority against, quorum reached
        uint256 proposalId3 = createProposalAndVote(charlie, 0, 0, 1, 2);
        vm.roll(block.number + governorA.votingPeriod());
        assertEq(
            uint256(governorA.state(proposalId3)),
            uint256(IGovernor.ProposalState.Defeated)
        );
    }

    /*
     * @dev Tests cross-chain proposal submission.
     * Ensures a proposal can be submitted from one chain and received on another.
     */
    function test_CrossChainExecution() public {
        vm.deal(address(governorA), 100 ether);
        vm.deal(address(governorB), 100 ether);

        // Prepare cross-chainproposal parameters
        (
            address[] memory srcTargets,
            uint256[] memory srcValues,
            bytes[] memory srcCalldatas,
            string memory srcDescription,
            uint256 dstProposalId
        ) = createCrossChainProposal(bEid, governorA);

        // Ensure Alice has enough tokens on chain A
        deal(address(tokenA), alice, governorA.proposalThreshold() * 2); // Increased token amount
        vm.prank(alice);
        tokenA.delegate(alice);
        vm.roll(block.number + 1);

        // Submit proposal on chain A
        vm.prank(alice);
        uint256 proposalIdA = governorA.propose(
            srcTargets,
            srcValues,
            srcCalldatas,
            srcDescription
        );

        // Move to voting period
        vm.warp(block.timestamp + governorA.votingDelay() + 1);
        vm.roll(block.number + governorA.votingDelay() + 1);

        // Cast vote
        vm.prank(alice);
        governorA.castVote(proposalIdA, 1); // Vote in favor

        // Move to end of voting period
        vm.warp(block.timestamp + governorA.votingPeriod() + 1);
        vm.roll(block.number + governorA.votingPeriod() + 1);

        governorA.queue(
            srcTargets,
            srcValues,
            srcCalldatas,
            hashDescription(srcDescription)
        );

        vm.warp(block.timestamp + timelockA.getMinDelay());

        vm.expectEmit(true, true, true, true);
        emit ISummerGovernor.ProposalQueuedCrossChain(dstProposalId, bEid);
        governorA.execute(
            srcTargets,
            srcValues,
            srcCalldatas,
            hashDescription(srcDescription)
        );
    }

    function test_SendCrossChainProposalAndExecution() public {
        // Test
    }

    function test_SendCrossChainProposal_RevertWhenCalldataIsEmpty() public {
        // Test that the function reverts when _srcCalldatas is empty
    }

    function test_SendCrossChainProposal_RevertWhenDstEidIsZero() public {
        // Test that the function reverts when the decoded dstEid is 0
    }

    function test_SendCrossChainProposal_RevertWhenSourceProposalNotExecuted()
        public
    {
        // Test that the function reverts when the source proposal is not in Executed state
    }

    function test_SendCrossChainProposal_RevertWhenProposalNotQueuedCrossChain()
        public
    {
        // Test that the function reverts when the proposal has not been queued cross-chain
    }

    function test_SendCrossChainProposal_RevertWhenProposalAlreadySentCrossChain()
        public
    {
        // Test that the function reverts when the proposal has already been sent cross-chain
    }

    function test_SendCrossChainProposal_RevertWhenRefundFails() public {
        // Test that the function reverts when the refund to the sender fails
    }

    function test_SendCrossChainProposal_SuccessfulExecution() public {
        // Test a successful execution of sendCrossChainProposal
    }

    function test_SendCrossChainProposal_CorrectEventEmitted() public {
        // Test that the correct ProposalSentCrossChain event is emitted
    }

    function test_SendCrossChainProposal_CorrectProposalMarkedAsSent() public {
        // Test that the proposal is correctly marked as sent in the queuedCrossChainProposals mapping
    }

    function test_SendCrossChainProposal_CorrectMessageSentToLzEndpoint()
        public
    {
        // Test that the correct message is sent to the LayerZero endpoint
    }

    function test_SendCrossChainProposal_CorrectRefundAmount() public {
        // Test that the correct amount is refunded to the sender
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
        targets[0] = address(tokenA);
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

    function createCrossChainProposal(
        uint32 dstEid,
        SummerGovernor srcGovernor
    )
        internal
        view
        returns (
            address[] memory,
            uint256[] memory,
            bytes[] memory,
            string memory,
            uint256
        )
    {
        (
            address[] memory dstTargets,
            uint256[] memory dstValues,
            bytes[] memory dstCalldatas,
            string memory dstDescription
        ) = createProposalParams();

        bytes[] memory srcCalldatas = new bytes[](1);

        srcCalldatas[0] = abi.encodeWithSelector(
            SummerGovernor.queueCrossChainProposal.selector,
            dstEid,
            dstTargets,
            dstValues,
            dstCalldatas,
            keccak256(bytes(dstDescription))
        );

        uint256 dstProposalId = srcGovernor.hashProposal(
            dstTargets,
            dstValues,
            dstCalldatas,
            keccak256(bytes(dstDescription))
        );

        address[] memory srcTargets = new address[](1);
        srcTargets[0] = address(srcGovernor);

        uint256[] memory srcValues = new uint256[](1);
        srcValues[0] = 0;

        string memory srcDescription = string(
            abi.encodePacked("Cross-chain proposal: ", dstDescription)
        );

        return (
            srcTargets,
            srcValues,
            srcCalldatas,
            srcDescription,
            dstProposalId
        );
    }

    function getQuorumThreshold() public view returns (uint256) {
        return (tokenA.totalSupply() * QUORUM_FRACTION) / 100;
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

        vm.roll(block.number + governorA.votingDelay() + 1);

        vm.prank(alice);
        governorA.castVote(proposalId, aliceVote);
        vm.prank(bob);
        governorA.castVote(proposalId, bobVote);
        vm.prank(charlie);
        governorA.castVote(proposalId, charlieVote);
        vm.prank(david);
        governorA.castVote(proposalId, davidVote);

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

        uint256 proposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        return (proposalId, hashDescription(description));
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
