// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console, Test} from "forge-std/Test.sol";
import {VotingDecayMath} from "../src/VotingDecayMath.sol";

contract VotingDecayMathTest is Test {
    uint256 public constant INITIAL_VALUE = 100e18;
    // Define decay rate per second
    // 0.1e18 per year is approximately 3.168808781402895e9 per second
    // (0.1e18 / (365 * 24 * 60 * 60))
    uint256 internal constant INITIAL_DECAY_RATE = 3.1709792e9; // ~10% per year

    function test_EdgeCaseExponentialDecay() public pure {
        // Test the branch in VotingDecayMath where timeElapsed == 0
        uint256 result = VotingDecayMath.exponentialDecay(
            INITIAL_VALUE,
            INITIAL_DECAY_RATE,
            0 // timeElapsed = 0
        );
        assertEq(result, INITIAL_VALUE);
    }

    function test_LinearDecayEdgeCases() public pure {
        // Test zero time elapsed
        uint256 result = VotingDecayMath.linearDecay(
            INITIAL_VALUE,
            INITIAL_DECAY_RATE,
            0 // timeElapsed = 0
        );
        assertEq(
            result,
            INITIAL_VALUE,
            "No decay should occur when time elapsed is 0"
        );

        // Test zero initial value
        result = VotingDecayMath.linearDecay(
            0, // initialValue = 0
            INITIAL_DECAY_RATE,
            100 // timeElapsed = 100
        );
        assertEq(result, 0, "Zero initial value should remain zero");

        // Test zero decay rate
        result = VotingDecayMath.linearDecay(
            INITIAL_VALUE,
            0,
            100 // timeElapsed = 100
        );
        assertEq(
            result,
            INITIAL_VALUE,
            "No decay should occur with zero decay rate"
        );
    }

    function test_ExponentialDecayEdgeCases() public pure {
        // Test zero initial value
        uint256 result = VotingDecayMath.exponentialDecay(
            0, // initialValue
            INITIAL_DECAY_RATE, // decayRatePerSecond
            100 // timeElapsed = 100
        );
        assertEq(result, 0, "Zero initial value should remain zero");

        // Test zero decay rate
        result = VotingDecayMath.exponentialDecay(
            INITIAL_VALUE, // initialValue
            0, // decayRatePerSecond
            100 // timeElapsed = 100
        );
        assertEq(
            result,
            INITIAL_VALUE,
            "No decay should occur with zero decay rate"
        );

        // Test large but manageable time elapsed (e.g., 1 year)
        result = VotingDecayMath.exponentialDecay(
            INITIAL_VALUE, // initialValue - 100 tokens
            0.00000000027e18, // decayRatePerSecond - ~0.000000027% per second (~50% per year)
            365 days // decayTimeInSeconds - one year
        );
        assertGt(result, 0, "Decay should not underflow with large time");
        assertLt(result, 100e18, "Large time should cause significant decay");

        // Test medium time period
        result = VotingDecayMath.exponentialDecay(
            INITIAL_VALUE, // initialValue - 100 tokens
            0.0000000027e18, // decayRatePerSecond - ~0.00000027% per second (~50% per month)
            30 days // decayTimeInSeconds - 30 days
        );
        assertGt(result, 0, "Decay should not underflow with medium time");
        assertLt(
            result,
            INITIAL_VALUE,
            "Medium time should cause partial decay"
        );
    }

    function test_ExtremeDecayCases() public pure {
        // Test extremely long time period (100 years)
        uint256 result = VotingDecayMath.exponentialDecay(
            INITIAL_VALUE, // 100 tokens
            INITIAL_DECAY_RATE, // ~10% per year decay
            36500 days // 100 years
        );
        assertGt(
            result,
            0,
            "Should not decay to complete zero even after 100 years"
        );
        assertLt(
            result,
            INITIAL_VALUE / 100,
            "Should decay significantly over 100 years"
        );

        // Test very high decay rate
        result = VotingDecayMath.exponentialDecay(
            INITIAL_VALUE,
            INITIAL_DECAY_RATE * 10000,
            1 days
        );
        assertGt(
            result,
            0,
            "Should not decay to complete zero even with high decay rate"
        );
        assertLt(
            result,
            INITIAL_VALUE / 10,
            "Should decay significantly with high rate"
        );

        // Test combination of high value, high decay rate, and long time
        result = VotingDecayMath.exponentialDecay(
            1000000e18, // 1 million tokens
            0.0000001e18, // 0.00001% per second (~58% per day)
            365 days
        );
        assertGt(
            result,
            0,
            "Should not overflow or underflow with extreme values"
        );
        assertLt(result, 1000000e18, "Should show decay for extreme values");

        // Test linear decay with extreme values
        result = VotingDecayMath.linearDecay(
            INITIAL_VALUE,
            1e18, // 100% per second
            7 days
        );
        assertEq(result, 0, "Should fully decay with high linear rate");

        // Test linear decay with very long time period
        result = VotingDecayMath.linearDecay(
            INITIAL_VALUE,
            INITIAL_DECAY_RATE / 100,
            36500 days // 100 years
        );
        assertGt(result, 0, "Should not underflow with long time periods");
        assertLt(
            result,
            INITIAL_VALUE,
            "Should show some decay over long period"
        );
    }
}
