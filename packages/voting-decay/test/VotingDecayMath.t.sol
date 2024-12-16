// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console, Test} from "forge-std/Test.sol";
import {VotingDecayMath} from "../src/VotingDecayMath.sol";

contract VotingDecayMathTest is Test {
    function setUp() public {}

    function test_EdgeCaseExponentialDecay() public pure {
        // Test the branch in VotingDecayMath where timeElapsed == 0
        uint256 result = VotingDecayMath.exponentialDecay(
            100e18,
            0, // timeElapsed = 0
            0.1e18
        );
        assertEq(result, 100e18);
    }

    function test_LinearDecayEdgeCases() public {
        // Test zero time elapsed
        uint256 result = VotingDecayMath.linearDecay(
            100e18,
            0, // timeElapsed = 0
            0.1e18
        );
        assertEq(
            result,
            100e18,
            "No decay should occur when time elapsed is 0"
        );

        // Test zero initial value
        result = VotingDecayMath.linearDecay(
            0, // initialValue = 0
            100,
            0.1e18
        );
        assertEq(result, 0, "Zero initial value should remain zero");

        // Test zero decay rate
        result = VotingDecayMath.linearDecay(
            100e18,
            100,
            0 // decayRate = 0
        );
        assertEq(result, 100e18, "No decay should occur with zero decay rate");
    }

    function test_ExponentialDecayEdgeCases() public {
        // Test zero initial value
        uint256 result = VotingDecayMath.exponentialDecay(
            0, // initialValue
            0.1e18, // decayRatePerSecond
            100 // decayTimeInSeconds
        );
        assertEq(result, 0, "Zero initial value should remain zero");

        // Test zero decay rate
        result = VotingDecayMath.exponentialDecay(
            100e18, // initialValue
            0, // decayRatePerSecond
            100 // decayTimeInSeconds
        );
        assertEq(result, 100e18, "No decay should occur with zero decay rate");

        // Test large but manageable time elapsed (e.g., 1 year)
        result = VotingDecayMath.exponentialDecay(
            100e18, // initialValue - 100 tokens
            0.00000000027e18, // decayRatePerSecond - ~0.000000027% per second (~50% per year)
            365 days // decayTimeInSeconds - one year
        );
        assertGt(result, 0, "Decay should not underflow with large time");
        assertLt(result, 100e18, "Large time should cause significant decay");

        // Test medium time period
        result = VotingDecayMath.exponentialDecay(
            100e18, // initialValue - 100 tokens
            0.0000000027e18, // decayRatePerSecond - ~0.00000027% per second (~50% per month)
            30 days // decayTimeInSeconds - 30 days
        );
        assertGt(result, 0, "Decay should not underflow with medium time");
        assertLt(result, 100e18, "Medium time should cause partial decay");
    }
}
