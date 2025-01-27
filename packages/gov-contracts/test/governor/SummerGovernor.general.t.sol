// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Origin, SummerGovernor} from "../../src/contracts/SummerGovernor.sol";
import {ISummerGovernorErrors} from "../../src/errors/ISummerGovernorErrors.sol";

import {ISummerGovernor} from "../../src/interfaces/ISummerGovernor.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

import {SummerToken} from "../../src/contracts/SummerToken.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {IVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {ERC20, ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

import {ISummerToken} from "../../src/interfaces/ISummerToken.sol";
import {SummerVestingWallet} from "../../src/contracts/SummerVestingWallet.sol";
import {ISummerVestingWallet} from "../../src/interfaces/ISummerVestingWallet.sol";
import {SummerTokenTestBase} from "../token/SummerTokenTestBase.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {ExposedSummerGovernor, SummerGovernorTestBase} from "./SummerGovernorTestBase.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ExposedSummerTimelockController} from "../token/SummerTokenTestBase.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

/*
 * @title SummerGovernorTest
 * @dev Test contract for SummerGovernor functionality.
 */
contract SummerGovernorTest is SummerGovernorTestBase {
    function test_InitialSetup() public {
        address lzEndpointA = address(endpoints[aEid]);

        SummerGovernor.GovernorParams memory params = ISummerGovernor
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
        new SummerGovernor(params);
        assertEq(governorA.name(), "SummerGovernor");
        assertEq(governorA.votingDelay(), VOTING_DELAY);
        assertEq(governorA.votingPeriod(), VOTING_PERIOD);
        assertEq(governorA.proposalThreshold(), PROPOSAL_THRESHOLD);
        assertEq(governorA.quorumNumerator(), QUORUM_FRACTION);
    }

    /*
     * @dev Tests the proposal creation process.
     * Ensures that a proposal can be created successfully.
     */
    function test_ProposalCreation() public {
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(
            address(alice),
            governorA.quorum(block.timestamp - 1)
        );
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);

        advanceTimeForVotingDelay();

        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        assertGt(proposalId, 0);
    }

    /*
     * @dev Tests the voting process on a proposal.
     * Verifies that votes are correctly cast and counted.
     */
    function test_Voting() public {
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);

        advanceTimeAndBlock();

        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        advanceTimeForVotingDelay();

        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        (, uint256 forVotes, ) = governorA.proposalVotes(proposalId);
        assertEq(forVotes, governorA.proposalThreshold());
    }

    /*
     * @dev Tests the full proposal execution flow.
     * Covers proposal creation, voting, queueing, execution, and result verification.
     */
    function test_ProposalExecution() public {
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.quorum(block.timestamp - 1));
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);

        advanceTimeAndBlock();

        vm.prank(alice);
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams(address(aSummerToken));
        uint256 proposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        advanceTimeForVotingDelay();

        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        advanceTimeForVotingPeriod();

        governorA.queue(
            targets,
            values,
            calldatas,
            hashDescription(description)
        );

        advanceTimeForTimelockMinDelay();

        governorA.execute(
            targets,
            values,
            calldatas,
            hashDescription(description)
        );

        assertEq(aSummerToken.balanceOf(bob), 100);
    }

    /*
     * @dev Tests that a proposal creation fails when the proposer is below threshold and not whitelisted.
     */
    function test_ProposalCreationBelowThresholdAndNotWhitelisted() public {
        // Ensure Charlie has some tokens, but below the proposal threshold
        uint256 belowThreshold = governorA.proposalThreshold() - 1;
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(charlie, belowThreshold);
        vm.stopPrank();

        vm.startPrank(charlie);
        aSummerToken.delegate(charlie);
        advanceTimeAndBlock();

        // Attempt to create a proposal
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams(address(aSummerToken));

        // Expect the transaction to revert with SummerGovernorProposerBelowThresholdAndNotGuardian error
        vm.expectRevert(
            abi.encodeWithSelector(
                SummerGovernorProposerBelowThresholdAndNotGuardian.selector,
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
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);

        advanceTimeAndBlock();

        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        advanceTimeForVotingDelay();

        // Cast votes
        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        advanceTimeForVotingPeriod();

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
        assertEq(clockMode, "mode=timestamp", "Incorrect CLOCK_MODE");
    }

    /*
     * @dev Tests the clock function.
     */
    function test_Clock() public view {
        uint256 currentBlock = block.timestamp;
        uint48 clockValue = governorA.clock();
        assertEq(
            uint256(clockValue),
            currentBlock,
            "Clock value should match current block number"
        );
    }

    /*
     * @dev Tests the supportsInterface function of the governorA.
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

        SummerGovernor.GovernorParams memory params = ISummerGovernor
            .GovernorParams({
                token: aSummerToken,
                timelock: timelockA,
                accessManager: address(accessManagerA),
                votingDelay: VOTING_DELAY,
                votingPeriod: VOTING_PERIOD,
                proposalThreshold: belowMin,
                quorumFraction: QUORUM_FRACTION,
                endpoint: lzEndpointA,
                hubChainId: 31337,
                initialOwner: address(timelockA)
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
     * @dev Tests proposal creation by a guardian account.
     * Ensures a guardian account can create a proposal without meeting the threshold.
     */
    function test_ProposalCreationByGuardian() public {
        address guardian = address(0x1234);

        // Setup guardian in AccessManager
        vm.startPrank(address(timelockA));
        accessManagerA.grantGuardianRole(guardian);
        accessManagerA.setGuardianExpiration(
            guardian,
            block.timestamp + 1000000
        );
        vm.stopPrank();

        // Ensure Alice has enough voting power for governance
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.quorum(block.timestamp - 1));
        vm.stopPrank();

        vm.startPrank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();
        vm.stopPrank();

        // Create proposal to grant guardian role through AccessManager
        address[] memory targets = new address[](1);
        targets[0] = address(accessManagerA);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            IProtocolAccessManager.grantGuardianRole.selector,
            guardian
        );
        string memory description = "Grant guardian role";

        vm.prank(alice);
        uint256 proposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        advanceTimeForVotingDelay();

        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        advanceTimeForVotingPeriod();

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

        // Ensure the guardian has no voting power
        vm.prank(guardian);
        aSummerToken.delegate(address(0));

        // Verify that the account has the guardian role
        assertTrue(
            accessManagerA.hasRole(accessManagerA.GUARDIAN_ROLE(), guardian),
            "Account should have guardian role"
        );

        // Create a proposal as the guardian without meeting threshold
        vm.startPrank(guardian);
        (uint256 guardianProposalId, ) = createProposal();
        vm.stopPrank();

        // Verify that the proposal was created successfully
        assertTrue(
            guardianProposalId > 0,
            "Proposal should be created successfully"
        );
        assertEq(
            uint256(governorA.state(guardianProposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "Proposal should be in Pending state"
        );

        // Verify guardian can create proposal without meeting threshold
        uint256 guardianVotes = governorA.getVotes(
            guardian,
            block.timestamp - 1
        );
        assertTrue(
            guardianVotes < governorA.proposalThreshold(),
            "Guardian should have less votes than threshold"
        );
    }

    /*
     * @dev Tests cancellation of a proposal by the whitelist guardian.
     * Verifies that the guardian can cancel a proposal.
     */
    function test_CancelProposalByGuardian() public {
        address guardian = address(0x115);

        // Setup guardian in AccessManager
        vm.startPrank(address(timelockA));
        accessManagerA.grantGuardianRole(guardian);
        accessManagerA.setGuardianExpiration(
            guardian,
            block.timestamp + 1000000
        );
        vm.stopPrank();

        // Setup proposal creation
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.proposalThreshold() * 2);
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);

        advanceTimeAndBlock();

        // Create proposal
        vm.prank(alice);
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams(address(aSummerToken));

        uint256 proposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        // Cancel with guardian
        vm.prank(guardian);
        governorA.cancel(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        // Verify proposal is canceled
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
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);

        advanceTimeForVotingDelay();

        vm.startPrank(alice);
        (uint256 proposalId, bytes32 descriptionHash) = createProposal();
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,

        ) = createProposalParams(address(aSummerToken));

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
        uint256 supply = 100000000 * 10 ** 18;

        uint256 quorumThreshold = getQuorumThreshold(supply);
        assertTrue(
            quorumThreshold > governorA.proposalThreshold(),
            "Quorum threshold should be greater than proposal threshold"
        );

        // Give Charlie enough tokens to meet the proposal threshold but not enough to reach quorum
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(charlie, quorumThreshold / 2);
        aSummerToken.transfer(alice, supply - quorumThreshold / 2);
        vm.stopPrank();

        // Charlie delegates to himself
        vm.prank(charlie);
        aSummerToken.delegate(charlie);

        advanceTimeAndBlock();

        console.log("Charlie's votes :", aSummerToken.getVotes(charlie));
        console.log("Charlie's balance :", aSummerToken.balanceOf(charlie));
        // Ensure Charlie has enough tokens to meet the proposal threshold
        uint256 charlieVotes = governorA.getVotes(charlie, block.timestamp - 1);
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

        advanceTimeForVotingDelay();

        // Charlie votes in favor
        vm.prank(charlie);
        governorA.castVote(proposalId, 1);

        advanceTimeForVotingPeriod();

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
        uint256 quorum = governorA.quorum(block.timestamp - 1);
        assertTrue(
            forVotes + againstVotes + abstainVotes < quorum,
            "Quorum should not be reached"
        );
    }

    function test_ProposalWithMajorityInFavor() public {
        // Mint tokens to voters
        uint256 aliceTokens = 38000000e18;
        uint256 bobTokens = 3000000e18;
        uint256 charlieTokens = 2000000e18;
        uint256 davidTokens = 2000000e18;

        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, aliceTokens);
        aSummerToken.transfer(bob, bobTokens);
        aSummerToken.transfer(charlie, charlieTokens);
        aSummerToken.transfer(david, davidTokens);
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

        advanceTimeAndBlock();

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams(address(aSummerToken));

        vm.prank(alice);
        uint256 proposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        advanceTimeForVotingDelay();

        // Cast votes
        vm.prank(alice);
        governorA.castVote(proposalId, 1); // For
        vm.prank(bob);
        governorA.castVote(proposalId, 1); // For
        vm.prank(charlie);
        governorA.castVote(proposalId, 0); // Against
        vm.prank(david);
        governorA.castVote(proposalId, 2); // Abstain

        advanceTimeForVotingPeriod();

        assertEq(
            uint256(governorA.state(proposalId)),
            uint256(IGovernor.ProposalState.Succeeded)
        );

        // Queue and execute the proposal
        bytes32 descriptionHash = keccak256(bytes(description));
        governorA.queue(targets, values, calldatas, descriptionHash);

        advanceTimeForTimelockMinDelay();

        governorA.execute(targets, values, calldatas, descriptionHash);

        assertEq(
            uint256(governorA.state(proposalId)),
            uint256(IGovernor.ProposalState.Executed)
        );
    }

    function test_ProposalWithUnanimousSupport() public {
        // Mint tokens to voters
        uint256 aliceTokens = 20000000e18;
        uint256 bobTokens = 3000000e18;
        uint256 charlieTokens = 2000000e18;
        uint256 davidTokens = 20000000e18;

        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, aliceTokens);
        aSummerToken.transfer(bob, bobTokens);
        aSummerToken.transfer(charlie, charlieTokens);
        aSummerToken.transfer(david, davidTokens);
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

        advanceTimeAndBlock();

        uint256 proposalId = createProposalAndVote(bob, 1, 1, 1, 1);

        advanceTimeForVotingPeriod();

        // Get vote counts
        (
            uint256 againstVotes,
            uint256 forVotes,
            uint256 abstainVotes
        ) = governorA.proposalVotes(proposalId);

        // Verify quorum was met
        assertTrue(
            forVotes + againstVotes + abstainVotes >=
                governorA.quorum(block.timestamp - 1),
            "Failed to meet quorum"
        );

        // Verify unanimous support
        assertTrue(forVotes > againstVotes, "Failed to achieve majority");
        assertEq(againstVotes, 0, "Should have no votes against");
        assertEq(abstainVotes, 0, "Should have no abstentions");

        assertEq(
            uint256(governorA.state(proposalId)),
            uint256(IGovernor.ProposalState.Succeeded),
            "Proposal should be succeeded"
        );
    }

    function test_ProposalWithMajorityAgainst() public {
        // Mint tokens to voters
        uint256 aliceTokens = 38000000e18;
        uint256 bobTokens = 3000000e18;
        uint256 charlieTokens = 2000000e18;
        uint256 davidTokens = 2000000e18;

        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, aliceTokens);
        aSummerToken.transfer(bob, bobTokens);
        aSummerToken.transfer(charlie, charlieTokens);
        aSummerToken.transfer(david, davidTokens);
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

        advanceTimeAndBlock();

        uint256 proposalId = createProposalAndVote(charlie, 0, 0, 1, 2);

        advanceTimeForVotingPeriod();

        (
            uint256 againstVotes,
            uint256 forVotes,
            uint256 abstainVotes
        ) = governorA.proposalVotes(proposalId);

        assertEq(
            againstVotes,
            aliceTokens + bobTokens,
            "Incorrect against votes"
        );
        assertEq(forVotes, charlieTokens, "Incorrect for votes");
        assertEq(abstainVotes, davidTokens, "Incorrect abstain votes");

        assertEq(
            uint256(governorA.state(proposalId)),
            uint256(IGovernor.ProposalState.Defeated),
            "Proposal should be defeated"
        );
    }

    function test_VotingPowerIncludesVestingWalletBalance() public {
        // Setup: Create a vesting wallet for Alice
        uint256 vestingAmount = 500000 * 10 ** 18;
        uint256 directAmount = 1000000 * 10 ** 18;
        console.log("Vesting amount :", vestingAmount);

        // Grant foundation role to timelock
        vm.startPrank(address(timelockA));
        accessManagerA.grantFoundationRole(address(timelockA));
        vm.stopPrank();

        vm.startPrank(address(timelockA));
        aSummerToken.approve(address(vestingWalletFactoryA), vestingAmount);
        vestingWalletFactoryA.createVestingWallet(
            alice,
            vestingAmount,
            new uint256[](0),
            ISummerVestingWallet.VestingType.TeamVesting
        );
        aSummerToken.transfer(alice, directAmount);
        vm.stopPrank();

        // Alice delegates to herself
        vm.prank(alice);
        aSummerToken.delegate(alice);

        advanceTimeAndBlock();

        // Check Alice's voting power
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        uint256 expectedVotingPower = vestingAmount + directAmount;

        assertEq(
            aliceVotingPower,
            expectedVotingPower,
            "Alice's voting power should include both locked and unlocked tokens"
        );

        // Create a proposal
        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        advanceTimeForVotingDelay();

        // Alice votes
        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        // Check proposal votes
        (, uint256 forVotes, ) = governorA.proposalVotes(proposalId);

        assertEq(
            forVotes,
            expectedVotingPower,
            "Proposal votes should reflect Alice's full voting power"
        );
    }

    function test_ProposalCreationOnWrongChain() public {
        uint32 governanceChainId = 1; // Ethereum mainnet
        uint32 currentChainId = 31337; // Anvil's default chain ID

        // Ensure we're on the expected test chain
        assertEq(
            block.chainid,
            currentChainId,
            "Test environment should be on chain 31337"
        );

        // Deploy the governorA with a different chain ID than the current one
        SummerGovernor.GovernorParams memory params = ISummerGovernor
            .GovernorParams({
                token: aSummerToken,
                timelock: timelockA,
                accessManager: address(accessManagerA),
                votingDelay: VOTING_DELAY,
                votingPeriod: VOTING_PERIOD,
                proposalThreshold: PROPOSAL_THRESHOLD,
                quorumFraction: QUORUM_FRACTION,
                endpoint: address(endpoints[aEid]),
                hubChainId: governanceChainId,
                initialOwner: address(timelockA)
            });

        ExposedSummerGovernor wrongChainGovernor = new ExposedSummerGovernor(
            params
        );

        vm.startPrank(address(timelockA));
        accessManagerA.revokeDecayControllerRole(address(governorA));
        accessManagerA.grantDecayControllerRole(address(wrongChainGovernor));
        vm.stopPrank();

        // Ensure Alice has enough tokens to meet the proposal threshold
        deal(
            address(aSummerToken),
            alice,
            wrongChainGovernor.proposalThreshold()
        );
        vm.prank(alice);
        aSummerToken.delegate(alice);

        advanceTimeAndBlock();

        // Prepare proposal parameters
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams(address(aSummerToken));

        // Attempt to create a proposal, expecting it to revert
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                SummerGovernorNotHubChain.selector,
                currentChainId,
                governanceChainId
            )
        );
        wrongChainGovernor.propose(targets, values, calldatas, description);
    }

    function getQuorumThreshold(uint256 supply) public pure returns (uint256) {
        return (supply * QUORUM_FRACTION) / 100;
    }

    function createProposalAndVote(
        address proposer,
        uint8 aliceVote,
        uint8 bobVote,
        uint8 charlieVote,
        uint8 davidVote
    ) internal returns (uint256) {
        advanceTimeAndBlock();
        vm.prank(proposer);
        (uint256 proposalId, ) = createProposal();

        // Add a check here to ensure the proposal is created successfully
        require(proposalId != 0, "Proposal creation failed");

        advanceTimeForVotingDelay();

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

    function test_DecayUpdateOnPropose() public {
        // Setup
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        // Verify decay update is called when proposing
        vm.expectCall(
            address(aSummerToken),
            abi.encodeWithSelector(
                ISummerToken.updateDecayFactor.selector,
                alice
            )
        );

        vm.prank(alice);
        createProposal();
    }

    function test_VestingWalletVotingPower() public {
        // Initial setup
        uint256 vestingAmount = 500000 * 10 ** 18;
        uint256 directAmount = 1000000 * 10 ** 18;
        uint256 additionalAmount = 100000 * 10 ** 18;
        address _bob = address(0xb0b);

        // Grant foundation role to timelock
        vm.startPrank(address(timelockA));
        accessManagerA.grantFoundationRole(address(timelockA));
        vm.stopPrank();

        vm.prank(address(timelockA));
        aSummerToken.setDecayRatePerYear(Percentage.wrap(0));

        vm.prank(_bob);
        // Bob delegates to himself - even if he has no tokens yet, he will have voting power after Cas 5 test is
        // finished
        aSummerToken.delegate(_bob);
        advanceTimeAndBlock();

        // Case 1: Create vesting wallet and transfer initial tokens
        vm.startPrank(address(timelockA));
        aSummerToken.approve(address(vestingWalletFactoryA), vestingAmount);
        vestingWalletFactoryA.createVestingWallet(
            alice,
            vestingAmount,
            new uint256[](0),
            ISummerVestingWallet.VestingType.TeamVesting
        );

        aSummerToken.transfer(alice, directAmount);
        vm.stopPrank();

        address vestingWalletAddress = vestingWalletFactoryA.vestingWallets(
            alice
        );
        SummerVestingWallet vestingWallet = SummerVestingWallet(
            payable(vestingWalletAddress)
        );

        // Need to initialize decay account for vesting wallet to read votes
        governorA.forceUpdateDecay(vestingWalletAddress);

        // Alice delegates to herself
        vm.prank(alice);
        aSummerToken.delegate(alice);

        advanceTimeAndBlock();

        // Check initial state
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        uint256 vestingWalletVotingPower = governorA.getVotes(
            vestingWalletAddress,
            block.timestamp - 1
        );
        assertEq(
            vestingWalletVotingPower,
            0,
            "Vesting wallet should have 0 voting power"
        );
        assertEq(
            aliceVotingPower,
            vestingAmount + directAmount,
            "Alice should have voting power from both direct and vesting tokens"
        );

        // Case 2: Transfer from Alice to vesting wallet (should not change voting power)
        vm.startPrank(alice);
        aSummerToken.transfer(vestingWalletAddress, 100000 * 10 ** 18);
        advanceTimeAndBlock();

        uint256 newAliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        assertEq(
            newAliceVotingPower,
            aliceVotingPower,
            "Alice's voting power should not change when transferring to own vesting wallet"
        );

        // Case 3: Transfer from another address to vesting wallet
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(vestingWalletAddress, additionalAmount);
        advanceTimeAndBlock();

        uint256 updatedAliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        assertEq(
            updatedAliceVotingPower,
            newAliceVotingPower + additionalAmount,
            "Alice's voting power should increase when vesting wallet receives tokens from others"
        );

        // Case 4: Transfer from vesting wallet to beneficiary (Alice)
        // First, let's make the tokens vestable
        vm.warp(block.timestamp + 365 days);
        vestingWallet.vestedAmount(
            address(aSummerToken),
            SafeCast.toUint64(block.timestamp)
        );
        vm.startPrank(alice);
        vestingWallet.release(address(aSummerToken));
        advanceTimeAndBlock();

        uint256 afterClaimVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        assertEq(
            afterClaimVotingPower,
            updatedAliceVotingPower,
            "Alice's voting power should be less than the updated amount because of decay"
        );

        // Case 5: Transfer from vesting wallet to third party (Bob)
        vm.startPrank(vestingWalletAddress);
        uint256 transferAmount = 25000 * 10 ** 18;
        aSummerToken.transfer(_bob, transferAmount);
        advanceTimeAndBlock();

        uint256 finalAliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        uint256 bobVotingPower = governorA.getVotes(_bob, block.timestamp - 1);
        assertEq(
            finalAliceVotingPower,
            afterClaimVotingPower - transferAmount,
            "Alice's voting power should decrease when vesting wallet transfers to third party"
        );
        assertEq(
            bobVotingPower,
            transferAmount,
            "Bob should receive voting power from vesting wallet transfer"
        );
    }

    function test_DecayUpdateOnVote() public {
        // Setup proposal
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.proposalThreshold());
        aSummerToken.transfer(bob, governorA.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        vm.prank(bob);
        aSummerToken.delegate(bob);
        advanceTimeAndBlock();

        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        // Move to voting period
        advanceTimeForVotingDelay();

        // Verify decay update is called when voting
        vm.expectCall(
            address(aSummerToken),
            abi.encodeWithSelector(ISummerToken.updateDecayFactor.selector, bob)
        );

        vm.prank(bob);
        governorA.castVote(proposalId, 1);
    }

    function test_DecayUpdateOnExecute() public {
        // Setup with sufficient balance for execution
        uint256 initialBalance = governorA.quorum(block.timestamp - 1);
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, initialBalance);
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        vm.prank(alice);
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams(address(aSummerToken));

        uint256 proposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        advanceTimeForVotingDelay();

        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        advanceTimeForVotingPeriod();

        governorA.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        advanceTimeForTimelockMinDelay();

        // Verify decay update is called when executing
        vm.expectCall(
            address(aSummerToken),
            abi.encodeWithSelector(ISummerToken.updateDecayFactor.selector, bob)
        );

        vm.prank(bob);
        governorA.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );
    }

    function test_DecayUpdateOnCancel() public {
        // Setup and create proposal
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        vm.startPrank(alice);
        (, bytes32 descriptionHash) = createProposal();
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,

        ) = createProposalParams(address(aSummerToken));

        // Verify decay update is called when cancelling
        vm.expectCall(
            address(aSummerToken),
            abi.encodeWithSelector(
                ISummerToken.updateDecayFactor.selector,
                alice
            )
        );

        governorA.cancel(targets, values, calldatas, descriptionHash);
        vm.stopPrank();
    }

    function test_DecayFactorUpdatesCorrectly() public {
        uint256 initialBalance = governorA.proposalThreshold() * 10;
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, initialBalance);
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        // Get initial decay factor
        uint256 initialDecayFactor = aSummerToken.getDecayFactor(alice);

        // Create proposal
        vm.prank(alice);
        createProposal();

        advanceTimeForPeriod(VOTING_DELAY + 30 days);

        // Check decay factor after proposal
        uint256 decayFactorAfterProposal = aSummerToken.getDecayFactor(alice);

        assertLt(
            decayFactorAfterProposal,
            initialDecayFactor,
            "Decay factor should decrease after proposal creation"
        );

        console.log("Initial decay factor:", initialDecayFactor);
        console.log("Decay factor after proposal:", decayFactorAfterProposal);
    }

    function test_GetGuardianExpiration() public {
        address guardian = address(0x1234);
        uint256 expirationTime = block.timestamp + 8 days; // Set expiration in the future

        // Setup guardian in AccessManager
        vm.startPrank(address(timelockA));
        accessManagerA.grantGuardianRole(guardian);
        accessManagerA.setGuardianExpiration(guardian, expirationTime);
        vm.stopPrank();

        // Verify expiration was set correctly
        uint256 storedExpiration = accessManagerA.getGuardianExpiration(
            guardian
        );
        assertEq(
            storedExpiration,
            expirationTime,
            "Guardian expiration not set correctly"
        );
    }

    /*
     * @dev Tests the guardian role assignment through a governance proposal.
     * Verifies that an account can be granted the guardian role via a proposal.
     */
    function test_GuardianRoleAssignment() public {
        address account = address(0x03);

        // Give Alice enough tokens to meet proposal threshold
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);

        advanceTimeAndBlock();

        address[] memory targets = new address[](2); // Changed to 2 targets
        uint256[] memory values = new uint256[](2); // Changed to 2 values
        bytes[] memory calldatas = new bytes[](2); // Changed to 2 calldatas

        targets[0] = address(accessManagerA);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(
            IProtocolAccessManager.grantGuardianRole.selector,
            account
        );

        targets[1] = address(accessManagerA);
        values[1] = 0;
        calldatas[1] = abi.encodeWithSelector(
            IProtocolAccessManager.setGuardianExpiration.selector,
            account,
            block.timestamp + 30 days // Set expiration 30 days in the future
        );

        string memory description = "Grant guardian role";

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

        // Verify the account has been granted the guardian role
        bool hasGuardianRole = accessManagerA.hasRole(
            accessManagerA.GUARDIAN_ROLE(),
            account
        );
        assertTrue(hasGuardianRole, "Account should have guardian role");

        // Verify the account can perform guardian actions
        vm.prank(account);
        (
            address[] memory cancelTargets,
            uint256[] memory cancelValues,
            bytes[] memory cancelCalldatas,
            string memory cancelDescription
        ) = createProposalParams(address(aSummerToken));

        uint256 newProposalId = governorA.propose(
            cancelTargets,
            cancelValues,
            cancelCalldatas,
            cancelDescription
        );

        // Guardian should be able to cancel the proposal
        vm.prank(account);
        governorA.cancel(
            cancelTargets,
            cancelValues,
            cancelCalldatas,
            keccak256(bytes(cancelDescription))
        );

        assertEq(
            uint256(governorA.state(newProposalId)),
            uint256(IGovernor.ProposalState.Canceled),
            "Proposal should be canceled by guardian"
        );
    }

    function test_GuardianExpiryProposalTracking() public {
        // Give Alice enough tokens to meet proposal threshold and quorum
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.quorum(block.timestamp - 1));
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        // Test single operation
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(accessManagerA);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(
            IProtocolAccessManager.setGuardianExpiration.selector,
            bob,
            block.timestamp + 30 days
        );

        string memory description = "Set guardian expiry";
        bytes32 singleDescriptionHash = keccak256(bytes(description));

        vm.prank(alice);
        uint256 singleProposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        // Test batch operation with mixed operations
        address[] memory batchTargets = new address[](2);
        uint256[] memory batchValues = new uint256[](2);
        bytes[] memory batchCalldatas = new bytes[](2);

        batchTargets[0] = address(accessManagerA);
        batchValues[0] = 0;
        batchCalldatas[0] = abi.encodeWithSelector(
            IProtocolAccessManager.grantGuardianRole.selector,
            charlie
        );

        batchTargets[1] = address(accessManagerA);
        batchValues[1] = 0;
        batchCalldatas[1] = abi.encodeWithSelector(
            IProtocolAccessManager.setGuardianExpiration.selector,
            charlie,
            block.timestamp + 30 days
        );

        string memory batchDescription = "batch description";
        bytes32 batchDescriptionHash = keccak256(bytes(batchDescription));

        vm.prank(alice);
        uint256 batchProposalId = governorA.propose(
            batchTargets,
            batchValues,
            batchCalldatas,
            batchDescription
        );

        // Vote and queue both proposals
        advanceTimeForVotingDelay();

        vm.startPrank(alice);
        governorA.castVote(singleProposalId, 1);
        governorA.castVote(batchProposalId, 1);
        vm.stopPrank();

        advanceTimeForVotingPeriod();

        governorA.queue(targets, values, calldatas, singleDescriptionHash);
        governorA.queue(
            batchTargets,
            batchValues,
            batchCalldatas,
            batchDescriptionHash
        );

        // Verify that both operations are marked as guardian expiry operations
        bytes32 singleOpId = timelockA.hashOperationBatch(
            targets,
            values,
            calldatas,
            0, // predecessor
            _timelockSalt(address(governorA), singleDescriptionHash) // salt
        );

        bytes32 batchOpId = timelockA.hashOperationBatch(
            batchTargets,
            batchValues,
            batchCalldatas,
            0, // predecessor
            _timelockSalt(address(governorA), batchDescriptionHash) // salt
        );

        console.log("Batch Op Id");
        console.logBytes32(batchOpId);

        assertTrue(
            ExposedSummerTimelockController(payable(address(timelockA)))
                .exposedIsGuardianExpiryProposal(singleOpId),
            "Single operation should be marked as guardian expiry"
        );
        assertTrue(
            ExposedSummerTimelockController(payable(address(timelockA)))
                .exposedIsGuardianExpiryProposal(batchOpId),
            "Batch operation should be marked as guardian expiry"
        );

        // Try to cancel the operations with a guardian (should fail)
        address guardian = address(0x1234);
        vm.startPrank(address(timelockA));
        accessManagerA.grantGuardianRole(guardian);
        accessManagerA.setGuardianExpiration(
            guardian,
            block.timestamp + 1000000
        );
        timelockA.grantRole(timelockA.CANCELLER_ROLE(), guardian);
        vm.stopPrank();

        vm.startPrank(guardian);
        vm.expectRevert("Only governors can cancel guardian expiry proposals");
        timelockA.cancel(singleOpId);

        vm.expectRevert("Only governors can cancel guardian expiry proposals");
        timelockA.cancel(batchOpId);
        vm.stopPrank();
    }

    function _timelockSalt(
        address addressToSalt,
        bytes32 descriptionHash
    ) private pure returns (bytes32) {
        return bytes20(addressToSalt) ^ descriptionHash;
    }
}
