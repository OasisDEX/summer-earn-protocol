// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerGovernorTestBase} from "./SummerGovernorTestBase.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract SummerGovernorOwnershipTest is SummerGovernorTestBase {
    function test_InitialOwnership() public view {
        // Verify that the timelock is the owner of the governor
        assertEq(governorA.owner(), address(timelockA));
        assertEq(governorB.owner(), address(timelockB));
    }

    function test_OnlyOwnerFunctions() public {
        // Test setPeer function (which is owner-protected)
        vm.startPrank(alice);

        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                alice
            )
        );
        governorA.setPeer(bEid, addressToBytes32(address(governorB)));

        vm.stopPrank();

        // Verify that owner (timelock) can call setPeer
        vm.prank(address(timelockA));
        governorA.setPeer(bEid, addressToBytes32(address(governorB)));
    }

    function test_OwnershipTransfer() public {
        address newOwner = address(0x123);

        // Create proposal to transfer ownership
        address[] memory targets = new address[](1);
        targets[0] = address(governorA);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            governorA.transferOwnership.selector,
            newOwner
        );
        string memory description = "Transfer governor ownership to new owner";

        // Setup voter with enough tokens
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.quorum(block.timestamp - 1));
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
        governorA.execute(targets, values, calldatas, descriptionHash);

        // Verify ownership was transferred
        assertEq(governorA.owner(), newOwner);
    }

    function testRevert_UnauthorizedOwnershipTransfer() public {
        address newOwner = address(0x123);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                alice
            )
        );
        governorA.transferOwnership(newOwner);
    }

    function testRevert_TransferOwnershipToZeroAddress() public {
        vm.prank(address(timelockA));
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableInvalidOwner.selector,
                address(0)
            )
        );
        governorA.transferOwnership(address(0));
    }
}
