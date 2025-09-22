// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Origin, SummerGovernorV2} from "../../src/contracts/SummerGovernorV2.sol";
import {ISummerGovernorErrors} from "../../src/errors/ISummerGovernorErrors.sol";

import {ISummerGovernorV2} from "../../src/interfaces/ISummerGovernorV2.sol";
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
import {SummerGovernorV2TestBase} from "./SummerGovernorV2TestBase.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ExposedSummerTimelockController} from "../token/SummerTokenTestBase.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

/*
 * @title SummerGovernorTest
 * @dev Test contract for SummerGovernorV2 functionality.
 */
contract SummerGovernorTest is SummerGovernorV2TestBase {
    function test_InitialSetup() public {
        address lzEndpointA = address(endpoints[aEid]);

        SummerGovernorV2.GovernorParams memory params = ISummerGovernorV2
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
        new SummerGovernorV2(params);
        assertEq(governorA.name(), "SummerGovernorV2");
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
        // Stake tokens to get StakedSummerToken for voting rights
        uint256 requiredAmount = governorA.quorum(block.timestamp - 1) * 2;
        stakeAndGetXSumr(alice, requiredAmount, true);
        vm.prank(alice);
        axSumr.delegate(alice);

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
        // Stake tokens to get StakedSummerToken for proposal threshold
        uint256 proposalThreshold = governorA.proposalThreshold();
        stakeAndGetXSumr(alice, proposalThreshold, true);
        vm.prank(alice);
        axSumr.delegate(alice);
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
        // Stake tokens to get StakedSummerToken for quorum
        uint256 quorumAmount = governorA.quorum(block.timestamp - 1) * 2;
        stakeAndGetXSumr(alice, quorumAmount, true);
        vm.prank(alice);
        axSumr.delegate(alice);
        advanceTimeAndBlock();

        vm.prank(alice);
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams(address(testToken));
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

        assertEq(testToken.balanceOf(bob), 100, "bob should have 100 tokens");
    }

    /*
     * @dev Tests that a proposal creation fails when the proposer is below threshold and not whitelisted.
     */
    function test_ProposalCreationBelowThresholdAndNotWhitelisted() public {
        // Ensure Charlie has some tokens, but below the proposal threshold
        uint256 belowThreshold = governorA.proposalThreshold() - 1;

        stakeAndGetXSumr(charlie, belowThreshold, true);
        vm.prank(charlie);
        axSumr.delegate(charlie);
        advanceTimeAndBlock();
        // Attempt to create a proposal
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams(address(testToken));

        // Expect the transaction to revert with SummerGovernorProposerBelowThresholdAndNotGuardian error
        vm.expectRevert(
            abi.encodeWithSelector(
                SummerGovernorProposerBelowThresholdAndNotGuardian.selector,
                charlie,
                belowThreshold,
                governorA.proposalThreshold()
            )
        );
        vm.prank(charlie);
        governorA.propose(targets, values, calldatas, description);
    }

    /*
     * @dev Tests the proposalNeedsQueuing function.
     */
    function test_ProposalNeedsQueuing() public {
        stakeAndGetXSumr(alice, governorA.proposalThreshold(), true);

        vm.prank(alice);
        axSumr.delegate(alice);

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

        SummerGovernorV2.GovernorParams memory params = ISummerGovernorV2
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
        new SummerGovernorV2(params);

        params.proposalThreshold = aboveMax;
        vm.expectRevert(
            abi.encodeWithSelector(
                SummerGovernorInvalidProposalThreshold.selector,
                aboveMax,
                governorA.MIN_PROPOSAL_THRESHOLD(),
                governorA.MAX_PROPOSAL_THRESHOLD()
            )
        );
        new SummerGovernorV2(params);
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
        stakeAndGetXSumr(
            alice,
            governorA.quorum(block.timestamp - 1) * 2,
            true
        );

        vm.startPrank(alice);
        axSumr.delegate(alice);
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
        axSumr.delegate(address(0));

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
        stakeAndGetXSumr(alice, governorA.proposalThreshold() * 2, true);

        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Create proposal
        vm.prank(alice);
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams(address(testToken));

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
        stakeAndGetXSumr(alice, governorA.proposalThreshold(), true);

        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeForVotingDelay();

        vm.startPrank(alice);
        (uint256 proposalId, bytes32 descriptionHash) = createProposal();
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,

        ) = createProposalParams(address(testToken));

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
        stakeAndGetXSumr(charlie, quorumThreshold / 2, true);
        stakeAndGetXSumr(alice, supply - quorumThreshold / 2, true);

        // Charlie delegates to himself
        vm.prank(charlie);
        axSumr.delegate(charlie);

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
        uint quorum = governorA.quorum(block.timestamp - 1);
        uint256 aliceTokens = (3 * quorum) / 10;
        uint256 bobTokens = (3 * quorum) / 10;
        uint256 charlieTokens = quorum / 4;
        uint256 davidTokens = quorum - aliceTokens - bobTokens;

        stakeAndGetXSumr(alice, aliceTokens, true);
        stakeAndGetXSumr(bob, bobTokens, true);
        stakeAndGetXSumr(charlie, charlieTokens, true);
        stakeAndGetXSumr(david, davidTokens, true);

        // Delegate votes
        vm.prank(alice);
        axSumr.delegate(alice);
        vm.prank(bob);
        axSumr.delegate(bob);
        vm.prank(charlie);
        axSumr.delegate(charlie);
        vm.prank(david);
        axSumr.delegate(david);

        advanceTimeAndBlock();

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams(address(testToken));

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
        uint quorum = governorA.quorum(block.timestamp - 1);
        uint256 aliceTokens = (2 * quorum) / 9;
        uint256 bobTokens = (3 * quorum) / 9;
        uint256 charlieTokens = (2 * quorum) / 9;
        uint256 davidTokens = quorum - aliceTokens - bobTokens - charlieTokens;

        assertGe(
            aliceTokens + bobTokens + charlieTokens + davidTokens,
            quorum,
            "Total votes should be greater than quorum"
        );

        stakeAndGetXSumr(alice, aliceTokens, true);
        stakeAndGetXSumr(bob, bobTokens, true);
        stakeAndGetXSumr(charlie, charlieTokens, true);
        stakeAndGetXSumr(david, davidTokens, true);

        // Delegate votes
        vm.prank(alice);
        axSumr.delegate(alice);
        vm.prank(bob);
        axSumr.delegate(bob);
        vm.prank(charlie);
        axSumr.delegate(charlie);
        vm.prank(david);
        axSumr.delegate(david);

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
            "Failed to meet quorum - unanimous support"
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
        uint quorum = governorA.quorum(block.timestamp - 1);
        uint256 aliceTokens = (38 * quorum) / 108;
        uint256 bobTokens = (30 * quorum) / 108;
        uint256 charlieTokens = (20 * quorum) / 108;
        uint256 davidTokens = quorum - aliceTokens - bobTokens - charlieTokens;

        stakeAndGetXSumr(alice, aliceTokens, true);
        stakeAndGetXSumr(bob, bobTokens, true);
        stakeAndGetXSumr(charlie, charlieTokens, true);
        stakeAndGetXSumr(david, davidTokens, true);

        // Delegate votes
        vm.prank(alice);
        axSumr.delegate(alice);
        vm.prank(bob);
        axSumr.delegate(bob);
        vm.prank(charlie);
        axSumr.delegate(charlie);
        vm.prank(david);
        axSumr.delegate(david);

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

    // function test_VotingPowerIncludesVestingWalletBalance() public {
    //     // Setup: Create a vesting wallet for Alice
    //     uint256 vestingAmount = 500000 * 10 ** 18;
    //     uint256 directAmount = 1000000 * 10 ** 18;
    //     console.log("Vesting amount :", vestingAmount);

    //     // Grant foundation role to timelock
    //     vm.startPrank(address(timelockA));
    //     accessManagerA.grantFoundationRole(address(timelockA));
    //     vm.stopPrank();

    //     vm.startPrank(address(timelockA));
    //     vestingWalletFactoryA.createVestingWallet(
    //         alice,
    //         vestingAmount,
    //         new uint256[](0),
    //         ISummerVestingWallet.VestingType.TeamVesting
    //     );
    //     stakeAndGetXSumr(alice, directAmount, true);
    //     vm.stopPrank();

    //     // Alice delegates to herself
    //     vm.prank(alice);
    //     axSumr.delegate(alice);

    //     advanceTimeAndBlock();

    //     // Check Alice's voting power
    //     uint256 aliceVotingPower = governorA.getVotes(
    //         alice,
    //         block.timestamp - 1
    //     );
    //     uint256 expectedVotingPower = vestingAmount + directAmount;

    //     assertEq(
    //         aliceVotingPower,
    //         expectedVotingPower,
    //         "Alice's voting power should include both locked and unlocked tokens"
    //     );

    //     // Create a proposal
    //     vm.prank(alice);
    //     (uint256 proposalId, ) = createProposal();

    //     advanceTimeForVotingDelay();

    //     // Alice votes
    //     vm.prank(alice);
    //     governorA.castVote(proposalId, 1);

    //     // Check proposal votes
    //     (, uint256 forVotes, ) = governorA.proposalVotes(proposalId);

    //     assertEq(
    //         forVotes,
    //         expectedVotingPower,
    //         "Proposal votes should reflect Alice's full voting power"
    //     );
    // }

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
        SummerGovernorV2.GovernorParams memory params = ISummerGovernorV2
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

        SummerGovernorV2 wrongChainGovernor = new SummerGovernorV2(params);

        // Ensure Alice has enough tokens to meet the proposal threshold
        deal(
            address(aSummerToken),
            alice,
            wrongChainGovernor.proposalThreshold()
        );
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Prepare proposal parameters
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams(address(testToken));

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

    // function test_VestingWalletVotingPower() public {
    //     // Initial setup
    //     uint256 vestingAmount = 500000 * 10 ** 18;
    //     uint256 directAmount = 1000000 * 10 ** 18;
    //     uint256 additionalAmount = 100000 * 10 ** 18;
    //     address _bob = address(0xb0b);

    //     // Grant foundation role to timelock
    //     vm.startPrank(address(timelockA));
    //     accessManagerA.grantFoundationRole(address(timelockA));
    //     vm.stopPrank();

    //     vm.prank(_bob);
    //     // Bob delegates to himself - even if he has no tokens yet, he will have voting power after Cas 5 test is
    //     // finished
    //     axSumr.delegate(_bob);
    //     advanceTimeAndBlock();

    //     // Case 1: Create vesting wallet and transfer initial tokens
    //     vm.startPrank(address(timelockA));
    //     aSummerToken.approve(address(vestingWalletFactoryA), vestingAmount);
    //     vestingWalletFactoryA.createVestingWallet(
    //         alice,
    //         vestingAmount,
    //         new uint256[](0),
    //         ISummerVestingWallet.VestingType.TeamVesting
    //     );

    //         stakeAndGetXSumr(alice, directAmount, true);

    //     vm.stopPrank();

    //     address vestingWalletAddress = vestingWalletFactoryA.vestingWallets(
    //         alice
    //     );
    //     SummerVestingWallet vestingWallet = SummerVestingWallet(
    //         payable(vestingWalletAddress)
    //     );

    //     // Alice delegates to herself
    //     vm.prank(alice);
    //     axSumr.delegate(alice);

    //     advanceTimeAndBlock();

    //     // Check initial state
    //     uint256 aliceVotingPower = governorA.getVotes(
    //         alice,
    //         block.timestamp - 1
    //     );
    //     uint256 vestingWalletVotingPower = governorA.getVotes(
    //         vestingWalletAddress,
    //         block.timestamp - 1
    //     );
    //     assertEq(
    //         vestingWalletVotingPower,
    //         0,
    //         "Vesting wallet should have 0 voting power"
    //     );
    //     assertEq(
    //         aliceVotingPower,
    //         vestingAmount + directAmount,
    //         "Alice should have voting power from both direct and vesting tokens"
    //     );

    //     // Case 2: Transfer from Alice to vesting wallet (should not change voting power)
    //     vm.startPrank(alice);
    //     aSummerToken.transfer(vestingWalletAddress, 100000 * 10 ** 18);
    //     advanceTimeAndBlock();

    //     uint256 newAliceVotingPower = governorA.getVotes(
    //         alice,
    //         block.timestamp - 1
    //     );
    //     assertEq(
    //         newAliceVotingPower,
    //         aliceVotingPower,
    //         "Alice's voting power should not change when transferring to own vesting wallet"
    //     );

    //     // Case 3: Transfer from another address to vesting wallet
    //     vm.startPrank(address(timelockA));
    //     aSummerToken.transfer(vestingWalletAddress, additionalAmount);
    //     advanceTimeAndBlock();

    //     uint256 updatedAliceVotingPower = governorA.getVotes(
    //         alice,
    //         block.timestamp - 1
    //     );
    //     assertEq(
    //         updatedAliceVotingPower,
    //         newAliceVotingPower + additionalAmount,
    //         "Alice's voting power should increase when vesting wallet receives tokens from others"
    //     );

    //     // Case 4: Transfer from vesting wallet to beneficiary (Alice)
    //     // First, let's make the tokens vestable
    //     vm.warp(block.timestamp + 365 days);
    //     vestingWallet.vestedAmount(
    //         address(aSummerToken),
    //         SafeCast.toUint64(block.timestamp)
    //     );
    //     vm.startPrank(alice);
    //     vestingWallet.release(address(aSummerToken));
    //     advanceTimeAndBlock();

    //     uint256 afterClaimVotingPower = governorA.getVotes(
    //         alice,
    //         block.timestamp - 1
    //     );

    //     // Case 5: Transfer from vesting wallet to third party (Bob)
    //     vm.startPrank(vestingWalletAddress);
    //     uint256 transferAmount = 25000 * 10 ** 18;
    //     aSummerToken.transfer(_bob, transferAmount);
    //     advanceTimeAndBlock();

    //     uint256 finalAliceVotingPower = governorA.getVotes(
    //         alice,
    //         block.timestamp - 1
    //     );

    //     uint256 bobVotingPower = governorA.getVotes(_bob, block.timestamp - 1);
    //     assertEq(
    //         finalAliceVotingPower,
    //         afterClaimVotingPower - transferAmount,
    //         "Alice's voting power should decrease when vesting wallet transfers to third party"
    //     );
    //     assertEq(
    //         bobVotingPower,
    //         transferAmount,
    //         "Bob should receive voting power from vesting wallet transfer"
    //     );
    // }

    // function test_VestingWalletTransferOwnership() public {
    //     // Initial setup
    //     uint256 vestingAmount = 500000 * 10 ** 18;
    //     uint256 directAmount = 1000000 * 10 ** 18;
    //     uint256 additionalAmount = 100000 * 10 ** 18;

    //     // Grant foundation role to timelock
    //     vm.startPrank(address(timelockA));
    //     accessManagerA.grantFoundationRole(address(timelockA));
    //     vm.stopPrank();

    //     // Create vesting wallet
    //     vm.startPrank(address(timelockA));
    //     aSummerToken.approve(address(vestingWalletFactoryA), vestingAmount);
    //     vestingWalletFactoryA.createVestingWallet(
    //         alice,
    //         vestingAmount,
    //         new uint256[](0),
    //         ISummerVestingWallet.VestingType.TeamVesting
    //     );
    //     aSummerToken.transfer(alice, directAmount);
    //     vm.stopPrank();

    //     // Delegate to herself
    //     vm.startPrank(alice);
    //     axSumr.delegate(alice);
    //     vm.stopPrank();

    //     advanceTimeAndBlock();

    //     uint256 aliceVotesBeforeTransfer = governorA.getVotes(
    //         alice,
    //         block.timestamp - 1
    //     );
    //     uint256 bobVotesBeforeTransfer = governorA.getVotes(
    //         bob,
    //         block.timestamp - 1
    //     );
    //     console.log("Alice votes before transfer:", aliceVotesBeforeTransfer);
    //     console.log("Direct amount transferred: :", directAmount);
    //     console.log("Bob votes before transfer  :", bobVotesBeforeTransfer);
    //     address vestingWallet = vestingWalletFactoryA.vestingWallets(alice);
    //     // Transfer ownership
    //     vm.startPrank(address(alice));
    //     SummerVestingWallet(payable(vestingWallet)).transferOwnership(bob);
    //     aSummerToken.transfer(bob, directAmount);
    //     vm.stopPrank();

    //     vm.prank(bob);
    //     axSumr.delegate(bob);
    //     advanceTimeAndBlock();

    //     uint256 aliceVotesAfterTransfer = governorA.getVotes(
    //         alice,
    //         block.timestamp - 1
    //     );
    //     uint256 bobVotesAfterTransfer = governorA.getVotes(
    //         bob,
    //         block.timestamp - 1
    //     );
    //     console.log("Alice votes after transfer :", aliceVotesAfterTransfer);
    //     console.log("Bob votes after transfer   :", bobVotesAfterTransfer);

    //     assertEq(
    //         aliceVotesAfterTransfer,
    //         aliceVotesBeforeTransfer - directAmount,
    //         "Voting power should not change when transferring ownership, only direct tokens(votes) are transferred"
    //     );
    //     assertEq(
    //         bobVotesAfterTransfer,
    //         bobVotesBeforeTransfer + directAmount,
    //         "Bob should receive voting power from vesting wallet transfer"
    //     );

    //     uint256 bobBalanceBeforeVestingClaim = aSummerToken.balanceOf(bob);
    //     uint256 aliceBalanceBeforeVestingClaim = aSummerToken.balanceOf(alice);
    //     console.log(
    //         "Bob balance before claim   :",
    //         bobBalanceBeforeVestingClaim
    //     );
    //     console.log(
    //         "Alice balance before claim :",
    //         aliceBalanceBeforeVestingClaim
    //     );

    //     // Make the tokens vestable
    //     vm.warp(block.timestamp + 2 * 365 days);

    //     vm.prank(bob);
    //     SummerVestingWallet(payable(vestingWallet)).release(
    //         address(aSummerToken)
    //     );
    //     advanceTimeAndBlock();

    //     uint256 bobBalanceAfterVestingClaim = aSummerToken.balanceOf(bob);
    //     uint256 aliceBalanceAfterVestingClaim = aSummerToken.balanceOf(alice);
    //     console.log(
    //         "Bob balance after claim    :",
    //         bobBalanceAfterVestingClaim
    //     );
    //     console.log(
    //         "Alice balance after claim  :",
    //         aliceBalanceAfterVestingClaim
    //     );

    //     uint256 aliceVotesAfterVestingClaim = governorA.getVotes(
    //         alice,
    //         block.timestamp - 1
    //     );
    //     uint256 bobVotesAfterVestingClaim = governorA.getVotes(
    //         bob,
    //         block.timestamp - 1
    //     );
    //     console.log(
    //         "Alice votes after release  :",
    //         aliceVotesAfterVestingClaim
    //     );
    //     console.log("Bob votes after release    :", bobVotesAfterVestingClaim);

    //     assertEq(
    //         aliceVotesAfterVestingClaim,
    //         0,
    //         "Voting power should decrease when vesting wallet releases tokens"
    //     );
    //     assertEq(
    //         bobVotesAfterVestingClaim,
    //         directAmount + vestingAmount,
    //         "Bob should receive voting power from vesting wallet transfer"
    //     );
    // }
    // function test_VestingWalletTransferOwnershipWithDelegation() public {
    //     // Initial setup
    //     uint256 vestingAmount = 500000 * 10 ** 18;
    //     uint256 directAmount = 1000000 * 10 ** 18;

    //     // Grant foundation role to timelock
    //     vm.startPrank(address(timelockA));
    //     accessManagerA.grantFoundationRole(address(timelockA));
    //     vm.stopPrank();

    //     // Create vesting wallet and transfer direct tokens
    //     vm.startPrank(address(timelockA));
    //     aSummerToken.approve(address(vestingWalletFactoryA), vestingAmount);
    //     vestingWalletFactoryA.createVestingWallet(
    //         alice,
    //         vestingAmount,
    //         new uint256[](0),
    //         ISummerVestingWallet.VestingType.TeamVesting
    //     );
    //     aSummerToken.transfer(alice, directAmount);
    //     vm.stopPrank();

    //     // Initial self-delegation
    //     vm.startPrank(alice);
    //     axSumr.delegate(alice);
    //     vm.stopPrank();
    //     advanceTimeAndBlock();

    //     // Check initial voting power
    //     uint256 aliceInitialVotes = governorA.getVotes(
    //         alice,
    //         block.timestamp - 1
    //     );
    //     console.log("Alice initial votes:", aliceInitialVotes);
    //     assertEq(
    //         aliceInitialVotes,
    //         vestingAmount + directAmount,
    //         "Initial voting power should include vesting and direct tokens"
    //     );

    //     // Delegate to address(0)
    //     vm.startPrank(alice);
    //     axSumr.delegate(address(0));
    //     vm.stopPrank();
    //     advanceTimeAndBlock();

    //     // Check votes after delegating to zero address
    //     uint256 aliceVotesAfterZeroDelegation = governorA.getVotes(
    //         alice,
    //         block.timestamp - 1
    //     );
    //     console.log(
    //         "Alice votes after zero delegation:",
    //         aliceVotesAfterZeroDelegation
    //     );
    //     assertEq(
    //         aliceVotesAfterZeroDelegation,
    //         0,
    //         "Voting power should be zero after delegating to zero address"
    //     );

    //     // Transfer ownership
    //     address vestingWallet = vestingWalletFactoryA.vestingWallets(alice);
    //     vm.startPrank(alice);
    //     SummerVestingWallet(payable(vestingWallet)).transferOwnership(bob);
    //     aSummerToken.transfer(bob, directAmount);
    //     vm.stopPrank();
    //     advanceTimeAndBlock();

    //     // Bob self-delegates
    //     vm.startPrank(bob);
    //     axSumr.delegate(bob);
    //     vm.stopPrank();
    //     advanceTimeAndBlock();

    //     // Check voting power after ownership transfer and Bob's delegation
    //     uint256 bobVotesAfterDelegation = governorA.getVotes(
    //         bob,
    //         block.timestamp - 1
    //     );
    //     uint256 aliceVotesAfterTransfer = governorA.getVotes(
    //         alice,
    //         block.timestamp - 1
    //     );

    //     console.log("Bob votes after delegation:", bobVotesAfterDelegation);
    //     console.log("Alice votes after transfer:", aliceVotesAfterTransfer);

    //     assertEq(
    //         bobVotesAfterDelegation,
    //         directAmount,
    //         "Bob should only have voting power from direct tokens initially"
    //     );
    //     assertEq(
    //         aliceVotesAfterTransfer,
    //         0,
    //         "Alice should have no voting power after transfer and zero delegation"
    //     );

    //     // Make tokens vestable and release
    //     vm.warp(block.timestamp + 2 * 365 days);

    //     vm.prank(bob);
    //     SummerVestingWallet(payable(vestingWallet)).release(
    //         address(aSummerToken)
    //     );
    //     advanceTimeAndBlock();

    //     // Final voting power check
    //     uint256 bobFinalVotes = governorA.getVotes(bob, block.timestamp - 1);
    //     uint256 aliceFinalVotes = governorA.getVotes(
    //         alice,
    //         block.timestamp - 1
    //     );

    //     console.log("Bob final votes:", bobFinalVotes);
    //     console.log("Alice final votes:", aliceFinalVotes);

    //     assertEq(
    //         bobFinalVotes,
    //         directAmount + vestingAmount,
    //         "Bob should have voting power from both direct and vested tokens"
    //     );
    //     assertEq(aliceFinalVotes, 0, "Alice should still have no voting power");
    // }

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
    function test_GuardianRoleAssignment2() public {
        address account = address(0x03);

        // Give Alice enough tokens to meet proposal threshold
        stakeAndGetXSumr(alice, governorA.quorum(block.timestamp - 1), true);

        vm.prank(alice);
        axSumr.delegate(alice);

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
        stakeAndGetXSumr(alice, governorA.quorum(block.timestamp - 1), true);

        vm.prank(alice);
        axSumr.delegate(alice);

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
        ) = createProposalParams(address(testToken));

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
        stakeAndGetXSumr(
            alice,
            governorA.quorum(block.timestamp - 1) * 2,
            true
        );

        vm.prank(alice);
        axSumr.delegate(alice);
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
