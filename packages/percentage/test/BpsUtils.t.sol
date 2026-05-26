// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import "../contracts/BpsUtils.sol";

contract BpsUtilsTest is Test {
    function test_ApplyBps() public pure {
        // 5% of 1000 = 50
        uint256 result = BpsUtils.applyBps(1000, BPS.wrap(500));
        assertEq(result, 50);
    }

    function test_ApplyBps_100Percent() public pure {
        uint256 result = BpsUtils.applyBps(1000, BPS_100);
        assertEq(result, 1000);
    }

    function test_ApplyBps_Zero() public pure {
        uint256 result = BpsUtils.applyBps(1000, BPS.wrap(0));
        assertEq(result, 0);
    }

    function test_AddBps() public pure {
        // 1% increase of 1000 = 1010
        uint256 result = BpsUtils.addBps(1000, BPS.wrap(100));
        assertEq(result, 1010);
    }

    function test_AddBps_ZeroIncrease() public pure {
        uint256 result = BpsUtils.addBps(1000, BPS.wrap(0));
        assertEq(result, 1000);
    }

    function test_AddBps_100Percent() public pure {
        // 100% increase of 1000 = 2000
        uint256 result = BpsUtils.addBps(1000, BPS_100);
        assertEq(result, 2000);
    }

    function test_SubtractBps() public pure {
        // 1% decrease of 1000 = 990
        uint256 result = BpsUtils.subtractBps(1000, BPS.wrap(100));
        assertEq(result, 990);
    }

    function test_SubtractBps_ZeroDecrease() public pure {
        uint256 result = BpsUtils.subtractBps(1000, BPS.wrap(0));
        assertEq(result, 1000);
    }

    function test_SubtractBps_100Percent() public pure {
        uint256 result = BpsUtils.subtractBps(1000, BPS_100);
        assertEq(result, 0);
    }

    function test_IsBpsInRange_Valid() public pure {
        assertTrue(BpsUtils.isBpsInRange(BPS.wrap(0)));
        assertTrue(BpsUtils.isBpsInRange(BPS.wrap(1)));
        assertTrue(BpsUtils.isBpsInRange(BPS.wrap(5000)));
        assertTrue(BpsUtils.isBpsInRange(BPS_100));
    }

    function test_IsBpsInRange_Invalid() public pure {
        assertFalse(BpsUtils.isBpsInRange(BPS.wrap(10001)));
        assertFalse(BpsUtils.isBpsInRange(BPS.wrap(type(uint256).max)));
    }

    function test_FromFraction_Quarter() public pure {
        // 1/4 = 25% = 2500 bps
        BPS result = BpsUtils.fromFraction(1, 4);
        assertEq(BPS.unwrap(result), 2500);
    }

    function test_FromFraction_Half() public pure {
        // 1/2 = 50% = 5000 bps
        BPS result = BpsUtils.fromFraction(1, 2);
        assertEq(BPS.unwrap(result), 5000);
    }

    function test_FromFraction_Whole() public pure {
        // 1/1 = 100% = 10000 bps
        BPS result = BpsUtils.fromFraction(1, 1);
        assertEq(BPS.unwrap(result), BPS_FACTOR);
    }

    function test_FromFraction_Zero() public pure {
        BPS result = BpsUtils.fromFraction(0, 100);
        assertEq(BPS.unwrap(result), 0);
    }
}
