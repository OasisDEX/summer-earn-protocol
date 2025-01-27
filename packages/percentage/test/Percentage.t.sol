// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import "../contracts/Percentage.sol";

contract PercentageTest is Test {
    function test_PercentageAddition() public pure {
        Percentage percentageA = Percentage.wrap(10 * PERCENTAGE_FACTOR);
        Percentage percentageB = Percentage.wrap(20 * PERCENTAGE_FACTOR);

        Percentage result = percentageA + percentageB;

        assertEq(Percentage.unwrap(result), 30 * PERCENTAGE_FACTOR);
    }

    function test_PercentageSubtraction() public pure {
        Percentage percentageA = Percentage.wrap(30 * PERCENTAGE_FACTOR);
        Percentage percentageB = Percentage.wrap(20 * PERCENTAGE_FACTOR);

        Percentage result = percentageA - percentageB;

        assertEq(Percentage.unwrap(result), 10 * PERCENTAGE_FACTOR);
    }

    function test_PercentageMultiplication() public pure {
        Percentage percentageA = Percentage.wrap(50 * PERCENTAGE_FACTOR);
        Percentage percentageB = Percentage.wrap(50 * PERCENTAGE_FACTOR);

        Percentage result = percentageA * percentageB;

        assertEq(Percentage.unwrap(result), 25 * PERCENTAGE_FACTOR);
    }

    function test_PercentageDivision() public pure {
        Percentage percentageA = Percentage.wrap(50 * PERCENTAGE_FACTOR);
        Percentage percentageB = Percentage.wrap(25 * PERCENTAGE_FACTOR);

        Percentage result = percentageA / percentageB;

        assertEq(Percentage.unwrap(result), 200 * PERCENTAGE_FACTOR);
    }

    function test_PercentageLessOrEqualThan() public pure {
        assertTrue(
            Percentage.wrap(50 * PERCENTAGE_FACTOR) <=
                Percentage.wrap(50 * PERCENTAGE_FACTOR)
        );
        assertTrue(
            Percentage.wrap(50 * PERCENTAGE_FACTOR) <=
                Percentage.wrap((50 * PERCENTAGE_FACTOR) + 1)
        );
        assertTrue(
            Percentage.wrap(50 * PERCENTAGE_FACTOR) <=
                Percentage.wrap(60 * PERCENTAGE_FACTOR)
        );
        assertFalse(
            Percentage.wrap(60 * PERCENTAGE_FACTOR) <=
                Percentage.wrap(50 * PERCENTAGE_FACTOR)
        );
    }

    function test_PercentageLessThan() public pure {
        assertTrue(
            Percentage.wrap(50 * PERCENTAGE_FACTOR) <
                Percentage.wrap((50 * PERCENTAGE_FACTOR) + 1)
        );
        assertTrue(
            Percentage.wrap(50 * PERCENTAGE_FACTOR) <
                Percentage.wrap(60 * PERCENTAGE_FACTOR)
        );
        assertFalse(
            Percentage.wrap(50 * PERCENTAGE_FACTOR) <
                Percentage.wrap(50 * PERCENTAGE_FACTOR)
        );
        assertFalse(
            Percentage.wrap(60 * PERCENTAGE_FACTOR) <
                Percentage.wrap(50 * PERCENTAGE_FACTOR)
        );
    }

    function test_PercentageGreaterOrEqualThan() public pure {
        assertTrue(
            Percentage.wrap(50 * PERCENTAGE_FACTOR) >=
                Percentage.wrap(50 * PERCENTAGE_FACTOR)
        );
        assertTrue(
            Percentage.wrap((50 * PERCENTAGE_FACTOR) + 1) >=
                Percentage.wrap(50 * PERCENTAGE_FACTOR)
        );
        assertTrue(
            Percentage.wrap(60 * PERCENTAGE_FACTOR) >=
                Percentage.wrap(50 * PERCENTAGE_FACTOR)
        );
        assertFalse(
            Percentage.wrap(50 * PERCENTAGE_FACTOR) >=
                Percentage.wrap(60 * PERCENTAGE_FACTOR)
        );
    }

    function test_PercentageGreaterThan() public pure {
        assertTrue(
            Percentage.wrap((50 * PERCENTAGE_FACTOR) + 1) >
                Percentage.wrap(50 * PERCENTAGE_FACTOR)
        );
        assertTrue(
            Percentage.wrap(60 * PERCENTAGE_FACTOR) >
                Percentage.wrap(50 * PERCENTAGE_FACTOR)
        );
        assertFalse(
            Percentage.wrap(50 * PERCENTAGE_FACTOR) >
                Percentage.wrap(50 * PERCENTAGE_FACTOR)
        );
        assertFalse(
            Percentage.wrap(50 * PERCENTAGE_FACTOR) >
                Percentage.wrap(60 * PERCENTAGE_FACTOR)
        );
    }
}
