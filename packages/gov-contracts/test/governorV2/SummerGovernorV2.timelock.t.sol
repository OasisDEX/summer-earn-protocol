// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerGovernorV2TestBase} from "./SummerGovernorV2TestBase.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {TimelockGuard} from "../../src/contracts/misc/TimelockGuard.sol";
import {console} from "forge-std/console.sol";

contract SummerGovernorTimelockTest is SummerGovernorV2TestBase {
    event TimelockChange(address oldTimelock, address newTimelock);

    function test_TimelockStateTransitions2() public {
        // Setup voter with enough tokens
        uint quorum = governorA.quorum(block.timestamp - 1);
        stakeAndGetXSumr(alice, quorum, true);

        vm.prank(alice);
        axSumr.delegate(alice);
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
            uint256(IGovernor.ProposalState.Active),
            "aaasssssssaa"
        );

        advanceTimeForVotingPeriod();

        // Check state after voting ends (should be Succeeded)
        assertEq(
            uint256(governorA.state(proposalId)),
            uint256(IGovernor.ProposalState.Succeeded),
            "aaasssssssaxxxxa"
        );

        // Queue the proposal
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,

        ) = createProposalParams(address(testToken));

        governorA.queue(targets, values, calldatas, descriptionHash);

        // Check state after queueing
        assertEq(
            uint256(governorA.state(proposalId)),
            uint256(IGovernor.ProposalState.Queued),
            "aaassssaa"
        );

        advanceTimeForTimelockMinDelay();

        // Execute
        governorA.execute(targets, values, calldatas, descriptionHash);

        // Check final state
        assertEq(
            uint256(governorA.state(proposalId)),
            uint256(IGovernor.ProposalState.Executed),
            "aaaaa"
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
        stakeAndGetXSumr(alice, governorA.proposalThreshold(), true);

        vm.prank(alice);
        axSumr.delegate(alice);
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
        stakeAndGetXSumr(alice, governorA.quorum(block.timestamp - 1), true);

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

    function test_QueueAndExecuteWithDelay2() public {
        // Setup voter
        stakeAndGetXSumr(alice, governorA.quorum(block.timestamp - 1), true);

        vm.prank(alice);
        axSumr.delegate(alice);
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

        ) = createProposalParams(address(testToken));

        uint256 queueTime = block.timestamp;
        governorA.queue(targets, values, calldatas, descriptionHash);

        //Try to execute immediately (should fail)
        bytes32 operationId = timelockA.hashOperationBatch(
            targets,
            values,
            calldatas,
            0, // predecessor
            bytes20(address(governorA)) ^ descriptionHash // salt
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                TimelockController.TimelockUnexpectedOperationState.selector,
                operationId,
                bytes32(1 << uint8(TimelockController.OperationState.Ready)) // Expect Ready state
            )
        );
        governorA.execute(targets, values, calldatas, descriptionHash);

        // Advance time but not quite enough
        vm.warp(queueTime + timelockA.getMinDelay() - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                TimelockController.TimelockUnexpectedOperationState.selector,
                operationId,
                bytes32(1 << uint8(TimelockController.OperationState.Ready)) // Expect Ready state
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

    function test_QueueAndExecuteWithTimelockGuard() public {
        // Setup voter
        stakeAndGetXSumr(alice, governorA.quorum(block.timestamp - 1), true);

        vm.prank(alice);
        axSumr.delegate(alice);
        advanceTimeAndBlock();

        // Deploy TimelockGuard with a minimum timestamp in the future
        uint256 currentTime = block.timestamp;
        uint256 minDelay = timelockA.getMinDelay();
        uint256 guardMinimumTimestamp = currentTime + minDelay + 10 days; // Additional 10 days buffer

        TimelockGuard guard = new TimelockGuard(guardMinimumTimestamp);

        // Mint tokens to timelock so they can be transferred
        deal(address(testToken), address(timelockA), 1000);

        // Create proposal with two calls:
        // 1. Validate timestamp using TimelockGuard
        // 2. Execute the actual action (transfer tokens)
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory calldatas = new bytes[](2);

        // First call: validate timestamp
        targets[0] = address(guard);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(
            TimelockGuard.validateTimestamp.selector
        );

        // Second call: transfer tokens
        targets[1] = address(testToken);
        values[1] = 0;
        calldatas[1] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            bob,
            100
        );

        string
            memory description = "Transfer tokens with TimelockGuard validation";

        // Create proposal
        vm.prank(alice);
        uint256 proposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );
        bytes32 descriptionHash = keccak256(bytes(description));

        advanceTimeForVotingDelay();

        // Vote
        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        advanceTimeForVotingPeriod();

        // Queue the proposal
        uint256 queueTime = block.timestamp;
        governorA.queue(targets, values, calldatas, descriptionHash);

        // Advance time to meet timelock delay but NOT the guard's minimum timestamp
        vm.warp(queueTime + minDelay);

        // Try to execute - should fail because guard's minimum timestamp hasn't been reached
        bytes32 operationId = timelockA.hashOperationBatch(
            targets,
            values,
            calldatas,
            0, // predecessor
            bytes20(address(governorA)) ^ descriptionHash // salt
        );

        // First, check that timelock allows execution (state is Ready)
        // But execution should revert due to TimelockGuard validation
        vm.expectRevert(TimelockGuard.TimelockGuard__TooEarly.selector);
        governorA.execute(targets, values, calldatas, descriptionHash);

        // Advance time to meet both timelock delay AND guard's minimum timestamp
        vm.warp(guardMinimumTimestamp);

        // Now execution should succeed
        governorA.execute(targets, values, calldatas, descriptionHash);

        // Verify proposal state
        assertEq(
            uint256(governorA.state(proposalId)),
            uint256(IGovernor.ProposalState.Executed)
        );

        // Verify the actual action was executed (tokens were transferred)
        assertEq(testToken.balanceOf(bob), 100);
    }
}
