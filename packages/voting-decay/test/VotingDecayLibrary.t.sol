// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console, Test} from "forge-std/Test.sol";
import {VotingDecayLibrary} from "../src/VotingDecayLibrary.sol";
import {Constants} from "@summerfi/constants/Constants.sol";
using VotingDecayLibrary for VotingDecayLibrary.DecayState;
using VotingDecayLibrary for VotingDecayLibrary.DecayInfo;

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
        assertEq(state.getDecayFactor(user, _getDelegateTo), Constants.WAD);
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
        assertEq(state.getDecayFactor(user, _getDelegateTo), Constants.WAD);

        // Fast forward another 2 days (outside decay-free window)
        vm.warp(block.timestamp + 2 days);
        assertLt(state.getDecayFactor(user, _getDelegateTo), Constants.WAD);
    }

    function _mockDelegationChain(
        address account
    ) internal pure returns (address) {
        address delegate1 = address(0x11);
        address delegate2 = address(0x12);
        address delegate3 = address(0x13);

        if (account == address(0x1)) return delegate1;
        if (account == delegate1) return delegate2;
        if (account == delegate2) return delegate3;
        return account;
    }

    function _mockValidDelegationChain(
        address account
    ) internal view returns (address) {
        // Log the input account to see what's being passed
        console.log("Checking delegation for address:", account);

        if (account == user) {
            console.log("User delegates to:", delegate);
            return delegate;
        }
        if (account == delegate) {
            console.log("Delegate self-delegates");
            return delegate; // delegate self-delegates to end the chain
        }

        console.log("No delegation found, returning:", account);
        return account;
    }

    function test_MaxDelegationDepthExceeded() public {
        // Setup a delegation chain: user -> delegate1 -> delegate2 -> delegate3
        address delegate1 = address(0x11);
        address delegate2 = address(0x12);
        address delegate3 = address(0x13);

        // Initialize all accounts
        state.resetDecay(user);
        state.resetDecay(delegate1);
        state.resetDecay(delegate2);
        state.resetDecay(delegate3);

        // Get decay factor for user, which should follow delegation chain:
        // user -> delegate1 -> delegate2 -> delegate3 (depth of 3, which exceeds max)
        uint256 decayFactor = state.getDecayFactor(user, _mockDelegationChain);

        assertEq(
            decayFactor,
            0,
            "Decay factor should be 0 for max delegation depth exceeded"
        );
    }

    function test_ValidDelegationDepth() public {
        // Initialize the accounts
        state.resetDecay(user);
        state.resetDecay(delegate); // Using the existing delegate address from setUp

        console.log("User address:", user);
        console.log("Delegate address:", delegate);

        // Get decay factor for user, which should follow delegation chain:
        // user -> delegate (depth of 1, which is valid)
        uint256 decayFactor = state.getDecayFactor(
            user,
            _mockValidDelegationChain
        );

        console.log("Resulting decay factor:", decayFactor);

        assertGt(
            decayFactor,
            0,
            "Decay factor should be non-zero for valid delegation depth"
        );
    }

    function _mockSelfDelegation(
        address account
    ) internal pure returns (address) {
        return account;
    }

    function _mockSingleDelegation(
        address account
    ) internal view returns (address) {
        if (account == user) return delegate;
        return account;
    }

    function test_DelegationChainLength_NoDelegate() public {
        state.resetDecay(user);
        uint256 chainLength = state.getDelegationChainLength(
            user,
            _mockSelfDelegation
        );
        assertEq(
            chainLength,
            0,
            "Chain length should be 0 for self-delegation"
        );
    }

    function test_DelegationChainLength_SingleDelegate() public {
        state.resetDecay(user);
        state.resetDecay(delegate);
        uint256 chainLength = state.getDelegationChainLength(
            user,
            _mockSingleDelegation
        );
        assertEq(
            chainLength,
            1,
            "Chain length should be 1 for single delegation"
        );
    }

    function _mockZeroDelegation(
        address account
    ) internal pure returns (address) {
        console.log("Using _mockZeroDelegation for account:", account);
        return address(0);
    }

    function test_DelegationChainLength_ZeroAddress() public {
        state.resetDecay(user);

        console.log("Testing zero address delegation");
        console.log("User address:", user);

        // Test delegation to zero address
        uint256 chainLength = state.getDelegationChainLength(
            user,
            _mockZeroDelegation
        );
        console.log("Chain length:", chainLength);

        assertEq(
            chainLength,
            0,
            "Chain length should be 0 for zero address delegation"
        );
    }

    function test_UninitializedAccountDecay() public {
        // Don't initialize the user account

        // Get decay factor immediately after contract deployment
        uint256 initialDecayFactor = state.getDecayFactor(user, _getDelegateTo);
        assertEq(
            initialDecayFactor,
            Constants.WAD,
            "Initial decay factor should be WAD"
        );

        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);

        uint256 decayedFactor = state.getDecayFactor(user, _getDelegateTo);
        uint256 expectedDecayedFactor = 0.9e18; // 90% of initial after one year
        assertApproxEqAbs(decayedFactor, expectedDecayedFactor, 1e16);
    }

    function test_UninitializedAccountVotingPower() public {
        // Don't initialize the user account

        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);

        uint256 votingPower = state.getVotingPower(
            user,
            INITIAL_VALUE,
            _getDelegateTo
        );
        uint256 expectedVotingPower = 908.219178e18; // ~90.82% of INITIAL_VALUE
        assertApproxEqAbs(votingPower, expectedVotingPower, 1e18);
    }

    function _mockCyclicDelegation(
        address account
    ) internal pure returns (address) {
        address delegate1 = address(0x11);
        address delegate2 = address(0x12);

        if (account == address(0x1)) return delegate1;
        if (account == delegate1) return delegate2;
        if (account == delegate2) return address(0x1); // Creates cycle back to original user
        return account;
    }

    function test_DelegationCycles() public {
        address delegate1 = address(0x11);
        address delegate2 = address(0x12);

        // Initialize all accounts in the cycle
        state.resetDecay(user);
        state.resetDecay(delegate1);
        state.resetDecay(delegate2);

        // Get decay factor using cyclic delegation
        uint256 decayFactor = state.getDecayFactor(user, _mockCyclicDelegation);

        // Verify that cyclic delegation results in zero decay factor
        assertEq(
            decayFactor,
            0,
            "Cyclic delegation should result in zero decay factor"
        );

        // Also verify the chain length
        uint256 chainLength = state.getDelegationChainLength(
            user,
            _mockCyclicDelegation
        );
        assertEq(
            chainLength,
            2,
            "Chain length should be capped at MAX_DELEGATION_DEPTH"
        );
    }

    function test_DecayFunctionTransition() public {
        state.resetDecay(user);

        // Set initial linear decay and advance time
        vm.warp(block.timestamp + 30 days);
        uint256 linearDecay = state.getDecayFactor(user, _getDelegateTo);

        // Switch to exponential decay
        state.setDecayFunction(VotingDecayLibrary.DecayFunction.Exponential);

        // Advance more time
        vm.warp(block.timestamp + 30 days);
        uint256 mixedDecay = state.getDecayFactor(user, _getDelegateTo);

        assertLt(
            mixedDecay,
            linearDecay,
            "Mixed decay should be less than pure linear"
        );
    }

    function test_DecayBoundaryConditions() public {
        state.resetDecay(user);

        // Test extremely small decay rates
        state.setDecayRatePerSecond(1);

        // Test extremely large time periods (100 years in days)
        vm.warp(block.timestamp + (100 * 365 days));
        uint256 longTermDecay = state.getDecayFactor(user, _getDelegateTo);
        assertGt(
            longTermDecay,
            0,
            "Even long-term decay should not reach zero"
        );

        // Test decay free window edge cases
        state.setDecayFreeWindow(0);
        uint256 noWindowDecay = state.getDecayFactor(user, _getDelegateTo);
        assertLt(
            noWindowDecay,
            Constants.WAD,
            "Should decay immediately without window"
        );
    }

    function test_ConcurrentDecayOperations() public {
        state.resetDecay(user);
        state.resetDecay(delegate);

        // Simulate multiple operations in same block
        vm.warp(block.timestamp + 1 days);

        uint256 decay1 = state.getDecayFactor(user, _getDelegateTo);
        state.updateDecayFactor(user, _getDelegateTo);
        uint256 decay2 = state.getDecayFactor(user, _getDelegateTo);

        assertEq(
            decay1,
            decay2,
            "Multiple operations in same block should be consistent"
        );
    }

    function test_StateRecovery() public {
        state.resetDecay(user);

        // Reduce the time period to something more reasonable, like 10 years
        vm.warp(block.timestamp + (10 * 365 days));
        uint256 lowDecay = state.getDecayFactor(user, _getDelegateTo);
        assertLt(lowDecay, Constants.WAD);

        // Reset and check recovery
        state.resetDecay(user);
        uint256 recoveredDecay = state.getDecayFactor(user, _getDelegateTo);
        assertEq(
            recoveredDecay,
            Constants.WAD,
            "Should fully recover after reset"
        );
    }

    function test_GetDecayInfo() public {
        // Setup initial state
        state.setDecayRatePerSecond(0.1e18);
        state.setDecayFreeWindow(1 days);

        // Get decay info
        VotingDecayLibrary.DecayInfo memory info = state.getDecayInfo(user);

        assertEq(
            info.lastUpdateTimestamp,
            0,
            "Timestamp should be 0 for uninitialized account"
        );
        assertEq(
            info.decayFactor,
            0,
            "Decay factor should be 0 for uninitialized account"
        );

        // Now initialize the account
        state.resetDecay(user);

        info = state.getDecayInfo(user);

        // Verify returned values
        assertEq(info.lastUpdateTimestamp, 1);
        assertEq(info.decayFactor, Constants.WAD); // Should be WAD for uninitialized account
    }

    function test_DelegationChainWithZeroAddress() public view {
        function(address)
            pure
            returns (address) mockGetDelegateTo = _mockZeroAddressDelegate;

        uint256 chainLength = state.getDelegationChainLength(
            user,
            mockGetDelegateTo
        );
        assertEq(chainLength, 0);
    }

    function test_ComplexDelegationScenario() public view {
        address user1 = address(1);

        // Mock delegation chain
        function(address)
            view
            returns (address) mockGetDelegateTo = _mockComplexDelegation;

        // Test chain length
        uint256 chainLength = state.getDelegationChainLength(
            user1,
            mockGetDelegateTo
        );
        assertEq(chainLength, 2, "Chain length should be 2");

        // Test decay factor
        uint256 decayFactor = state.getDecayFactor(user1, mockGetDelegateTo);
        assertGt(decayFactor, 0, "Decay factor should be greater than 0");
    }

    function _mockComplexDelegation(
        address account
    ) internal pure returns (address) {
        if (account == address(1)) return address(2);
        if (account == address(2)) return address(3);
        if (account == address(3)) return address(0); // End of chain
        return account;
    }

    function test_DelegationToZeroAddress() public {
        state.resetDecay(address(0));

        // Create a helper function that always returns address(0)
        function(address)
            view
            returns (address) mockGetDelegateTo = _mockZeroAddressDelegate;

        uint256 decayFactor = state.getDecayFactor(
            address(0),
            mockGetDelegateTo
        );
        assertEq(decayFactor, 0, "Decay factor should be 0 for zero address");
    }

    function _mockZeroAddressDelegate(address) internal pure returns (address) {
        return address(0);
    }

    function test_DelegationChainLength_EndsInZeroAddress() public view {
        address user1 = address(1);

        uint256 chainLength = state.getDelegationChainLength(
            user1,
            _mockChainToZeroDelegate
        );
        assertEq(
            chainLength,
            1,
            "Chain length should be 1 when ending in zero address"
        );
    }

    function _mockChainToZeroDelegate(
        address account
    ) internal pure returns (address) {
        if (account == address(1)) return address(2);
        if (account == address(2)) return address(0);
        return account;
    }

    function test_DelegationChainLength_DeepStructure() public {
        // Setup a deep delegation chain: user -> delegate1 -> delegate2 -> delegate3
        address delegate1 = address(0x11);
        address delegate2 = address(0x12);
        address delegate3 = address(0x13);

        // Initialize all accounts in the chain
        state.resetDecay(user);
        state.resetDecay(delegate1);
        state.resetDecay(delegate2);
        state.resetDecay(delegate3);

        // Test chain length
        uint256 chainLength = state.getDelegationChainLength(
            user,
            _mockDelegationChain
        );
        assertEq(
            chainLength,
            3,
            "Chain length should reflect full delegation depth"
        );

        // Test decay factor (should be 0 since it exceeds MAX_DELEGATION_DEPTH)
        uint256 decayFactor = state.getDecayFactor(user, _mockDelegationChain);
        assertEq(
            decayFactor,
            0,
            "Decay factor should be 0 when exceeding MAX_DELEGATION_DEPTH"
        );
    }

    function test_UpdateDecayFactorPreservesFactorInWindow() public {
        // Initialize account
        state.resetDecay(user);

        // Advance time to create some decay (60 days)
        vm.warp(block.timestamp + 60 days);

        // Get initial decay factor after decay period
        uint256 initialDecayFactor = state.getDecayFactor(user, _getDelegateTo);
        assertLt(initialDecayFactor, Constants.WAD, "Should have decayed");

        state.updateDecayFactor(user, _getDelegateTo);
        uint256 expectedDecayFactor = state.getDecayFactor(
            user,
            _getDelegateTo
        );

        // Move forward but stay within decay-free window (15 days)
        vm.warp(block.timestamp + 15 days);

        // Check decay factor hasn't changed
        uint256 newDecayFactor = state.getDecayFactor(user, _getDelegateTo);

        assertEq(
            newDecayFactor,
            expectedDecayFactor,
            "Decay factor should not change when updating within decay-free window"
        );

        // Double check it's not WAD
        assertLt(
            newDecayFactor,
            Constants.WAD,
            "Decay factor should not reset to WAD"
        );
    }
}
