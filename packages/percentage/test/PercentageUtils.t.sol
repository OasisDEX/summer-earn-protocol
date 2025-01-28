// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import "../contracts/PercentageUtils.sol";

contract PercentageUtilsTest is Test {
    using PercentageUtils for uint256;

    function test_FromFraction() public pure {
        Percentage percentage = PercentageUtils.fromFraction(2085, 100);

        assertEq(Percentage.unwrap(percentage), 2085 * (PERCENTAGE_FACTOR));

        Percentage percentage50 = PercentageUtils.fromFraction(1, 2);

        assertEq(
            Percentage.unwrap(percentage50),
            Percentage.unwrap(PercentageUtils.fromIntegerPercentage(50))
        );
    }

    function test_FromDecimalPercentage() public pure {
        Percentage percentage = PercentageUtils.fromIntegerPercentage(23);

        assertEq(Percentage.unwrap(percentage), 23 * PERCENTAGE_FACTOR);
    }

    function test_AddPercentage() public pure {
        uint256 amount = 100;
        Percentage percentage = PercentageUtils.fromIntegerPercentage(50);

        uint256 result = amount.addPercentage(percentage);

        assertEq(result, 150);
    }

    function test_SubtractPercentage() public pure {
        uint256 amount = 100;
        Percentage percentage = PercentageUtils.fromIntegerPercentage(20);

        uint256 result = amount.subtractPercentage(percentage);

        assertEq(result, 80);
    }

    function test_ApplyPercentage() public pure {
        uint256 amount = 100;
        Percentage percentage = PercentageUtils.fromIntegerPercentage(40);

        uint256 result = amount.applyPercentage(percentage);

        assertEq(result, 40);
    }

    function test_IsPercentageInRange() public pure {
        Percentage percentageInRange0 = PercentageUtils.fromIntegerPercentage(
            0
        );
        assertTrue(PercentageUtils.isPercentageInRange(percentageInRange0));

        Percentage percentageInRange100 = PercentageUtils.fromIntegerPercentage(
            100
        );
        assertTrue(PercentageUtils.isPercentageInRange(percentageInRange100));

        Percentage percentageInRange26 = PercentageUtils.fromIntegerPercentage(
            26
        );
        assertTrue(PercentageUtils.isPercentageInRange(percentageInRange26));

        Percentage percentageOutOfRange = PercentageUtils.fromIntegerPercentage(
            101
        );
        assertFalse(PercentageUtils.isPercentageInRange(percentageOutOfRange));
    }
}
