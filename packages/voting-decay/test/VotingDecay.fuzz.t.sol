// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "../src/VotingDecayManager.sol";

contract VotingDecayFuzzTest is Test {
    VotingDecayManager internal decayManager;
    address internal owner = address(0x1);
    address internal user = address(0x2);
    address internal delegate = address(0x3);

    function setUp() public {
        decayManager = new VotingDecayManager(30 days, 0.1e27, owner);
    }

    function testFuzz_DecayOverTime(uint256 elapsedTime) public {
        vm.assume(elapsedTime <= 365 days);
        decayManager.initializeAccount(user);

        uint256 initialIndex = decayManager.getCurrentDecayIndex(user);
        vm.warp(block.timestamp + elapsedTime);
        uint256 finalIndex = decayManager.getCurrentDecayIndex(user);

        assertLe(finalIndex, initialIndex);
    }

    function testFuzz_VotingPowerDecay(
        uint256 initialVotingPower,
        uint256 elapsedTime
    ) public {
        vm.assume(initialVotingPower <= 1e36);
        vm.assume(elapsedTime <= 1000 days);

        decayManager.initializeAccount(user);
        vm.warp(block.timestamp + elapsedTime);

        uint256 decayedVotingPower = decayManager.getVotingPower(
            user,
            initialVotingPower
        );
        assertLe(decayedVotingPower, initialVotingPower);
    }

    function testFuzz_SetDecayRate(uint256 newRate) public {
        vm.assume(newRate <= 1e27);

        vm.prank(owner);
        decayManager.setDecayRate(newRate);

        assertEq(decayManager.decayRate(), newRate);
    }

    function testFuzz_SetDecayFreeWindow(uint40 newWindow) public {
        vm.assume(newWindow <= 365 days);

        vm.prank(owner);
        decayManager.setDecayFreeWindow(newWindow);

        assertEq(decayManager.decayFreeWindow(), newWindow);
    }

    function testFuzz_DelegationAndUndelegation(uint256 elapsedTime) public {
        vm.assume(elapsedTime <= 365 days);

        decayManager.initializeAccount(user);
        decayManager.initializeAccount(delegate);

        decayManager.delegate(user, delegate);
        vm.warp(block.timestamp + elapsedTime);

        uint256 userIndex = decayManager.getCurrentDecayIndex(user);
        uint256 delegateIndex = decayManager.getCurrentDecayIndex(delegate);
        assertEq(userIndex, delegateIndex);

        decayManager.undelegate(user);
        assertEq(
            decayManager.getCurrentDecayIndex(user),
            VotingDecayLibrary.RAY
        );
    }

    function testFuzz_MultipleAccountsDecay(
        uint256[] memory elapsedTimes
    ) public {
        vm.assume(elapsedTimes.length <= 10);

        address[] memory accounts = new address[](elapsedTimes.length);
        uint256[] memory initialIndices = new uint256[](elapsedTimes.length);

        for (uint256 i = 0; i < elapsedTimes.length; i++) {
            vm.assume(elapsedTimes[i] <= 365 days);
            accounts[i] = address(uint160(i + 1));
            decayManager.initializeAccount(accounts[i]);
            initialIndices[i] = decayManager.getCurrentDecayIndex(accounts[i]);
        }

        for (uint256 i = 0; i < elapsedTimes.length; i++) {
            vm.warp(block.timestamp + elapsedTimes[i]);
            uint256 finalIndex = decayManager.getCurrentDecayIndex(accounts[i]);
            assertLe(finalIndex, initialIndices[i]);
        }
    }

    function testFuzz_ResetDecay(uint256 elapsedTime) public {
        vm.assume(elapsedTime <= 365 days);

        decayManager.initializeAccount(user);

        uint256 initialIndex = decayManager.getCurrentDecayIndex(user);

        // Warp time and update decay
        vm.warp(block.timestamp + elapsedTime);
        decayManager.updateDecay(user);

        uint256 decayedIndex = decayManager.getCurrentDecayIndex(user);

        vm.prank(owner);
        decayManager.resetDecay(user);

        uint256 resetIndex = decayManager.getCurrentDecayIndex(user);

        assertEq(
            initialIndex,
            VotingDecayLibrary.RAY,
            "Initial index should be RAY"
        );
        assertLe(
            decayedIndex,
            initialIndex,
            "Decayed index should be less than or equal to initial index"
        );
        assertEq(
            resetIndex,
            VotingDecayLibrary.RAY,
            "Reset index should be RAY"
        );
        assertGe(
            resetIndex,
            decayedIndex,
            "Reset index should be greater than or equal to decayed index"
        );
    }
}
