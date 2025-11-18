// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BpsUtils} from "../../../src/helpers/BpsUtils.sol";
import {Percentage, toPercentage, fromPercentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {Bps, toBps, fromBps} from "../../../src/helpers/Bps.sol";
import {Test} from "forge-std/Test.sol";

contract BpsUtilsTest is Test {
    using BpsUtils for Bps;

    function setUp() public {}

    function test_Conversion() public pure {
        {
            Bps bps = BpsUtils.fromIntegerBPS(10);
            assertEq(
                Bps.unwrap(bps),
                Percentage.unwrap(PercentageUtils.fromIntegerPercentage(10))
            ); // 10% in BPS
        }
        {
            Bps bps = BpsUtils.fromIntegerBPS(100);
            assertEq(
                Bps.unwrap(bps),
                Percentage.unwrap(PercentageUtils.fromIntegerPercentage(100))
            ); // 10% in BPS
        }
        {
            Bps bps = BpsUtils.fromIntegerBPS(250);
            assertEq(
                Bps.unwrap(bps),
                Percentage.unwrap(PercentageUtils.fromIntegerPercentage(250))
            ); // 2.5% in BPS
        }
        {
            Bps bps = BpsUtils.fromIntegerBPS(1000);
            assertEq(
                Bps.unwrap(bps),
                Percentage.unwrap(PercentageUtils.fromIntegerPercentage(1000))
            ); // 10% in BPS
        }
    }

    function test_AddBps() public pure {
        uint256 amount = 1_000_000;

        Bps bpsToAdd = BpsUtils.fromIntegerBPS(150); // 1.5%

        uint256 newAmount = BpsUtils.addBps(amount, bpsToAdd);

        assertEq(newAmount, 1_015_000); // 1,000,000 + 1.5% = 1,015,000
    }

    function test_SubtractBps() public pure {
        uint256 amount = 1_000_000;

        Bps bpsToSubtract = BpsUtils.fromIntegerBPS(200); // 2.0%

        uint256 newAmount = BpsUtils.subtractBps(amount, bpsToSubtract);

        assertEq(newAmount, 980_000); // 1,000,000 - 2.0% = 980,000
    }

    function test_ApplyBps() public pure {
        uint256 amount = 1_000_000;

        Bps bpsToApply = BpsUtils.fromIntegerBPS(75); // 0.75%

        uint256 feeAmount = BpsUtils.applyBps(amount, bpsToApply);

        assertEq(feeAmount, 7_500); // 0.75% of 1,000,000 = 7,500
    }
}
