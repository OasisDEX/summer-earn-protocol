// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";

import "../src/types/Percentage.sol";

contract PercentageTest is Test {

    function testPercentageAddition() public pure {
        Percentage percentageA = Percentage.wrap(10000000);
        Percentage percentageB = Percentage.wrap(20000000);

        Percentage result = percentageA + percentageB;

        assertEq(Percentage.unwrap(result), 30000000);
    }

    function testPercentageSubtraction() public pure {
        Percentage percentageA = Percentage.wrap(30000000);
        Percentage percentageB = Percentage.wrap(20000000);

        Percentage result = percentageA - percentageB;

        assertEq(Percentage.unwrap(result), 10000000);
    }

    function testPercentageMultiplication() public pure {
        Percentage percentageA = Percentage.wrap(50000000);
        Percentage percentageB = Percentage.wrap(50000000);

        Percentage result = percentageA * percentageB;

        assertEq(Percentage.unwrap(result), 25000000);
    }

    function testPercentageDivision() public pure {
        Percentage percentageA = Percentage.wrap(50000000);
        Percentage percentageB = Percentage.wrap(25000000);

        Percentage result = percentageA / percentageB;

        assertEq(Percentage.unwrap(result), 200000000);
    }

    function testPercentageLessOrEqualThan() public pure {
        assertTrue(Percentage.wrap(50000000) <= Percentage.wrap(50000000));
        assertTrue(Percentage.wrap(50000000) <= Percentage.wrap(50000001));
        assertTrue(Percentage.wrap(50000000) <= Percentage.wrap(60000000));
        assertFalse(Percentage.wrap(60000000) <= Percentage.wrap(50000000));
    }

    function testPercentageLessThan() public pure {
        assertTrue(Percentage.wrap(50000000) < Percentage.wrap(50000001));
        assertTrue(Percentage.wrap(50000000) < Percentage.wrap(60000000));
        assertFalse(Percentage.wrap(50000000) < Percentage.wrap(50000000));
        assertFalse(Percentage.wrap(60000000) < Percentage.wrap(50000000));
    }

    function testPercentageGreaterOrEqualThan() public pure {
        assertTrue(Percentage.wrap(50000000) >= Percentage.wrap(50000000));
        assertTrue(Percentage.wrap(50000001) >= Percentage.wrap(50000000));
        assertTrue(Percentage.wrap(60000000) >= Percentage.wrap(50000000));
        assertFalse(Percentage.wrap(50000000) >= Percentage.wrap(60000000));
    }

    function testPercentageGreaterThan() public pure {
        assertTrue(Percentage.wrap(50000001) > Percentage.wrap(50000000));
        assertTrue(Percentage.wrap(60000000) > Percentage.wrap(50000000));
        assertFalse(Percentage.wrap(50000000) > Percentage.wrap(50000000));
        assertFalse(Percentage.wrap(50000000) > Percentage.wrap(60000000));
    }

}
