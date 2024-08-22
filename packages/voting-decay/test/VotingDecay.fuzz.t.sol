// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "../src/VotingDecayManager.sol";
import "../src/VotingDecayLibrary.sol";

contract VotingDecayFuzzTest is Test {
    VotingDecayManager internal decayManager;
    address internal owner = address(0x1);
    address internal user = address(0x2);
    address internal delegate = address(0x3);

    uint256 public constant WAD = 1e18;
    uint256 public constant YEAR_IN_SECONDS = 365 days;
    uint256 public constant MAX_DECAY_RATE = WAD / YEAR_IN_SECONDS; // 100% decay per year

    function setUp() public {
        decayManager = new VotingDecayManager(
            30 days,
            MAX_DECAY_RATE / 10, // 10% decay per year
            VotingDecayLibrary.DecayFunction.Linear,
            owner
        );
        vm.prank(owner);
        decayManager.setAuthorizedRefresher(address(this), true);
    }

    function testFuzz_DecayOverTime(uint256 elapsedTime) public {
        vm.assume(elapsedTime > 0 && elapsedTime <= YEAR_IN_SECONDS);
        decayManager.initializeAccount(user);

        uint256 initialFactor = decayManager.getCurrentRetentionFactor(user);
        vm.warp(block.timestamp + elapsedTime);
        uint256 finalFactor = decayManager.getCurrentRetentionFactor(user);

        assertLe(finalFactor, initialFactor);
    }

    function testFuzz_ValueDecay(
        uint256 initialValue,
        uint256 elapsedTime
    ) public {
        vm.assume(initialValue > 0 && initialValue <= 1e36);
        vm.assume(elapsedTime > 0 && elapsedTime <= YEAR_IN_SECONDS);

        decayManager.initializeAccount(user);
        vm.warp(block.timestamp + elapsedTime);

        uint256 decayedValue = decayManager.getVotingPower(user, initialValue);
        assertLe(decayedValue, initialValue);
    }

    function testFuzz_SetDecayRate(uint256 newRate) public {
        vm.assume(newRate <= MAX_DECAY_RATE);

        vm.prank(owner);
        decayManager.setDecayRatePerSecond(newRate);

        assertEq(decayManager.decayRatePerSecond(), newRate);
    }

    function testFuzz_SetDecayFreeWindow(uint40 newWindow) public {
        vm.assume(newWindow <= YEAR_IN_SECONDS);

        vm.prank(owner);
        decayManager.setDecayFreeWindow(newWindow);

        assertEq(decayManager.decayFreeWindow(), newWindow);
    }

    function testFuzz_DelegationAndUndelegation(uint256 elapsedTime) public {
        vm.assume(elapsedTime > 0 && elapsedTime <= YEAR_IN_SECONDS);

        decayManager.initializeAccount(user);
        decayManager.initializeAccount(delegate);

        decayManager.delegate(user, delegate);
        vm.warp(block.timestamp + elapsedTime);

        uint256 userFactor = decayManager.getCurrentRetentionFactor(user);
        uint256 delegateFactor = decayManager.getCurrentRetentionFactor(delegate);
        assertEq(userFactor, delegateFactor);

        decayManager.undelegate(user);
        assertEq(decayManager.getCurrentRetentionFactor(user), VotingDecayLibrary.WAD);
    }

    function testFuzz_MultipleAccountsDecay(uint256[] memory elapsedTimes) public {
        vm.assume(elapsedTimes.length > 0 && elapsedTimes.length <= 10);

        address[] memory accounts = new address[](elapsedTimes.length);
        uint256[] memory initialFactors = new uint256[](elapsedTimes.length);

        for (uint256 i = 0; i < elapsedTimes.length; i++) {
            vm.assume(elapsedTimes[i] > 0 && elapsedTimes[i] <= YEAR_IN_SECONDS);
            accounts[i] = address(uint160(i + 1));
            decayManager.initializeAccount(accounts[i]);
            initialFactors[i] = decayManager.getCurrentRetentionFactor(accounts[i]);
        }

        for (uint256 i = 0; i < elapsedTimes.length; i++) {
            vm.warp(block.timestamp + elapsedTimes[i]);
            uint256 finalFactor = decayManager.getCurrentRetentionFactor(accounts[i]);
            assertLe(finalFactor, initialFactors[i]);
        }
    }

    function testFuzz_ResetDecay(uint256 elapsedTime) public {
        vm.assume(elapsedTime > 0 && elapsedTime <= YEAR_IN_SECONDS);

        decayManager.initializeAccount(user);

        uint256 initialFactor = decayManager.getCurrentRetentionFactor(user);

        // Warp time and update decay
        vm.warp(block.timestamp + elapsedTime);
        decayManager.updateDecay(user);

        uint256 decayedFactor = decayManager.getCurrentRetentionFactor(user);

        decayManager.resetDecay(user);

        uint256 resetFactor = decayManager.getCurrentRetentionFactor(user);

        assertEq(initialFactor, VotingDecayLibrary.WAD, "Initial factor should be WAD");
        assertLe(decayedFactor, initialFactor, "Decayed factor should be less than or equal to initial factor");
        assertEq(resetFactor, VotingDecayLibrary.WAD, "Reset factor should be WAD");
        assertGe(resetFactor, decayedFactor, "Reset factor should be greater than or equal to decayed factor");
    }

    function testFuzz_DecayFunctionComparison(uint256 initialValue, uint256 elapsedTime) public {
        vm.assume(initialValue > 0 && initialValue <= 1e36);
        vm.assume(elapsedTime > 0 && elapsedTime <= YEAR_IN_SECONDS);

        decayManager.initializeAccount(user);

        // Linear decay
        vm.warp(block.timestamp + elapsedTime);
        uint256 linearDecayedValue = decayManager.getVotingPower(user, initialValue);

        // Reset decay and change to exponential
        decayManager.resetDecay(user);
        vm.prank(owner);
        decayManager.setDecayFunction(VotingDecayLibrary.DecayFunction.Exponential);

        // Exponential decay
        vm.warp(block.timestamp + elapsedTime);
        uint256 exponentialDecayedValue = decayManager.getVotingPower(user, initialValue);

        // Exponential decay should result in a higher value than linear decay for the same time period
        assertGe(exponentialDecayedValue, linearDecayedValue);
    }

    function testFuzz_ExponentialDecay(uint256 initialValue, uint256 elapsedTime) public {
        vm.assume(initialValue > 0 && initialValue <= 1e36);
        vm.assume(elapsedTime > 0 && elapsedTime <= YEAR_IN_SECONDS);

        vm.prank(owner);
        decayManager.setDecayFunction(VotingDecayLibrary.DecayFunction.Exponential);

        decayManager.initializeAccount(user);
        uint256 initialFactor = decayManager.getCurrentRetentionFactor(user);

        vm.warp(block.timestamp + elapsedTime);
        uint256 finalFactor = decayManager.getCurrentRetentionFactor(user);
        uint256 decayedValue = decayManager.getVotingPower(user, initialValue);

        assertLe(finalFactor, initialFactor, "Final factor should be less than or equal to initial factor");
        assertLe(decayedValue, initialValue, "Decayed value should be less than or equal to initial value");
        if (initialValue > 1) {
            assertGt(decayedValue, 0, "Decayed value should be greater than zero");
        }
    }

    function testFuzz_ExponentialDecayRate(uint256 decayRate, uint256 elapsedTime) public {
        vm.assume(decayRate > 0 && decayRate <= MAX_DECAY_RATE);
        vm.assume(elapsedTime > 0 && elapsedTime <= YEAR_IN_SECONDS);

        vm.startPrank(owner);
        decayManager.setDecayFunction(VotingDecayLibrary.DecayFunction.Exponential);
        decayManager.setDecayRatePerSecond(decayRate);
        vm.stopPrank();

        decayManager.initializeAccount(user);
        uint256 initialFactor = decayManager.getCurrentRetentionFactor(user);

        vm.warp(block.timestamp + elapsedTime);
        uint256 finalFactor = decayManager.getCurrentRetentionFactor(user);

        assertLe(finalFactor, initialFactor, "Final factor should be less than or equal to initial factor");
        assertGt(finalFactor, 0, "Final factor should be greater than zero");
    }
}
