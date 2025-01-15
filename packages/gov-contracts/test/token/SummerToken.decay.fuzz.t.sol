// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerTokenTestBase} from "./SummerTokenTestBase.sol";
import {ISummerToken} from "../../src/interfaces/ISummerToken.sol";
import {ISummerTokenErrors} from "../../src/errors/ISummerTokenErrors.sol";
import {Constants} from "@summerfi/constants/Constants.sol";
import {console} from "forge-std/console.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/VotingDecayLibrary.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {VotingDecayMath} from "@summerfi/voting-decay/VotingDecayMath.sol";

contract SummerTokenDecayFuzzTest is SummerTokenTestBase {
    // Constants for bounds
    uint256 constant MAX_TRANSFER = 1_000_000 ether;
    uint256 constant MIN_TRANSFER = 0.000001 ether;
    uint256 constant MAX_TIME_DELTA = 365 days * 2; // 2 years
    uint256 constant MIN_DECAY_RATE = 1e16; // 1%
    uint256 constant MAX_DECAY_RATE = Constants.WAD / 2; // 50%

    function setUp() public virtual override {
        super.setUp();
        enableTransfers();
    }

    function testFuzz_DecayOverTime(
        address user,
        address delegate,
        uint256 amount,
        uint256 timeDelta
    ) public {
        // Bound inputs
        amount = bound(amount, MIN_TRANSFER, MAX_TRANSFER);
        timeDelta = bound(timeDelta, 1 days, MAX_TIME_DELTA);
        vm.assume(user != address(0) && delegate != address(0));
        vm.assume(user != delegate);

        // Setup initial balance
        deal(address(aSummerToken), user, amount);

        // Delegate tokens
        vm.prank(user);
        aSummerToken.delegate(delegate);

        // Initial voting power check
        assertEq(aSummerToken.getVotes(delegate), amount);

        // Move time past decay free window
        vm.warp(block.timestamp + INITIAL_DECAY_FREE_WINDOW + timeDelta);

        // Force decay update
        vm.prank(address(aSummerToken));
        aSummerToken.updateDecayFactor(user);

        // Calculate expected decay
        uint256 expectedVotes = (amount *
            (Constants.WAD -
                (Percentage.unwrap(aSummerToken.getDecayRatePerYear()) *
                    timeDelta) /
                (365.25 days))) / Constants.WAD;

        // Verify decay within tolerance
        assertApproxEqRel(aSummerToken.getVotes(delegate), expectedVotes, 1e16);
        assertGe(aSummerToken.getVotes(delegate), 0); // Never negative
    }

    function testFuzz_DelegationChain(
        uint256 amount,
        address[] calldata delegatees
    ) public {
        amount = bound(amount, MIN_TRANSFER, MAX_TRANSFER);

        uint256 MAX_DELEGATES = 16;
        if (delegatees.length == 0 || delegatees.length > MAX_DELEGATES) {
            return;
        }

        // First pass: count valid delegates
        uint256 validCount = 0;
        for (uint256 i = 0; i < delegatees.length; i++) {
            if (delegatees[i] == address(0)) continue;
            bool isDuplicate = false;
            for (uint256 j = 0; j < i; j++) {
                if (delegatees[j] == delegatees[i]) {
                    isDuplicate = true;
                    break;
                }
            }
            if (!isDuplicate) validCount++;
        }

        // Skip if we don't have enough valid delegates
        if (validCount < 2) return;

        // Create array with exact size needed
        address[] memory validDelegates = new address[](validCount);

        // Second pass: fill array
        uint256 currentIndex = 0;
        for (
            uint256 i = 0;
            i < delegatees.length && currentIndex < validCount;
            i++
        ) {
            if (delegatees[i] == address(0)) continue;
            bool isDuplicate = false;
            for (uint256 j = 0; j < currentIndex; j++) {
                if (validDelegates[j] == delegatees[i]) {
                    isDuplicate = true;
                    break;
                }
            }
            if (!isDuplicate) {
                validDelegates[currentIndex] = delegatees[i];
                currentIndex++;
            }
        }

        // Setup initial balance and approve
        deal(address(aSummerToken), validDelegates[0], amount);

        // Log initial state
        console.log("\nInitial state:");
        console.log("Amount:", amount);
        console.log(
            "Initial holder balance:",
            aSummerToken.balanceOf(address(this))
        );
        console.log(
            "Initial holder votes:",
            aSummerToken.getVotes(address(this))
        );

        // Create delegation chain
        for (uint256 i = 0; i < validDelegates.length; i++) {
            // Log before delegation
            console.log("\nBefore delegation to", validDelegates[i]);
            console.log(
                "Current delegate votes:",
                aSummerToken.getVotes(validDelegates[i])
            );

            if (i == 0) {
                vm.prank(validDelegates[0]);
                aSummerToken.delegate(validDelegates[i]);
            } else {
                vm.prank(validDelegates[i - 1]);
                aSummerToken.delegate(validDelegates[i]);
            }

            // Time warp
            vm.warp(block.timestamp + 1);
            vm.roll(block.number + 1);

            // Log after delegation
            console.log("After delegation:");
            console.log(
                "Previous delegate votes:",
                i > 0
                    ? aSummerToken.getVotes(validDelegates[i - 1])
                    : aSummerToken.getVotes(validDelegates[0])
            );
            console.log(
                "Current delegate votes:",
                aSummerToken.getVotes(validDelegates[i])
            );
        }

        console.log(
            "Final delegate votes:",
            aSummerToken.getVotes(validDelegates[validDelegates.length - 1])
        );
    }

    function addressToString(
        address addr
    ) internal pure returns (string memory) {
        return string.concat(vm.toString(addr));
    }

    function testFuzz_DecayRateChange(uint256 newRate) public {
        // Bound the rate between 1% and 50%
        newRate = bound(newRate, MIN_DECAY_RATE, MAX_DECAY_RATE);
        console.log("Bound result", newRate);

        vm.prank(address(this));
        aSummerToken.setDecayRatePerYear(Percentage.wrap(newRate));

        assertApproxEqRel(
            Percentage.unwrap(aSummerToken.getDecayRatePerYear()),
            newRate,
            1e16 // 1% tolerance
        );
    }

    function testFuzz_SetDecayFreeWindow(uint40 newWindow) public {
        // Bound the window between MIN_DECAY_FREE_WINDOW and MAX_DECAY_FREE_WINDOW
        newWindow = uint40(
            bound(newWindow, MIN_DECAY_FREE_WINDOW, MAX_DECAY_FREE_WINDOW)
        );

        vm.prank(address(this));
        aSummerToken.setDecayFreeWindow(newWindow);

        assertEq(aSummerToken.getDecayFreeWindow(), newWindow);
    }

    function testFuzz_SetDecayFunctionWithValidValues(
        bool useLinearDecay
    ) public {
        VotingDecayLibrary.DecayFunction newFunction = useLinearDecay
            ? VotingDecayLibrary.DecayFunction.Linear
            : VotingDecayLibrary.DecayFunction.Exponential;

        vm.prank(address(this));
        aSummerToken.setDecayFunction(newFunction);

        // Test decay behavior
        address user = address(0x1234);
        uint256 amount = 1000 ether;

        deal(address(aSummerToken), user, amount);

        vm.prank(user);
        aSummerToken.delegate(address(0x5678));

        vm.warp(block.timestamp + INITIAL_DECAY_FREE_WINDOW + 1 days);

        vm.prank(address(aSummerToken));
        aSummerToken.updateDecayFactor(user);

        // Verify votes are never negative
        assertGt(aSummerToken.getVotes(address(0x5678)), 0);
    }

    function testFuzz_DecayBehaviorWithDifferentFunctions(
        address user,
        address delegate,
        uint256 amount,
        bool useLinearDecay
    ) public {
        // Bound inputs
        amount = bound(amount, MIN_TRANSFER, MAX_TRANSFER);
        vm.assume(user != address(0) && delegate != address(0));
        vm.assume(user != delegate);

        // Set decay function
        VotingDecayLibrary.DecayFunction decayFunction = useLinearDecay
            ? VotingDecayLibrary.DecayFunction.Linear
            : VotingDecayLibrary.DecayFunction.Exponential;

        vm.prank(address(this));
        aSummerToken.setDecayFunction(decayFunction);

        // Setup initial balance
        deal(address(aSummerToken), user, amount);

        // Delegate tokens
        vm.prank(user);
        aSummerToken.delegate(delegate);

        // Move time past decay free window
        vm.warp(block.timestamp + INITIAL_DECAY_FREE_WINDOW + 1 days);

        // Force decay update
        vm.prank(address(aSummerToken));
        aSummerToken.updateDecayFactor(user);

        // Verify votes are never negative
        assertGe(aSummerToken.getVotes(delegate), 0);
    }
}
