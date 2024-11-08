// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {VotingDecayLibrary} from "../src/VotingDecayLibrary.sol";

contract VotingDecayTest is Test {
    using VotingDecayLibrary for VotingDecayLibrary.DecayState;

    VotingDecayLibrary.DecayState internal state;
    address internal user = address(0x1);
    address internal delegate = address(0x2);
    address internal owner = address(0x3);
    address internal refresher = address(0x4);
    uint256 internal constant INITIAL_VALUE = 1000e18;
    uint40 internal constant INITIAL_DECAY_FREE_WINDOW = 30 days;
    // Define decay rate per second
    // 0.1e18 per year is approximately 3.168808781402895e9 per second
    // (0.1e18 / (365 * 24 * 60 * 60))
    uint256 internal constant INITIAL_DECAY_RATE = 3.1709792e9; // ~10% per year

    function setUp() public {
        state.initialize(
            INITIAL_DECAY_FREE_WINDOW,
            INITIAL_DECAY_RATE,
            VotingDecayLibrary.DecayFunction.Linear
        );

        vm.label(user, "User");
        vm.label(delegate, "Delegate");
        vm.label(owner, "Owner");
        vm.label(refresher, "Refresher");
    }

    function _getDelegateTo(address account) internal pure returns (address) {
        return account;
    }

    function test_InitialRetentionFactor() public {
        state.resetDecay(user);
        assertEq(
            state.getDecayFactor(user, _getDelegateTo),
            VotingDecayLibrary.WAD
        );
    }

    function test_DecayOverOneYear() public {
        state.resetDecay(user);

        // Fast forward one year
        vm.warp(block.timestamp + 365 days);

        uint256 expectedRetentionFactor = 0.9e18; // 90% of initial
        assertApproxEqAbs(
            state.getDecayFactor(user, _getDelegateTo),
            expectedRetentionFactor,
            1e25
        );
    }

    function test_SetDecayRatePerSecond() public {
        state.resetDecay(user);

        uint256 newRate = uint256(2e17) / (365 * 24 * 60 * 60); // 20% per year
        vm.prank(owner);
        state.setDecayRatePerSecond(newRate);

        assertEq(state.decayRatePerSecond, newRate);

        // Fast-forward and check the retention factor
        vm.warp(block.timestamp + 365 days);
        uint256 expectedRetentionFactor = 0.817e18; // 81.7% of initial
        assertApproxEqAbs(
            state.getDecayFactor(user, _getDelegateTo),
            expectedRetentionFactor,
            1e16
        );
    }

    function testFail_SetInvalidDecayRate() public {
        uint256 invalidRate = 1.1e27; // 110% per year
        vm.prank(owner);
        state.setDecayRatePerSecond(invalidRate);
    }

    function test_ApplyDecayToValue() public {
        state.resetDecay(user);

        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);

        uint256 decayedVotingPower = state.getVotingPower(
            user,
            INITIAL_VALUE,
            _getDelegateTo
        );
        uint256 expectedDecayedVotingPower = 908e18; // 90.8% of initial
        assertApproxEqAbs(decayedVotingPower, expectedDecayedVotingPower, 1e18);
    }

    function test_SetDecayFreeWindow() public {
        state.resetDecay(user);

        uint40 newDecayFreeWindow = 60 days;

        vm.prank(owner);
        state.setDecayFreeWindow(newDecayFreeWindow);

        // Fast forward 59 days (within decay-free window)
        vm.warp(block.timestamp + 59 days);
        assertEq(
            state.getDecayFactor(user, _getDelegateTo),
            VotingDecayLibrary.WAD
        );

        // Fast forward another 2 days (outside decay-free window)
        vm.warp(block.timestamp + 2 days);
        assertLt(
            state.getDecayFactor(user, _getDelegateTo),
            VotingDecayLibrary.WAD
        );
    }
}
