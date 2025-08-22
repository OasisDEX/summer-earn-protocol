// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerGovernorV2TestBase} from "./SummerGovernorV2TestBase.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {console} from "forge-std/console.sol";
contract SummerGovernorCountingTest2 is SummerGovernorV2TestBase {
    // Test basic vote counting mode
    function test_CountingMode() public view {
        assertEq(governorA.COUNTING_MODE(), "support=bravo&quorum=for,abstain");
    }

    // Test vote types (Against = 0, For = 1, Abstain = 2)
    function test_VoteTypes() public {
        uint256 proposalId = _createTestProposal();

        // Setup voters with different voting weights
        address voter1 = address(0x1);
        address voter2 = address(0x2);
        address voter3 = address(0x3);

        stakeAndGetXSumr(voter1, 100e18, true);
        stakeAndGetXSumr(voter2, 200e18, true);
        stakeAndGetXSumr(voter3, 300e18, true);

        // Delegate voting power
        vm.prank(voter1);
        axSumr.delegate(voter1);
        vm.prank(voter2);
        axSumr.delegate(voter2);
        vm.prank(voter3);
        axSumr.delegate(voter3);
        advanceTimeAndBlock();

        advanceTimeForVotingDelay();

        // Cast different types of votes
        vm.prank(voter1);
        governorA.castVote(
            proposalId,
            uint8(GovernorCountingSimple.VoteType.Against)
        );
        vm.prank(voter2);
        governorA.castVote(
            proposalId,
            uint8(GovernorCountingSimple.VoteType.For)
        );
        vm.prank(voter3);
        governorA.castVote(
            proposalId,
            uint8(GovernorCountingSimple.VoteType.Abstain)
        );

        // Check vote counts
        (
            uint256 againstVotes,
            uint256 forVotes,
            uint256 abstainVotes
        ) = governorA.proposalVotes(proposalId);
        assertEq(againstVotes, 100e18);
        assertEq(forVotes, 200e18);
        assertEq(abstainVotes, 300e18);
    }

    // Test quorum calculation (forVotes + abstainVotes)
    function test_QuorumCalculation() public {
        uint256 proposalId = _createTestProposal();

        // Setup voter with enough voting power
        address voter = address(0x1);
        uint256 quorumVotes = governorA.quorum(block.timestamp - 1);

        stakeAndGetXSumr(voter, quorumVotes, true);
        vm.prank(voter);
        axSumr.delegate(voter);

        advanceTimeAndBlock();
        advanceTimeForVotingDelay();

        // Cast abstain vote
        vm.prank(voter);
        governorA.castVote(
            proposalId,
            uint8(GovernorCountingSimple.VoteType.Abstain)
        );

        advanceTimeForVotingPeriod();

        // Abstain votes count towards quorum
        assertTrue(
            governorA.state(proposalId) == IGovernor.ProposalState.Defeated
        );

        //Additional verification through vote counts
        (, , uint256 abstainVotes) = governorA.proposalVotes(proposalId);
        assertTrue(abstainVotes >= governorA.quorum(block.timestamp - 1));
    }

    // Test vote success conditions (forVotes > againstVotes)
    function test_VoteSucceeded2() public {
        uint256 proposalId = _createTestProposal();

        // Setup voters
        address forVoter = address(0x1);
        address abstainVoter = address(0x2);
        uint256 quorumVotes = governorA.quorum(block.timestamp - 1);

        stakeAndGetXSumr(forVoter, ((5 * quorumVotes) / 5) - 1, true);
        stakeAndGetXSumr(abstainVoter, (2 * quorumVotes) / 5, true);

        vm.prank(forVoter);
        axSumr.delegate(forVoter);
        vm.prank(abstainVoter);
        axSumr.delegate(abstainVoter);

        uint256 forVotes = axSumr.getVotes(forVoter);
        uint256 abstainVotes = axSumr.getVotes(abstainVoter);

        assertTrue(
            forVotes > abstainVotes,
            "forVotes should be greater than abstainVotes"
        );
        assertTrue(
            forVotes + abstainVotes > quorumVotes,
            "forVotes + abstainVotes should be greater than quorumVotes"
        );

        advanceTimeAndBlock();
        advanceTimeForVotingDelay();

        // Cast votes
        vm.prank(forVoter);
        governorA.castVote(
            proposalId,
            uint8(GovernorCountingSimple.VoteType.For)
        );

        vm.prank(abstainVoter);
        governorA.castVote(
            proposalId,
            uint8(GovernorCountingSimple.VoteType.Abstain)
        );

        advanceTimeForVotingPeriod();
        advanceTimeAndBlock();

        assertTrue(
            governorA.state(proposalId) == IGovernor.ProposalState.Succeeded
        );
    }

    // Test double voting prevention
    function testRevert_DoubleVoting() public {
        uint256 proposalId = _createTestProposal();

        address voter = address(0x1);
        stakeAndGetXSumr(voter, 100e18, true);

        vm.prank(voter);
        axSumr.delegate(voter);
        advanceTimeAndBlock();

        advanceTimeForVotingDelay();

        vm.startPrank(voter);
        governorA.castVote(
            proposalId,
            uint8(GovernorCountingSimple.VoteType.For)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IGovernor.GovernorAlreadyCastVote.selector,
                voter
            )
        );
        governorA.castVote(
            proposalId,
            uint8(GovernorCountingSimple.VoteType.Against)
        );
        vm.stopPrank();
    }

    // Test invalid vote type
    function testRevert_InvalidVoteType() public {
        uint256 proposalId = _createTestProposal();

        address voter = address(0x1);
        stakeAndGetXSumr(voter, 100e18, true);

        vm.prank(voter);
        axSumr.delegate(voter);
        advanceTimeAndBlock();

        advanceTimeForVotingDelay();

        vm.prank(voter);
        vm.expectRevert(IGovernor.GovernorInvalidVoteType.selector);
        governorA.castVote(proposalId, 3); // Invalid vote type
    }

    // Helper function to create a test proposal
    function _createTestProposal() internal returns (uint256) {
        address[] memory targets = new address[](1);
        targets[0] = address(0x1);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";
        string memory description = "Test Proposal";

        stakeAndGetXSumr(alice, governorA.proposalThreshold(), true);

        vm.prank(alice);
        axSumr.delegate(alice);
        advanceTimeAndBlock();

        vm.prank(alice);
        return governorA.propose(targets, values, calldatas, description);
    }
}
