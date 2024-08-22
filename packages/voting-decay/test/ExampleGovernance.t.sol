// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "./ExampleGovernance.sol";

contract ExampleGovernanceTest is Test {
    ExampleGovernance public governance;
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public governor = address(0x3);
    uint256 public constant INITIAL_VALUE = 100e18;

    function setUp() public {
        vm.prank(governor);
        governance = new ExampleGovernance();

        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(governor, "Governor");
    }

    function test_RegisterVoter() public {
        vm.prank(alice);
        governance.registerVoter(INITIAL_VALUE);

        (uint256 baseValue, bool isRegistered) = governance.voters(alice);
        assertEq(baseValue, INITIAL_VALUE);
        assertTrue(isRegistered);
    }

    function test_Voting() public {
        vm.startPrank(alice);
        governance.registerVoter(INITIAL_VALUE);
        uint256 proposalId = governance.createProposal();
        governance.vote(proposalId);
        vm.stopPrank();

        assertEq(governance.proposalVotes(proposalId), INITIAL_VALUE);
        assertTrue(governance.hasVoted(proposalId, alice));
    }

    function test_ValueDecay() public {
        vm.startPrank(alice);
        governance.registerVoter(INITIAL_VALUE);
        uint256 initialValue = governance.getAggregateValue(alice);
        assertEq(initialValue, INITIAL_VALUE);

        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);

        uint256 decayedValue = governance.getAggregateValue(alice);
        assertLt(decayedValue, initialValue);
        assertGt(decayedValue, 0);
        vm.stopPrank();
    }

    function test_Delegation() public {
        vm.prank(alice);
        governance.registerVoter(INITIAL_VALUE);

        vm.prank(bob);
        governance.registerVoter(INITIAL_VALUE);

        vm.prank(alice);
        governance.delegate(bob);

        VotingDecayLibrary.DecayInfo memory aliceInfo = governance.getDecayInfo(alice);

        assertEq(aliceInfo.delegateTo, bob);
        assertEq(governance.getAggregateValue(bob), INITIAL_VALUE * 2);
    }

    function test_UpdateBaseValue() public {
        vm.startPrank(alice);
        governance.registerVoter(INITIAL_VALUE);
        uint256 newValue = INITIAL_VALUE * 2;
        governance.updateBaseValue(newValue);
        vm.stopPrank();

        (uint256 baseValue, ) = governance.voters(alice);
        assertEq(baseValue, newValue);
    }

    function test_SetDecayRate() public {
        vm.startPrank(governor);
        governance.registerVoter(INITIAL_VALUE);
        // Set a 5% annual decay rate
        uint256 newDecayRate = (uint256(1e18) / 20) / (365 * 24 * 60 * 60);
        governance.setDecayRatePerSecond(newDecayRate);
        vm.stopPrank();

        uint256 decayRatePerSecond = governance.decayManager().decayRatePerSecond();
        assertEq(decayRatePerSecond, newDecayRate);
    }

    function test_SetDecayFreeWindow() public {
        vm.startPrank(governor);
        governance.registerVoter(INITIAL_VALUE);
        uint40 newWindow = 60 days;
        governance.setDecayFreeWindow(newWindow);
        vm.stopPrank();

        uint40 decayFreeWindow = governance.decayManager().decayFreeWindow();
        assertEq(decayFreeWindow, newWindow);
    }

    function test_SetDecayFunction() public {
        vm.startPrank(governor);
        governance.registerVoter(INITIAL_VALUE);
        governance.setDecayFunction(VotingDecayLibrary.DecayFunction.Exponential);
        vm.stopPrank();

        VotingDecayLibrary.DecayFunction decayFunction = governance.decayManager().decayFunction();
        assertEq(uint8(decayFunction), uint8(VotingDecayLibrary.DecayFunction.Exponential));
    }

    function test_CompareDecayFunctions() public {
        vm.startPrank(governor);
        governance.registerVoter(INITIAL_VALUE);

        // Set linear decay
        governance.setDecayFunction(VotingDecayLibrary.DecayFunction.Linear);
        vm.warp(block.timestamp + 365 days);
        uint256 linearDecayedValue = governance.getAggregateValue(governor);

        console.log("COMPARE");
        console.log(linearDecayedValue);
        // Reset decay and set exponential decay
        governance.refreshDecay();
        governance.setDecayFunction(VotingDecayLibrary.DecayFunction.Exponential);
        vm.warp(block.timestamp + 365 days);
        uint256 exponentialDecayedValue = governance.getAggregateValue(governor);

        vm.stopPrank();

        // Exponential decay should result in a higher value than linear decay after one year
        assertGt(exponentialDecayedValue, linearDecayedValue);
    }
}
