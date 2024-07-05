// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";

import "../src/libraries/PercentageUtils.sol";

contract PercentageUtilsTest is Test {
    using PercentageUtils for uint256;

    function testFromFraction() public pure {
        Percentage percentage = PercentageUtils.fromFraction(2085, 100);

        assertEq(Percentage.unwrap(percentage), 20850000);
    }

    function testFromDecimalPercentage() public pure {
        Percentage percentage = PercentageUtils.fromDecimalPercentage(23);

        assertEq(Percentage.unwrap(percentage), 23000000);
    }

    function testAddPercentage() public pure {
        uint256 amount = 100;
        Percentage percentage = PercentageUtils.fromDecimalPercentage(50);

        uint256 result = amount.addPercentage(percentage);

        assertEq(result, 150);
    }

    function testSubtractPercentage() public pure {
        uint256 amount = 100;
        Percentage percentage = PercentageUtils.fromDecimalPercentage(20);

        uint256 result = amount.subtractPercentage(percentage);

        assertEq(result, 80);
    }

    function testApplyPercentage() public pure {
        uint256 amount = 100;
        Percentage percentage = PercentageUtils.fromDecimalPercentage(40);

        uint256 result = amount.applyPercentage(percentage);

        assertEq(result, 40);
    }

    function testIsPercentageInRange() public pure {
        Percentage percentageInRange0 = PercentageUtils.fromDecimalPercentage(0);
        assertTrue(PercentageUtils.isPercentageInRange(percentageInRange0));

        Percentage percentageInRange100 = PercentageUtils.fromDecimalPercentage(100);
        assertTrue(PercentageUtils.isPercentageInRange(percentageInRange100));

        Percentage percentageInRange26 = PercentageUtils.fromDecimalPercentage(26);
        assertTrue(PercentageUtils.isPercentageInRange(percentageInRange26));

        Percentage percentageOutOfRange = PercentageUtils.fromDecimalPercentage(101);
        assertFalse(PercentageUtils.isPercentageInRange(percentageOutOfRange));
    }
}
