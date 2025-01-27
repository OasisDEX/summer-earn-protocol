// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {VotingDecayLibrary} from "../src/VotingDecayLibrary.sol";
import {Constants} from "@summerfi/constants/Constants.sol";

contract TestVotingDecayManager {
    using VotingDecayLibrary for VotingDecayLibrary.DecayState;

    VotingDecayLibrary.DecayState internal state;
    mapping(address => address) public delegations;

    constructor(
        uint40 decayFreeWindow_,
        uint256 decayRatePerSecond_,
        VotingDecayLibrary.DecayFunction decayFunction_
    ) {
        state.initialize(decayFreeWindow_, decayRatePerSecond_, decayFunction_);
    }

    function _getDelegateTo(address account) internal view returns (address) {
        return delegations[account];
    }

    function setDelegation(address from, address to) public {
        delegations[from] = to;
    }

    function resetDecay(address account) public {
        state.resetDecay(account);
    }

    function setDecayRatePerSecond(uint256 newRatePerSecond) public {
        state.setDecayRatePerSecond(newRatePerSecond);
    }

    function setDecayFreeWindow(uint40 newWindow) public {
        state.setDecayFreeWindow(newWindow);
    }

    function setDecayFunction(
        VotingDecayLibrary.DecayFunction newFunction
    ) public {
        state.setDecayFunction(newFunction);
    }

    function getDecayFactor(address account) public view returns (uint256) {
        return state.getDecayFactor(account, _getDelegateTo);
    }

    function getVotingPower(
        address account,
        uint256 value
    ) public view returns (uint256) {
        return state.getVotingPower(account, value, _getDelegateTo);
    }

    // Add these getter functions to maintain compatibility
    function decayRatePerSecond() public view returns (uint256) {
        return state.decayRatePerSecond;
    }

    function decayFreeWindow() public view returns (uint40) {
        return state.decayFreeWindow;
    }
}

/**
 * @title VotingDecayFuzzTest
 * @dev Fuzz testing suite for the VotingDecayManager contract
 */
