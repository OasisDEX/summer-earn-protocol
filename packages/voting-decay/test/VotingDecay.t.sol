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

    /*
     * @notice Sets up the test environment before each test
     * @dev Deploys a new VotingDecayManager and sets an initial decay rate
     */
    function setUp() public {
        vm.prank(owner);
        decayManager = new VotingDecayManager(
            INITIAL_DECAY_FREE_WINDOW,
            INITIAL_DECAY_RATE,
            VotingDecayLibrary.DecayFunction.Linear,
            owner
        );

        vm.label(user, "User");
        vm.label(delegate, "Delegate");
        vm.label(owner, "Owner");
        vm.label(refresher, "Refresher");
    }

    /*
     * @notice Tests that the initial retention factor is set correctly
     */
    function test_InitialRetentionFactor() public {
        decayManager.initializeAccount(user);

        assertEq(
            decayManager.getCurrentRetentionFactor(user),
            VotingDecayLibrary.WAD
        );
    }

    /*
     * @notice Tests the decay calculation over a one-year period
     */
    function test_DecayOverOneYear() public {
        decayManager.initializeAccount(user);

        // Fast forward one year
        vm.warp(block.timestamp + 365 days);

        uint256 expectedRetentionFactor = 0.9e18; // 90% of initial
        assertApproxEqAbs(
            decayManager.getCurrentRetentionFactor(user),
            expectedRetentionFactor,
            1e25
        );
    }

    /*
     * @notice Tests the update of retention factor after refreshing
     */
    function test_UpdateRetentionFactor() public {
        decayManager.initializeAccount(user);
        // Fast forward 6 months
        vm.warp(block.timestamp + 182 days);

        vm.prank(owner);
        decayManager.updateDecay(user);

        assertLt(
            decayManager.getCurrentRetentionFactor(user),
            VotingDecayLibrary.WAD
        );
    }

    /*
     * @notice Tests the reset of retention factor
     */
    function test_ResetDecay() public {
        decayManager.initializeAccount(user);
        // Fast forward 6 months
        vm.warp(block.timestamp + 182 days);

        vm.prank(owner);
        decayManager.resetDecay(user);

        assertEq(
            decayManager.getCurrentRetentionFactor(user),
            VotingDecayLibrary.WAD
        );
    }

    /*
     * @notice Tests setting a new decay rate and its effect on the retention factor
     */
    function test_SetDecayRatePerSecond() public {
        decayManager.initializeAccount(user);

        uint256 newRate = uint256(2e17) / (365 * 24 * 60 * 60); // 20% per year
        vm.prank(owner);
        decayManager.setDecayRatePerSecond(newRate);

        assertEq(decayManager.decayRatePerSecond(), newRate);

        // Fast-forward and check the retention factor
        vm.warp(block.timestamp + 365 days);
        uint256 expectedRetentionFactor = 0.817e18; // 81.7% of initial
        assertApproxEqAbs(
            decayManager.getCurrentRetentionFactor(user),
            expectedRetentionFactor,
            1e16
        );
    }

    /*
     * @notice Tests that setting an invalid decay rate fails
     */
    function testFail_SetInvalidDecayRate() public {
        uint256 invalidRate = 1.1e27; // 110% per year
        vm.prank(owner);
        decayManager.setDecayRatePerSecond(invalidRate);
    }

    /*
     * @notice Tests the delegation of value
     */
    function test_Delegate() public {
        decayManager.initializeAccount(user);
        decayManager.initializeAccount(delegate);
        decayManager.delegate(user, delegate);

        assertEq(
            decayManager.getCurrentRetentionFactor(user),
            decayManager.getCurrentRetentionFactor(delegate)
        );
    }

    /*
     * @notice Tests the undelegation of value
     */
    function test_Undelegate() public {
        decayManager.initializeAccount(user);
        decayManager.initializeAccount(delegate);
        decayManager.delegate(user, delegate);

        // Fast forward 6 months
        vm.warp(block.timestamp + 182 days);

        decayManager.undelegate(user);

        assertEq(
            decayManager.getCurrentRetentionFactor(user),
            VotingDecayLibrary.WAD
        ); // Reset to full value
        assertApproxEqAbs(
            decayManager.getCurrentRetentionFactor(delegate),
            0.95e18,
            1e17
        );
    }

    /*
     * @notice Tests the application of decay to value
     */
    function test_ApplyDecayToValue() public {
        decayManager.initializeAccount(user);

        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);

        uint256 decayedVotingPower = decayManager.getVotingPower(
            user,
            INITIAL_VALUE
        );
        uint256 expectedDecayedVotingPower = 908e18; // 90.8% of initial
        assertApproxEqAbs(decayedVotingPower, expectedDecayedVotingPower, 1e18);
    }

    /*
     * @notice Tests setting and using a decay-free window
     */
    function test_SetDecayFreeWindow() public {
        decayManager.initializeAccount(user);

        uint40 newDecayFreeWindow = 60 days;
        vm.prank(owner);
        decayManager.setDecayFreeWindow(newDecayFreeWindow);

        // Fast forward 59 days (within decay-free window)
        vm.warp(block.timestamp + 59 days);
        assertEq(
            decayManager.getCurrentRetentionFactor(user),
            VotingDecayLibrary.WAD
        );

        // Fast forward another 2 days (outside decay-free window)
        vm.warp(block.timestamp + 2 days);
        assertLt(
            decayManager.getCurrentRetentionFactor(user),
            VotingDecayLibrary.WAD
        );
    }

    /*
     * @notice Tests setting and using different decay functions
     */
    function test_SetDecayFunction() public {
        decayManager.initializeAccount(user);

        // Test linear decay
        vm.warp(block.timestamp + 365 days);
        uint256 linearDecayedValue = decayManager.getVotingPower(
            user,
            INITIAL_VALUE
        );

        // Switch to exponential decay
        vm.startPrank(owner);
        decayManager.setDecayFunction(
            VotingDecayLibrary.DecayFunction.Exponential
        );
        decayManager.resetDecay(user);
        vm.stopPrank();

        // Test exponential decay
        vm.warp(block.timestamp + 365 days);
        uint256 exponentialDecayedValue = decayManager.getVotingPower(
            user,
            INITIAL_VALUE
        );

        // Exponential decay should result in a higher value than linear decay after one year
        assertGt(exponentialDecayedValue, linearDecayedValue);
    }

    /*
     * @notice Tests authorized refresher functionality
     */
    function test_AuthorizedRefresher() public {
        vm.prank(owner);
        decayManager.setAuthorizedRefresher(refresher, true);

        vm.prank(refresher);
        decayManager.resetDecay(user);

        assertEq(
            decayManager.getCurrentRetentionFactor(user),
            VotingDecayLibrary.WAD
        );

        vm.prank(owner);
        decayManager.setAuthorizedRefresher(refresher, false);

        vm.expectRevert();
        vm.prank(refresher);
        decayManager.resetDecay(user);
    }
}
