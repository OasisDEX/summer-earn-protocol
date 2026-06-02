// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import "../contracts/BPS.sol";

contract BPSTest is Test {
    function test_BPS_Constants() public pure {
        assertEq(BPS_FACTOR, 10000);
        assertEq(BPS.unwrap(BPS_100), 10000);
        assertEq(BPS.unwrap(BPS_1), 1);
    }

    function test_BPS_Addition() public pure {
        BPS a = BPS.wrap(500);
        BPS b = BPS.wrap(200);

        BPS result = a + b;

        assertEq(BPS.unwrap(result), 700);
    }

    function test_BPS_Subtraction() public pure {
        BPS a = BPS.wrap(500);
        BPS b = BPS.wrap(200);

        BPS result = a - b;

        assertEq(BPS.unwrap(result), 300);
    }

    function test_BPS_Multiplication() public pure {
        // 50% * 50% = 25%  (5000 * 5000 / 10000 = 2500)
        BPS a = BPS.wrap(5000);
        BPS b = BPS.wrap(5000);

        BPS result = a * b;

        assertEq(BPS.unwrap(result), 2500);
    }

    function test_BPS_Multiplication_SmallValues() public pure {
        // 5% * 2% = 0.1%  (500 * 200 / 10000 = 10)
        BPS a = BPS.wrap(500);
        BPS b = BPS.wrap(200);

        BPS result = a * b;

        assertEq(BPS.unwrap(result), 10);
    }

    function test_BPS_Division() public pure {
        // 5% / 2% = 250%  (500 * 10000 / 200 = 25000)
        BPS a = BPS.wrap(500);
        BPS b = BPS.wrap(200);

        BPS result = a / b;

        assertEq(BPS.unwrap(result), 25000);
    }

    function test_BPS_LessOrEqualThan() public pure {
        assertTrue(BPS.wrap(500) <= BPS.wrap(500));
        assertTrue(BPS.wrap(499) <= BPS.wrap(500));
        assertFalse(BPS.wrap(501) <= BPS.wrap(500));
    }

    function test_BPS_LessThan() public pure {
        assertTrue(BPS.wrap(499) < BPS.wrap(500));
        assertFalse(BPS.wrap(500) < BPS.wrap(500));
        assertFalse(BPS.wrap(501) < BPS.wrap(500));
    }

    function test_BPS_GreaterOrEqualThan() public pure {
        assertTrue(BPS.wrap(500) >= BPS.wrap(500));
        assertTrue(BPS.wrap(501) >= BPS.wrap(500));
        assertFalse(BPS.wrap(499) >= BPS.wrap(500));
    }

    function test_BPS_GreaterThan() public pure {
        assertTrue(BPS.wrap(501) > BPS.wrap(500));
        assertFalse(BPS.wrap(500) > BPS.wrap(500));
        assertFalse(BPS.wrap(499) > BPS.wrap(500));
    }

    function test_BPS_EqualTo() public pure {
        assertTrue(BPS.wrap(500) == BPS.wrap(500));
        assertFalse(BPS.wrap(500) == BPS.wrap(501));
    }

    function test_BPS_Equals() public pure {
        assertTrue(equals(BPS.wrap(500), BPS.wrap(500)));
        assertFalse(equals(BPS.wrap(500), BPS.wrap(501)));
    }

    function test_toBps() public pure {
        BPS result = toBps(500);
        assertEq(BPS.unwrap(result), 500);
    }

    function test_fromBps() public pure {
        uint256 result = fromBps(BPS.wrap(500));
        assertEq(result, 500);
    }

    function test_BPS_100_IsMaxRange() public pure {
        assertTrue(BPS_100 >= BPS.wrap(10000));
        assertTrue(BPS_100 <= BPS.wrap(10000));
    }
}