contract VotingDecayFuzzTest is Test {
    TestVotingDecayManager internal decayManager;
    address internal owner = address(0x1);
    address internal user = address(0x2);
    address internal delegate = address(0x3);

    uint256 public constant WAD = 1e18;
    uint256 public constant YEAR_IN_SECONDS = 365 days;
    uint256 public constant MAX_DECAY_RATE = WAD / YEAR_IN_SECONDS; // 100% decay per year

    /**
     * @dev Set up the test environment
     */
    function setUp() public {
        vm.prank(owner);
        decayManager = new TestVotingDecayManager(
            30 days,
            MAX_DECAY_RATE / 10, // 10% decay per year
            VotingDecayLibrary.DecayFunction.Linear
        );
    }

    /**
     * @dev Test decay over time
     * @param elapsedTime Random time period to test decay
     */

    function testFuzz_DecayOverTime(uint256 elapsedTime) public {
        vm.assume(elapsedTime > 0 && elapsedTime <= YEAR_IN_SECONDS);
        decayManager.resetDecay(user);

        uint256 initialFactor = decayManager.getDecayFactor(user);
        vm.warp(block.timestamp + elapsedTime);
        uint256 finalFactor = decayManager.getDecayFactor(user);

        assertLe(finalFactor, initialFactor);
    }

    /**
     * @dev Test value decay
     * @param initialValue Random initial value to test decay
     * @param elapsedTime Random time period to test decay
     */
    function testFuzz_ValueDecay(
        uint256 initialValue,
        uint256 elapsedTime
    ) public {
        vm.assume(initialValue > 0 && initialValue <= 1e36);
        vm.assume(elapsedTime > 0 && elapsedTime <= YEAR_IN_SECONDS);

        decayManager.resetDecay(user);
        vm.warp(block.timestamp + elapsedTime);

        uint256 decayedValue = decayManager.getVotingPower(user, initialValue);
        assertLe(decayedValue, initialValue);
    }

    /**
     * @dev Test setting decay rate
     * @param newRate Random new decay rate to test
     */
    function testFuzz_SetDecayRate(uint256 newRate) public {
        vm.assume(newRate <= MAX_DECAY_RATE);

        vm.prank(owner);
        decayManager.setDecayRatePerSecond(newRate);

        assertEq(decayManager.decayRatePerSecond(), newRate);
    }

    /**
     * @dev Test setting decay-free window
     * @param newWindow Random new decay-free window to test
     */
    function testFuzz_SetDecayFreeWindow(uint40 newWindow) public {
        vm.assume(newWindow <= YEAR_IN_SECONDS);

        vm.prank(owner);
        decayManager.setDecayFreeWindow(newWindow);

        assertEq(decayManager.decayFreeWindow(), newWindow);
    }

    /**
     * @dev Test decay for multiple accounts
     * @param elapsedTimes Array of random time periods to test decay for multiple accounts
     */
    function testFuzz_MultipleAccountsDecay(
        uint256[] memory elapsedTimes
    ) public {
        vm.assume(elapsedTimes.length > 0 && elapsedTimes.length <= 10);

        address[] memory accounts = new address[](elapsedTimes.length);
        uint256[] memory initialFactors = new uint256[](elapsedTimes.length);

        for (uint256 i = 0; i < elapsedTimes.length; i++) {
            vm.assume(
                elapsedTimes[i] > 0 && elapsedTimes[i] <= YEAR_IN_SECONDS
            );
            accounts[i] = address(uint160(i + 1));
            decayManager.resetDecay(accounts[i]);
            initialFactors[i] = decayManager.getDecayFactor(accounts[i]);
        }

        for (uint256 i = 0; i < elapsedTimes.length; i++) {
            vm.warp(block.timestamp + elapsedTimes[i]);
            uint256 finalFactor = decayManager.getDecayFactor(accounts[i]);
            assertLe(finalFactor, initialFactors[i]);
        }
    }

    /**
     * @dev Test resetting decay
     * @param elapsedTime Random time period to test decay reset
     */
    function testFuzz_ResetDecay(uint256 elapsedTime) public {
        vm.assume(elapsedTime > 0 && elapsedTime <= YEAR_IN_SECONDS);

        decayManager.resetDecay(user);

        uint256 initialFactor = decayManager.getDecayFactor(user);

        // Warp time and update decay
        vm.warp(block.timestamp + elapsedTime);

        uint256 decayedFactor = decayManager.getDecayFactor(user);

        decayManager.resetDecay(user);
        uint256 resetFactor = decayManager.getDecayFactor(user);

        assertEq(initialFactor, Constants.WAD, "Initial factor should be WAD");
        assertLe(
            decayedFactor,
            initialFactor,
            "Decayed factor should be less than or equal to initial factor"
        );
        assertEq(resetFactor, Constants.WAD, "Reset factor should be WAD");
        assertGe(
            resetFactor,
            decayedFactor,
            "Reset factor should be greater than or equal to decayed factor"
        );
    }

    /**
     * @dev Test comparison between linear and exponential decay functions
     * @param initialValue Random initial value to test decay
     * @param elapsedTime Random time period to test decay
     */
    function testFuzz_DecayFunctionComparison(
        uint256 initialValue,
        uint256 elapsedTime
    ) public {
        vm.assume(initialValue > 0 && initialValue <= 1e36);
        vm.assume(elapsedTime > 0 && elapsedTime <= YEAR_IN_SECONDS);

        decayManager.resetDecay(user);

        // Linear decay
        vm.warp(block.timestamp + elapsedTime);
        uint256 linearDecayedValue = decayManager.getVotingPower(
            user,
            initialValue
        );

        // Reset decay and change to exponential
        decayManager.resetDecay(user);

        vm.prank(owner);
        decayManager.setDecayFunction(
            VotingDecayLibrary.DecayFunction.Exponential
        );

        // Exponential decay
        vm.warp(block.timestamp + elapsedTime);
        uint256 exponentialDecayedValue = decayManager.getVotingPower(
            user,
            initialValue
        );

        // Exponential decay should result in a higher value than linear decay for the same time period
        assertGe(exponentialDecayedValue, linearDecayedValue);
    }

    /**
     * @dev Test exponential decay
     * @param initialValue Random initial value to test decay
     * @param elapsedTime Random time period to test decay
     */
    function testFuzz_ExponentialDecay(
        uint256 initialValue,
        uint256 elapsedTime
    ) public {
        vm.assume(initialValue > 0 && initialValue <= 1e36);
        vm.assume(elapsedTime > 0 && elapsedTime <= YEAR_IN_SECONDS);

        vm.prank(owner);
        decayManager.setDecayFunction(
            VotingDecayLibrary.DecayFunction.Exponential
        );

        decayManager.resetDecay(user);
        uint256 initialFactor = decayManager.getDecayFactor(user);

        vm.warp(block.timestamp + elapsedTime);
        uint256 finalFactor = decayManager.getDecayFactor(user);
        uint256 decayedValue = decayManager.getVotingPower(user, initialValue);

        assertLe(
            finalFactor,
            initialFactor,
            "Final factor should be less than or equal to initial factor"
        );
        assertLe(
            decayedValue,
            initialValue,
            "Decayed value should be less than or equal to initial value"
        );
        if (initialValue > 1) {
            assertGt(
                decayedValue,
                0,
                "Decayed value should be greater than zero"
            );
        }
    }

    /**
     * @dev Test exponential decay rate
     * @param decayRate Random decay rate to test
     * @param elapsedTime Random time period to test decay
     */
    function testFuzz_ExponentialDecayRate(
        uint256 decayRate,
        uint256 elapsedTime
    ) public {
        vm.assume(decayRate > 0 && decayRate <= MAX_DECAY_RATE);
        vm.assume(elapsedTime > 0 && elapsedTime <= YEAR_IN_SECONDS);

        vm.startPrank(owner);
        decayManager.setDecayFunction(
            VotingDecayLibrary.DecayFunction.Exponential
        );
        decayManager.setDecayRatePerSecond(decayRate);
        vm.stopPrank();

        decayManager.resetDecay(user);
        uint256 initialFactor = decayManager.getDecayFactor(user);

        vm.warp(block.timestamp + elapsedTime);
        uint256 finalFactor = decayManager.getDecayFactor(user);

        assertLe(
            finalFactor,
            initialFactor,
            "Final factor should be less than or equal to initial factor"
        );
        assertGt(finalFactor, 0, "Final factor should be greater than zero");
    }

    /**
     * @dev Test delegation depth
     * @param delegationChain Array of addresses representing the delegation chain
     */
    function testFuzz_DelegationDepth(
        address[] calldata delegationChain
    ) public {
        vm.assume(delegationChain.length > 0 && delegationChain.length <= 5);

        // Initialize all accounts in the chain and set up delegation mapping
        for (uint i = 0; i < delegationChain.length; i++) {
            vm.assume(delegationChain[i] != address(0));
            // Ensure unique addresses
            for (uint j = 0; j < i; j++) {
                vm.assume(delegationChain[i] != delegationChain[j]);
            }
            decayManager.resetDecay(delegationChain[i]);

            // Set up delegation chain
            if (i < delegationChain.length - 1) {
                decayManager.setDelegation(
                    delegationChain[i],
                    delegationChain[i + 1]
                );
            } else {
                decayManager.setDelegation(
                    delegationChain[i],
                    delegationChain[i]
                );
            }
        }

        uint256 decayFactor = decayManager.getDecayFactor(delegationChain[0]);

        // If chain length exceeds MAX_DELEGATION_DEPTH, decay factor should be 0
        if (delegationChain.length > 2) {
            assertEq(
                decayFactor,
                0,
                "Decay factor should be 0 when delegation depth exceeded"
            );
        } else {
            assertGt(
                decayFactor,
                0,
                "Decay factor should be non-zero within delegation depth limit"
            );
        }
    }

    /**
     * @dev Test uninitialized account decay
     * @param elapsedTime Random time period to test decay
     */
    function testFuzz_UninitializedAccountDecay(uint256 elapsedTime) public {
        vm.assume(elapsedTime > 0 && elapsedTime <= YEAR_IN_SECONDS);

        // Don't initialize the user account
        uint256 initialFactor = decayManager.getDecayFactor(user);
        assertEq(initialFactor, WAD, "Initial factor should be WAD");

        vm.warp(block.timestamp + elapsedTime);
        uint256 finalFactor = decayManager.getDecayFactor(user);

        assertLe(
            finalFactor,
            initialFactor,
            "Final factor should be less than initial"
        );
        if (elapsedTime > decayManager.decayFreeWindow()) {
            assertLt(
                finalFactor,
                initialFactor,
                "Final factor should decay after free window"
            );
        } else {
            assertEq(finalFactor, initialFactor, "No decay within free window");
        }
    }

    /**
     * @dev Test uninitialized then initialized account decay
     * @param preInitTime Random time period to test decay before initialization
     * @param postInitTime Random time period to test decay after initialization
     */
    function testFuzz_UninitializedThenInitialized(
        uint256 preInitTime,
        uint256 postInitTime
    ) public {
        vm.assume(preInitTime > 0 && preInitTime <= YEAR_IN_SECONDS);
        vm.assume(postInitTime > 0 && postInitTime <= YEAR_IN_SECONDS);

        // Advance time while uninitialized
        vm.warp(block.timestamp + preInitTime);

        // Initialize the account
        decayManager.resetDecay(user);
        uint256 resetFactor = decayManager.getDecayFactor(user);
        assertEq(resetFactor, WAD, "Reset should set factor to WAD");

        // Check decay after initialization
        vm.warp(block.timestamp + postInitTime);
        uint256 postInitFactor = decayManager.getDecayFactor(user);

        if (postInitTime > decayManager.decayFreeWindow()) {
            assertLt(
                postInitFactor,
                resetFactor,
                "Should decay after initialization"
            );
        } else {
            assertEq(
                postInitFactor,
                resetFactor,
                "Should not decay within free window after init"
            );
        }
    }

    function test_UninitializedAccountVotingPower() public {
        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);

        uint256 votingPower = decayManager.getVotingPower(user, 1000e18);
        uint256 expectedVotingPower = 908.219178e18; // ~90.82% of 1000e18
        assertApproxEqAbs(votingPower, expectedVotingPower, 1e18);
    }
}
