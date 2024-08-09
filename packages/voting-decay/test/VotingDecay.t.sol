// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "../src/VotingDecayLibrary.sol";
import "../src/VotingDecayManager.sol";

/*
 * @title VotingDecayTest
 * @notice Test contract for the VotingDecayManager functionality
 * @dev Uses Forge's Test contract for assertions and utilities
 */
contract VotingDecayTest is Test {
    VotingDecayManager internal decayManager;
    address internal user = address(1);
    address internal delegate = address(2);
    address internal newOwner = address(3);
    uint256 internal constant INITIAL_VOTING_POWER = 1000e18;
    uint256 internal constant DECAY_RATE = 0.1e27; // 10% per year

    /*
     * @notice Sets up the test environment before each test
     * @dev Deploys a new VotingDecayManager and sets an initial decay rate
     */
    function setUp() public {
        decayManager = new VotingDecayManager();
        decayManager.setDecayRate(user, DECAY_RATE);
    }

    /*
     * @notice Tests that the initial decay index is set correctly
     */
    function test_InitialDecayIndex() public view {
        assertEq(
            decayManager.getCurrentDecayIndex(user),
            VotingDecayLibrary.RAY
        );
    }

    /*
     * @notice Tests the decay calculation over a one-year period
     */
    function test_DecayOverOneYear() public {
        // Fast forward one year
        vm.warp(block.timestamp + 365 days);

        uint256 expectedDecayIndex = 0.9e27; // 90% of initial
        assertApproxEqAbs(
            decayManager.getCurrentDecayIndex(user),
            expectedDecayIndex,
            1e25
        );
    }

    /*
     * @notice Tests the update of decay index after refreshing
     */
    function test_UpdateDecayIndex() public {
        // Fast forward 6 months
        vm.warp(block.timestamp + 182 days);

        vm.prank(newOwner);

        decayManager.updateDecay(user);

        assertEq(
            decayManager.getCurrentDecayIndex(user),
            VotingDecayLibrary.RAY
        );
    }

    /*
     * @notice Tests the reset of decay index
     */
    function test_ResetDecay() public {
        decayManager.setAuthorizedRefresher(newOwner, true);

        // Fast forward 6 months
        vm.warp(block.timestamp + 182 days);

        vm.prank(newOwner);
        decayManager.resetDecay(user);

        assertEq(
            decayManager.getCurrentDecayIndex(user),
            VotingDecayLibrary.RAY
        );
    }

    /*
     * @notice Tests setting a new decay rate and its effect on the decay index
     */
    function test_SetDecayRate() public {
        uint256 newRate = 0.2e27; // 20% per year
        decayManager.setDecayRate(user, newRate);

        assertEq(decayManager.getDecayRate(user), newRate);

        // Fast-forward and check the decay index
        vm.warp(block.timestamp + 365 days);
        uint256 expectedDecayIndex = 0.8e27; // 80% of initial
        assertApproxEqAbs(
            decayManager.getCurrentDecayIndex(user),
            expectedDecayIndex,
            1e25
        );
    }

    /*
     * @notice Tests that setting an invalid decay rate fails
     */
    function testFail_SetInvalidDecayRate() public {
        uint256 invalidRate = 1.1e27; // 110% per year
        decayManager.setDecayRate(user, invalidRate);
    }

    /*
     * @notice Tests the delegation of voting power
     */
    function test_Delegate() public {
        decayManager.setDecayRate(delegate, DECAY_RATE);
        decayManager.delegate(user, delegate);

        assertEq(
            decayManager.getCurrentDecayIndex(user),
            decayManager.getCurrentDecayIndex(delegate)
        );
    }

    /*
     * @notice Tests the undelegation of voting power
     */
    function test_Undelegate() public {
        decayManager.setDecayRate(delegate, DECAY_RATE);
        decayManager.delegate(user, delegate);

        // Fast forward 6 months
        vm.warp(block.timestamp + 182 days);

        decayManager.undelegate(user);

        assertEq(
            decayManager.getCurrentDecayIndex(user),
            VotingDecayLibrary.RAY
        ); // Reset to full voting power
        assertApproxEqAbs(
            decayManager.getCurrentDecayIndex(delegate),
            0.95e27,
            1e25
        );
    }

    /*
     * @notice Tests the application of decay to voting power
     */
    function test_ApplyDecayToVotingPower() public {
        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);

        uint256 decayedVotingPower = decayManager.getVotingPower(
            user,
            INITIAL_VOTING_POWER
        );
        uint256 expectedDecayedVotingPower = (INITIAL_VOTING_POWER * 9) / 10;
        assertApproxEqAbs(decayedVotingPower, expectedDecayedVotingPower, 1e18);
    }

    /*
     * @notice Tests setting and using a decay-free window
     */
    function test_SetDecayFreeWindow() public {
        uint256 decayFreeWindow = 30 days;
        decayManager.setDecayFreeWindow(user, decayFreeWindow);

        // Fast forward 29 days (within decay-free window)
        vm.warp(block.timestamp + 29 days);
        assertEq(
            decayManager.getCurrentDecayIndex(user),
            VotingDecayLibrary.RAY
        );

        // Fast forward another 30 days (outside decay-free window)
        vm.warp(block.timestamp + 30 days);
        assertLt(
            decayManager.getCurrentDecayIndex(user),
            VotingDecayLibrary.RAY
        );
    }
}
