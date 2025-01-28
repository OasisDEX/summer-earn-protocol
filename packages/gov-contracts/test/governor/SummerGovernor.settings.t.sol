// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerGovernorTestBase} from "./SummerGovernorTestBase.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

contract SummerGovernorSettingsTest is SummerGovernorTestBase {
    // Add events at contract level
    event VotingDelaySet(uint256 oldVotingDelay, uint256 newVotingDelay);
    event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);
    event ProposalThresholdSet(
        uint256 oldProposalThreshold,
        uint256 newProposalThreshold
    );

    function test_InitialSettings() public view {
        assertEq(governorA.votingDelay(), VOTING_DELAY);
        assertEq(governorA.votingPeriod(), VOTING_PERIOD);
        assertEq(governorA.proposalThreshold(), PROPOSAL_THRESHOLD);
    }

    function test_UpdateVotingDelay() public {
        uint48 newVotingDelay = 2 days;

        // Create proposal to update voting delay
        address[] memory targets = new address[](1);
        targets[0] = address(governorA);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            governorA.setVotingDelay.selector,
            newVotingDelay
        );
        string memory description = "Update voting delay";

        // Setup proposer
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.proposalThreshold());
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

        // Give enough tokens for quorum
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.quorum(block.timestamp - 1));
        vm.stopPrank();

        advanceTimeForVotingDelay();
        vm.prank(alice);
        governorA.castVote(proposalId, 1);
        advanceTimeForVotingPeriod();

        bytes32 descriptionHash = keccak256(bytes(description));
        governorA.queue(targets, values, calldatas, descriptionHash);
        advanceTimeForTimelockMinDelay();

        vm.expectEmit(true, true, true, true);
        emit VotingDelaySet(VOTING_DELAY, newVotingDelay);

        governorA.execute(targets, values, calldatas, descriptionHash);

        assertEq(governorA.votingDelay(), newVotingDelay);
    }

    function test_UpdateVotingPeriod() public {
        uint32 newVotingPeriod = 1 weeks;

        // Create proposal to update voting period
        address[] memory targets = new address[](1);
        targets[0] = address(governorA);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            governorA.setVotingPeriod.selector,
            newVotingPeriod
        );
        string memory description = "Update voting period";

        // Setup proposer
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

        // Give enough tokens for quorum
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.quorum(block.timestamp - 1));
        vm.stopPrank();

        advanceTimeForVotingDelay();

        // Vote
        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        advanceTimeForVotingPeriod();

        bytes32 descriptionHash = keccak256(bytes(description));

        // Queue the proposal
        governorA.queue(targets, values, calldatas, descriptionHash);

        advanceTimeForTimelockMinDelay();

        // Execute the proposal
        vm.expectEmit(true, true, true, true);
        emit VotingPeriodSet(VOTING_PERIOD, newVotingPeriod);
        governorA.execute(targets, values, calldatas, descriptionHash);

        assertEq(governorA.votingPeriod(), newVotingPeriod);
    }

    function test_UpdateProposalThreshold() public {
        uint256 newProposalThreshold = 200_000e18;

        // Create proposal to update threshold
        address[] memory targets = new address[](1);
        targets[0] = address(governorA);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            governorA.setProposalThreshold.selector,
            newProposalThreshold
        );
        string memory description = "Update proposal threshold";

        // Setup proposer
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

        // Give enough tokens for quorum
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.quorum(block.timestamp - 1));
        vm.stopPrank();

        advanceTimeForVotingDelay();

        // Vote
        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        advanceTimeForVotingPeriod();

        bytes32 descriptionHash = keccak256(bytes(description));

        // Queue the proposal
        governorA.queue(targets, values, calldatas, descriptionHash);

        advanceTimeForTimelockMinDelay();

        // Execute the proposal
        vm.expectEmit(true, true, true, true);
        emit ProposalThresholdSet(PROPOSAL_THRESHOLD, newProposalThreshold);
        governorA.execute(targets, values, calldatas, descriptionHash);

        assertEq(governorA.proposalThreshold(), newProposalThreshold);
    }

    function testRevert_ZeroVotingPeriod() public {
        uint32 newVotingPeriod = 0;

        // Create proposal to update voting period
        address[] memory targets = new address[](1);
        targets[0] = address(governorA);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            governorA.setVotingPeriod.selector,
            newVotingPeriod
        );
        string memory description = "Update voting period to zero";

        // Setup proposer
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

        // Give enough tokens for quorum
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.quorum(block.timestamp - 1));
        vm.stopPrank();

        advanceTimeForVotingDelay();

        // Vote
        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        advanceTimeForVotingPeriod();

        bytes32 descriptionHash = keccak256(bytes(description));

        // Queue the proposal
        governorA.queue(targets, values, calldatas, descriptionHash);

        advanceTimeForTimelockMinDelay();

        // Should revert on execution with GovernorInvalidVotingPeriod
        vm.expectRevert(
            abi.encodeWithSelector(
                IGovernor.GovernorInvalidVotingPeriod.selector,
                0
            )
        );
        governorA.execute(targets, values, calldatas, descriptionHash);
    }

    function testRevert_DirectSettingsUpdate() public {
        vm.startPrank(alice);

        vm.expectRevert(
            abi.encodeWithSelector(
                IGovernor.GovernorOnlyExecutor.selector,
                alice
            )
        );
        governorA.setVotingDelay(2 days);

        vm.expectRevert(
            abi.encodeWithSelector(
                IGovernor.GovernorOnlyExecutor.selector,
                alice
            )
        );
        governorA.setVotingPeriod(1 weeks);

        vm.expectRevert(
            abi.encodeWithSelector(
                IGovernor.GovernorOnlyExecutor.selector,
                alice
            )
        );
        governorA.setProposalThreshold(200_000e18);

        vm.stopPrank();
    }
}
