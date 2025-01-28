// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerGovernorTestBase} from "./SummerGovernorTestBase.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {GovernorVotesQuorumFraction} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";

contract SummerGovernorQuorumTest is SummerGovernorTestBase {
    event QuorumNumeratorUpdated(
        uint256 oldQuorumNumerator,
        uint256 newQuorumNumerator
    );

    function test_InitialQuorumSetup() public view {
        assertEq(governorA.quorumNumerator(), QUORUM_FRACTION);
        assertEq(governorA.quorumDenominator(), 100);
    }

    function test_QuorumCalculation() public {
        uint256 totalSupply = 1_000_000_000e18; // 1 billion tokens
        uint256 expectedQuorum = (totalSupply * QUORUM_FRACTION) / 100;

        // Mint total supply
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(address(timelockA), totalSupply);
        vm.stopPrank();

        // Give voting power to a voter
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.proposalThreshold());
        vm.stopPrank();

        // Delegate voting power
        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        // Create proposal
        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        // Wait for voting delay
        advanceTimeForVotingDelay();

        // Transfer voting power to another account to test quorum
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(address(0x1), 40_000_000e18);
        vm.stopPrank();

        vm.prank(address(0x1));
        aSummerToken.delegate(address(0x1));
        advanceTimeAndBlock();

        // Cast vote
        vm.prank(address(0x1));
        governorA.castVote(proposalId, 2); // Abstain vote

        // Advance past voting period
        advanceTimeForVotingPeriod();

        // Verify state
        assertEq(
            uint8(governorA.state(proposalId)),
            uint8(IGovernor.ProposalState.Defeated)
        );

        // Verify quorum calculation
        uint256 actualQuorum = governorA.quorum(block.timestamp - 1);
        assertEq(actualQuorum, expectedQuorum, "Quorum calculation mismatch");
    }

    function test_ProposalWithQuorum() public {
        // Setup voting power to exceed quorum
        uint256 totalSupply = 1_000_000_000e18; // 1 billion tokens

        // Calculate required votes for quorum (QUORUM_FRACTION = 4%)
        uint256 quorumAmount = (totalSupply * QUORUM_FRACTION) / 100;

        // Give alice enough tokens to meet quorum
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(
            alice,
            quorumAmount + governorA.proposalThreshold()
        );
        vm.stopPrank();

        // Delegate voting power
        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        // Create proposal
        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        // Wait for voting to start
        advanceTimeForVotingDelay();

        // Vote in favor
        vm.prank(alice);
        governorA.castVote(proposalId, 1); // Vote in favor

        // Wait for voting to end
        advanceTimeForVotingPeriod();

        // Get proposal votes (returns againstVotes, forVotes, abstainVotes)
        (
            uint256 againstVotes,
            uint256 forVotes,
            uint256 abstainVotes
        ) = governorA.proposalVotes(proposalId);

        // Verify proposal succeeded
        assertEq(
            uint8(governorA.state(proposalId)),
            uint8(IGovernor.ProposalState.Succeeded),
            "Proposal should have succeeded"
        );

        // Additional verification
        uint256 requiredQuorum = governorA.quorum(block.timestamp - 1);
        assertTrue(
            forVotes >= requiredQuorum,
            "Votes should meet quorum requirement"
        );

        // Verify vote counts
        assertEq(
            forVotes,
            quorumAmount + governorA.proposalThreshold(),
            "For votes should match delegated amount"
        );
        assertEq(againstVotes, 0, "Against votes should be 0");
        assertEq(abstainVotes, 0, "Abstain votes should be 0");
    }

    function test_ProposalWithoutQuorum() public {
        // Setup voting power below quorum
        uint256 totalSupply = 100_000_000e18;
        uint256 quorumAmount = (totalSupply * QUORUM_FRACTION) / 100;
        uint256 belowQuorumAmount = quorumAmount - 1e18; // Just below quorum

        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, belowQuorumAmount);
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        // Create proposal
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        advanceTimeForVotingDelay();

        // Vote with power below quorum
        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        advanceTimeForVotingPeriod();

        // Check proposal was defeated (due to not meeting quorum)
        assertEq(
            uint8(governorA.state(proposalId)),
            uint8(IGovernor.ProposalState.Defeated)
        );
    }

    function test_UpdateQuorumNumerator() public {
        uint256 newQuorumNumerator = 6; // 6%

        address[] memory targets = new address[](1);
        targets[0] = address(governorA);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            governorA.updateQuorumNumerator.selector,
            newQuorumNumerator
        );
        string memory description = "Update quorum numerator to 6%";

        // Setup proposer with enough voting power
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.quorum(block.timestamp - 1));
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        // Create and execute proposal
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

        bytes32 descriptionHash = keccak256(bytes(description));
        governorA.queue(targets, values, calldatas, descriptionHash);

        advanceTimeForTimelockMinDelay();

        vm.expectEmit(true, true, true, true);
        emit QuorumNumeratorUpdated(QUORUM_FRACTION, newQuorumNumerator);
        governorA.execute(targets, values, calldatas, descriptionHash);

        assertEq(governorA.quorumNumerator(), newQuorumNumerator);
    }

    function testRevert_InvalidQuorumNumerator() public {
        uint256 invalidQuorumNumerator = 101; // Over 100%

        address[] memory targets = new address[](1);
        targets[0] = address(governorA);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            governorA.updateQuorumNumerator.selector,
            invalidQuorumNumerator
        );
        string memory description = "Update to invalid quorum numerator";

        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.quorum(block.timestamp - 1));
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

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

        bytes32 descriptionHash = keccak256(bytes(description));
        governorA.queue(targets, values, calldatas, descriptionHash);

        advanceTimeForTimelockMinDelay();

        vm.expectRevert(
            abi.encodeWithSelector(
                GovernorVotesQuorumFraction
                    .GovernorInvalidQuorumFraction
                    .selector,
                invalidQuorumNumerator,
                100
            )
        );
        governorA.execute(targets, values, calldatas, descriptionHash);
    }
}
