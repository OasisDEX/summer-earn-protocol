// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerGovernorTestBase} from "./SummerGovernorTestBase.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract SummerGovernorTimelockTest is SummerGovernorTestBase {
    event TimelockChange(address oldTimelock, address newTimelock);

    function test_TimelockStateTransitions() public {
        // Setup voter with enough tokens
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.quorum(block.timestamp - 1));
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        // Create and pass proposal
        vm.prank(alice);
        (uint256 proposalId, bytes32 descriptionHash) = createProposal();

        // Check initial state
        assertEq(
            uint256(governorA.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending)
        );

        advanceTimeForVotingDelay();

        // Vote
        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        // Check state after voting starts
        assertEq(
            uint256(governorA.state(proposalId)),
            uint256(IGovernor.ProposalState.Active)
        );

        advanceTimeForVotingPeriod();

        // Check state after voting ends (should be Succeeded)
        assertEq(
            uint256(governorA.state(proposalId)),
            uint256(IGovernor.ProposalState.Succeeded)
        );

        // Queue the proposal
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,

        ) = createProposalParams(address(aSummerToken));

        governorA.queue(targets, values, calldatas, descriptionHash);

        // Check state after queueing
        assertEq(
            uint256(governorA.state(proposalId)),
            uint256(IGovernor.ProposalState.Queued)
        );

        advanceTimeForTimelockMinDelay();

        // Execute
        governorA.execute(targets, values, calldatas, descriptionHash);

        // Check final state
        assertEq(
            uint256(governorA.state(proposalId)),
            uint256(IGovernor.ProposalState.Executed)
        );
    }

    function test_TimelockAddressUpdate() public {
        // Deploy new timelock
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = address(governorA);
        executors[0] = address(0);

        TimelockController newTimelock = new TimelockController(
            1 days,
            proposers,
            executors,
            address(this)
        );

        // Create proposal to update timelock
        address[] memory targets = new address[](1);
        targets[0] = address(governorA);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            governorA.updateTimelock.selector,
            newTimelock
        );
        string memory description = "Update timelock controller";

        // Setup voter
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

        // Queue
        governorA.queue(targets, values, calldatas, descriptionHash);

        advanceTimeForTimelockMinDelay();

        // Execute
        vm.expectEmit(true, true, true, true);
        emit TimelockChange(address(timelockA), address(newTimelock));

        governorA.execute(targets, values, calldatas, descriptionHash);

        // Verify update
        assertEq(governorA.timelock(), address(newTimelock));
    }

    function test_QueueAndExecuteWithDelay() public {
        // Setup voter
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.quorum(block.timestamp - 1));
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        // Create proposal
        vm.prank(alice);
        (uint256 proposalId, bytes32 descriptionHash) = createProposal();

        advanceTimeForVotingDelay();

        // Vote
        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        advanceTimeForVotingPeriod();

        // Queue
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,

        ) = createProposalParams(address(aSummerToken));

        uint256 queueTime = block.timestamp;
        governorA.queue(targets, values, calldatas, descriptionHash);

        //Try to execute immediately (should fail)
        vm.expectRevert(
            abi.encodeWithSelector(
                TimelockController.TimelockUnexpectedOperationState.selector,
                bytes32(
                    0x7e6abb1e72b1f25d9128cead45603aeee47b9ae7443b55445810bb453ec24c33
                ),
                bytes32(1 << uint8(TimelockController.OperationState.Ready))
            )
        );
        governorA.execute(targets, values, calldatas, descriptionHash);

        // Advance time but not quite enough
        vm.warp(queueTime + timelockA.getMinDelay() - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                TimelockController.TimelockUnexpectedOperationState.selector,
                bytes32(
                    0x7e6abb1e72b1f25d9128cead45603aeee47b9ae7443b55445810bb453ec24c33
                ),
                bytes32(1 << uint8(TimelockController.OperationState.Ready))
            )
        );
        governorA.execute(targets, values, calldatas, descriptionHash);

        // Advance time to exactly the delay
        vm.warp(queueTime + timelockA.getMinDelay());

        // Now execution should succeed
        governorA.execute(targets, values, calldatas, descriptionHash);

        // Verify proposal state
        assertEq(
            uint256(governorA.state(proposalId)),
            uint256(IGovernor.ProposalState.Executed)
        );
    }
}
