// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";

import "../src/types/Percentage.sol";

contract PercentageTest is Test {
    function testPercentageAddition() public pure {
        Percentage percentageA = Percentage.wrap(10 * PERCENTAGE_FACTOR);
        Percentage percentageB = Percentage.wrap(20 * PERCENTAGE_FACTOR);

        Percentage result = percentageA + percentageB;

        assertEq(Percentage.unwrap(result), 30 * PERCENTAGE_FACTOR);
    }

    function testPercentageSubtraction() public pure {
        Percentage percentageA = Percentage.wrap(30 * PERCENTAGE_FACTOR);
        Percentage percentageB = Percentage.wrap(20 * PERCENTAGE_FACTOR);

        Percentage result = percentageA - percentageB;

        assertEq(Percentage.unwrap(result), 10 * PERCENTAGE_FACTOR);
    }

    function testPercentageMultiplication() public pure {
        Percentage percentageA = Percentage.wrap(50 * PERCENTAGE_FACTOR);
        Percentage percentageB = Percentage.wrap(50 * PERCENTAGE_FACTOR);

        Percentage result = percentageA * percentageB;

        assertEq(Percentage.unwrap(result), 25 * PERCENTAGE_FACTOR);
    }

    function testPercentageDivision() public pure {
        Percentage percentageA = Percentage.wrap(50 * PERCENTAGE_FACTOR);
        Percentage percentageB = Percentage.wrap(25 * PERCENTAGE_FACTOR);

        Percentage result = percentageA / percentageB;

        assertEq(Percentage.unwrap(result), 200 * PERCENTAGE_FACTOR);
    }

    function testPercentageLessOrEqualThan() public pure {
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

    function testPercentageLessThan() public pure {
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

    function testPercentageGreaterOrEqualThan() public pure {
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

    function testPercentageGreaterThan() public pure {
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
