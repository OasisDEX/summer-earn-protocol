// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {Percentage, PERCENTAGE_FACTOR} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Bps, BPS_FACTOR, toBps, fromBps} from "../../../src/helpers/Bps.sol";
import {BpsUtils} from "../../../src/helpers/BpsUtils.sol";

contract BpsUtilsHarness {
    function bpsToPercentage(Bps bps) external pure returns (Percentage) {
        return BpsUtils.bpsToPercentage(bps);
    }

    function percentageToBps(
        Percentage percentage
    ) external pure returns (Bps) {
        return BpsUtils.percentageToBps(percentage);
    }

    function isValidBps(Bps bps) external pure returns (bool) {
        return BpsUtils.isValidBps(bps);
    }
}

contract BpsUtilsTest is Test {
    BpsUtilsHarness internal harness;

    function setUp() public {
        harness = new BpsUtilsHarness();
    }

    function test_bpsToPercentage_zero() public view {
        Percentage result = harness.bpsToPercentage(toBps(0));
        assertEq(Percentage.unwrap(result), 0);
    }

    function test_bpsToPercentage_onePercent() public view {
        Percentage result = harness.bpsToPercentage(toBps(100));
        assertEq(Percentage.unwrap(result), PERCENTAGE_FACTOR);
    }

    function test_bpsToPercentage_hundredPercent() public view {
        Percentage result = harness.bpsToPercentage(toBps(BPS_FACTOR));
        assertEq(Percentage.unwrap(result), 100 * PERCENTAGE_FACTOR);
    }

    function test_percentageToBps_zero() public view {
        Bps result = harness.percentageToBps(Percentage.wrap(0));
        assertEq(fromBps(result), 0);
    }

    function test_percentageToBps_onePercent() public view {
        Bps result = harness.percentageToBps(
            Percentage.wrap(PERCENTAGE_FACTOR)
        );
        assertEq(fromBps(result), 100);
    }

    function test_percentageToBps_hundredPercent() public view {
        Bps result = harness.percentageToBps(
            Percentage.wrap(100 * PERCENTAGE_FACTOR)
        );
        assertEq(fromBps(result), BPS_FACTOR);
    }

    function test_roundTripConversion_examples() public view {
        uint256[3] memory samples = [uint256(0), 100, BPS_FACTOR];

        for (uint256 i = 0; i < samples.length; i++) {
            Bps original = toBps(samples[i]);
            Percentage asPercentage = harness.bpsToPercentage(original);
            Bps back = harness.percentageToBps(asPercentage);

            assertEq(fromBps(back), samples[i]);
        }
    }

    function test_isValidBps_bounds() public view {
        assertTrue(harness.isValidBps(toBps(0)));
        assertTrue(harness.isValidBps(toBps(BPS_FACTOR)));

        assertFalse(harness.isValidBps(toBps(BPS_FACTOR + 1)));
    }
}
