// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {VotingDecayLibrary} from "../src/VotingDecayLibrary.sol";
import {VotingDecayManager} from "../src/VotingDecayManager.sol";

// Concrete implementation of VotingDecayManager for testing
contract TestVotingDecayManager is VotingDecayManager {
    constructor(
        uint40 decayFreeWindow_,
        uint256 decayRatePerSecond_,
        VotingDecayLibrary.DecayFunction decayFunction_
    )
        VotingDecayManager(
            decayFreeWindow_,
            decayRatePerSecond_,
            decayFunction_,
            msg.sender
        )
    {}

    function _getDelegateTo(
        address account
    ) internal pure override returns (address) {
        return account;
    }

    function initializeAccount(address account) public {
        _initializeAccountIfNew(account);
    }
}

contract VotingDecayTest is Test {
    TestVotingDecayManager internal decayManager;
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
        decayManager = new TestVotingDecayManager(
            INITIAL_DECAY_FREE_WINDOW,
            INITIAL_DECAY_RATE,
            VotingDecayLibrary.DecayFunction.Linear
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

        assertEq(decayManager.getDecayFactor(user), VotingDecayLibrary.WAD);
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
            decayManager.getDecayFactor(user),
            expectedRetentionFactor,
            1e25
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
            decayManager.getDecayFactor(user),
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
        assertEq(decayManager.getDecayFactor(user), VotingDecayLibrary.WAD);

        // Fast forward another 2 days (outside decay-free window)
        vm.warp(block.timestamp + 2 days);
        assertLt(decayManager.getDecayFactor(user), VotingDecayLibrary.WAD);
    }
}
