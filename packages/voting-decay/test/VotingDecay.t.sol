// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "../src/VotingDecayLibrary.sol";
import "../src/VotingDecayManager.sol";

contract VotingDecayTest is Test {
    VotingDecayManager internal decayManager;
    address internal user = address(1);
    address internal delegate = address(2);
    uint256 internal constant INITIAL_VOTING_POWER = 1000e18;
    uint256 internal constant DECAY_RATE = 0.1e27; // 10% per year

    function setUp() public {
        decayManager = new VotingDecayManager();
        decayManager.setDecayRate(user, DECAY_RATE);
    }

    function test_InitialDecayIndex() public view {
        assertEq(decayManager.getCurrentDecayIndex(user), VotingDecayLibrary.RAY);
    }

    function test_DecayOverOneYear() public {
        // Fast forward one year
        vm.warp(block.timestamp + 365 days);

        uint256 expectedDecayIndex = 0.9e27; // 90% of initial
        assertApproxEqAbs(decayManager.getCurrentDecayIndex(user), expectedDecayIndex, 1e25);
    }

    function test_UpdateDecayIndex() public {
        // Fast forward 6 months
        vm.warp(block.timestamp + 182 days);

        decayManager.refreshDecay(user);

        assertEq(decayManager.getCurrentDecayIndex(user), VotingDecayLibrary.RAY);
    }

    function test_ResetDecay() public {
        // Fast forward 6 months
        vm.warp(block.timestamp + 182 days);

        decayManager.refreshDecay(user);

        assertEq(decayManager.getCurrentDecayIndex(user), VotingDecayLibrary.RAY);
    }

    function test_SetDecayRate() public {
        uint256 newRate = 0.2e27; // 20% per year
        decayManager.setDecayRate(user, newRate);

        assertEq(decayManager.getDecayRate(user), newRate);

        // Fast-forward and check the decay index
        vm.warp(block.timestamp + 365 days);
        uint256 expectedDecayIndex = 0.8e27; // 80% of initial
        assertApproxEqAbs(decayManager.getCurrentDecayIndex(user), expectedDecayIndex, 1e25);
    }

    function testFail_SetInvalidDecayRate() public {
        uint256 invalidRate = 1.1e27; // 110% per year
        decayManager.setDecayRate(user, invalidRate);
    }

    function test_Delegate() public {
        decayManager.setDecayRate(delegate, DECAY_RATE);
        decayManager.delegate(user, delegate);

        assertEq(decayManager.getCurrentDecayIndex(user), decayManager.getCurrentDecayIndex(delegate));
    }

    function test_Undelegate() public {
        decayManager.setDecayRate(delegate, DECAY_RATE);
        decayManager.delegate(user, delegate);

        // Fast forward 6 months
        vm.warp(block.timestamp + 182 days);

        decayManager.undelegate(user);

        assertEq(decayManager.getCurrentDecayIndex(user), VotingDecayLibrary.RAY); // Reset to full voting power
        assertApproxEqAbs(decayManager.getCurrentDecayIndex(delegate), 0.95e27, 1e25);
    }

    function test_ApplyDecayToVotingPower() public {
        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);

        uint256 decayedVotingPower = decayManager.getVotingPower(user, INITIAL_VOTING_POWER);
        uint256 expectedDecayedVotingPower = (INITIAL_VOTING_POWER * 9) / 10;
        assertApproxEqAbs(decayedVotingPower, expectedDecayedVotingPower, 1e18);
    }

    function test_SetDecayFreeWindow() public {
        uint256 decayFreeWindow = 30 days;
        decayManager.setDecayFreeWindow(user, decayFreeWindow);

        // Fast forward 29 days (within decay-free window)
        vm.warp(block.timestamp + 29 days);
        assertEq(decayManager.getCurrentDecayIndex(user), VotingDecayLibrary.RAY);

        // Fast forward another 30 days (outside decay-free window)
        vm.warp(block.timestamp + 30 days);
        assertLt(decayManager.getCurrentDecayIndex(user), VotingDecayLibrary.RAY);
    }
}
