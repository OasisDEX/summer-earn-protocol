// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "./ExampleGovernance.sol";

/*
 * @title ExampleGovernanceTest
 * @notice Test contract for ExampleGovernance
 */
contract ExampleGovernanceTest is Test {
    ExampleGovernance public governance;
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public governor = address(0x3);
    uint256 public constant INITIAL_VOTING_POWER = 100e18;

    /*
     * @notice Set up the test environment
     */
    function setUp() public {
        vm.prank(governor);
        governance = new ExampleGovernance();

        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(governor, "Governor");
    }

    /*
     * @notice Test voter registration
     */
    function test_RegisterVoter() public {
        vm.prank(alice);
        governance.registerVoter(INITIAL_VOTING_POWER);

        (uint256 baseVotingPower, bool isRegistered) = governance.voters(alice);
        assertEq(baseVotingPower, INITIAL_VOTING_POWER);
        assertTrue(isRegistered);
    }

    /*
     * @notice Test voting functionality
     */
    function test_Voting() public {
        vm.startPrank(alice);
        governance.registerVoter(INITIAL_VOTING_POWER);
        uint256 proposalId = governance.createProposal();
        governance.vote(proposalId);
        vm.stopPrank();

        assertEq(governance.proposalVotes(proposalId), INITIAL_VOTING_POWER);
        assertTrue(governance.hasVoted(proposalId, alice));
    }

    /*
     * @notice Test voting power decay over time
     */
    function test_VotingPowerDecay() public {
        vm.startPrank(alice);
        governance.registerVoter(INITIAL_VOTING_POWER);
        uint256 initialVotingPower = governance.getAggregateVotingPower(alice);
        assertEq(initialVotingPower, INITIAL_VOTING_POWER);

        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);

        uint256 decayedVotingPower = governance.getAggregateVotingPower(alice);
        assertLt(decayedVotingPower, initialVotingPower);
        assertGt(decayedVotingPower, 0);
        vm.stopPrank();
    }

    /*
     * @notice Test delegation of voting power
     */
    function test_Delegation() public {
        vm.prank(alice);
        governance.registerVoter(INITIAL_VOTING_POWER);

        vm.prank(bob);
        governance.registerVoter(INITIAL_VOTING_POWER);

        vm.prank(alice);
        governance.delegate(bob);

        VotingDecayLibrary.DecayInfo memory aliceInfo = governance.getDecayInfo(
            alice
        );

        assertEq(aliceInfo.delegateTo, bob);
        assertEq(
            governance.getAggregateVotingPower(bob),
            INITIAL_VOTING_POWER * 2
        );
    }

    /*
     * @notice Test updating voting power
     */
    function test_UpdateVotingPower() public {
        vm.startPrank(alice);
        governance.registerVoter(INITIAL_VOTING_POWER);
        uint256 newVotingPower = INITIAL_VOTING_POWER * 2;
        vm.stopPrank();

        vm.prank(alice);
        governance.updateVotingPower(newVotingPower);


        (uint256 baseVotingPower, ) = governance.voters(alice);
        assertEq(baseVotingPower, newVotingPower);
    }

    /*
     * @notice Test setting a new decay rate
     */
    function test_SetDecayRate() public {
        vm.startPrank(alice);
        governance.registerVoter(INITIAL_VOTING_POWER);
        uint256 newDecayRate = 0.05e27; // 5% annual decay
        governance.setDecayRate(newDecayRate);
        vm.stopPrank();

        uint256 decayRate = governance.decayManager().decayRate();
        assertEq(decayRate, newDecayRate);
    }

    /*
     * @notice Test setting a new decay-free window
     */
    function test_SetDecayFreeWindow() public {
        vm.startPrank(alice);
        governance.registerVoter(INITIAL_VOTING_POWER);
        uint40 newWindow = 60 days;
        governance.setDecayFreeWindow(newWindow);
        vm.stopPrank();

        uint40 decayFreeWindow = governance.decayManager().decayFreeWindow();
        assertEq(decayFreeWindow, newWindow);
    }
}
