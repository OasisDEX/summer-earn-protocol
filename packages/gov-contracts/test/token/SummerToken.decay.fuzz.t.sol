// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerTokenTestBase} from "./SummerTokenTestBase.sol";
import {ISummerToken} from "../../src/interfaces/ISummerToken.sol";
import {ISummerTokenErrors} from "../../src/errors/ISummerTokenErrors.sol";
import {Constants} from "@summerfi/constants/Constants.sol";
import {console} from "forge-std/console.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/VotingDecayLibrary.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

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
        address[] calldata users,
        uint256 amount
    ) public {
        uint256 chainLength = users.length;
        vm.assume(chainLength >= 2);
        amount = bound(amount, 1, type(uint96).max);

        // Setup initial balance
        deal(address(aSummerToken), users[0], amount);

        // Create delegation chain
        for (uint256 i = 0; i < users.length - 1; i++) {
            vm.prank(users[i]);
            aSummerToken.delegate(users[i + 1]);
        }

        uint256 finalDelegateVotes = aSummerToken.getVotes(
            users[chainLength - 1]
        );

        // Assert based on chain length
        if (chainLength <= VotingDecayLibrary.MAX_DELEGATION_DEPTH) {
            assertEq(
                finalDelegateVotes,
                amount,
                "Final delegate should have full voting power within MAX_DELEGATION_DEPTH"
            );
        } else {
            assertEq(
                finalDelegateVotes,
                0,
                "Final delegate should have zero voting power beyond MAX_DELEGATION_DEPTH"
            );
        }
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
}
