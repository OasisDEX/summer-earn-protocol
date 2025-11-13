// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BpsUtils} from "../../../src/helpers/BpsUtils.sol";
import {Percentage, toPercentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Bps, BPS_FACTOR, toBps, fromBps} from "../../../src/helpers/Bps.sol";
import {Test} from "forge-std/Test.sol";

contract BpsUtilsTest is Test {
    using BpsUtils for Bps;

    function setUp() public {}

    function test_Conversion() public pure {
        {
            Percentage percentage = toPercentage(10);
            Bps bps = BpsUtils.percentageToBps(percentage);
            assertEq(Bps.unwrap(bps), 100_000); // 10% in BPS
        }
        {
            Percentage percentage = toPercentage(100);
            Bps bps = BpsUtils.percentageToBps(percentage);
            assertEq(Bps.unwrap(bps), 1_000_000); // 100% in BPS
        }
        {
            Bps bps = toBps(25_000); // 2.5% in BPS
            Percentage percentage = BpsUtils.bpsToPercentage(bps);
            assertEq(Percentage.unwrap(percentage), 2.5e18); // 2.5% in Percentage
        }
        {
            Bps bps = toBps(1_000_000); // 100% in BPS
            Percentage percentage = BpsUtils.bpsToPercentage(bps);
            assertEq(Percentage.unwrap(percentage), 100e18); // 100% in Percentage
        }
    }

    function test_Validation() public pure {
        Percentage percentage = toPercentage(10);
        Bps bps = BpsUtils.percentageToBps(percentage);

        //assertEq(BpsUtils.isValidBps(bps), true);

        Bps invalidBps = toBps(15_000); // 150% in BPS
        assertEq(BpsUtils.isValidBps(invalidBps), false);
    }

    function test_BpsFee() public pure {
        {
            Percentage percentage = toPercentage(10);
            Bps bps = BpsUtils.percentageToBps(percentage);

            uint256 amount = 1_000_000; // 1,000,000 units

            uint256 feeAmount = BpsUtils.calculateBpsFee(amount, bps);
            assertEq(feeAmount, 100_000); // 10% fee = 100,000 units
        }
        {
            Percentage percentage = toPercentage(100);
            Bps bps = BpsUtils.percentageToBps(percentage);

            uint256 amount = 1_000_000; // 1,000,000 units

            uint256 feeAmount = BpsUtils.calculateBpsFee(amount, bps);
            assertEq(feeAmount, 1_000_000); // 100% fee = 1,000,000 units
        }
        {
            Percentage percentage = toPercentage(0);
            Bps bps = BpsUtils.percentageToBps(percentage);

            uint256 amount = 1_000_000; // 1,000,000 units

            uint256 feeAmount = BpsUtils.calculateBpsFee(amount, bps);
            assertEq(feeAmount, 0); // 0% fee = 0 units
        }
    }

    function test_BpsDiscount() public pure {
        {
            Percentage percentage = toPercentage(10);
            Bps bps = BpsUtils.percentageToBps(percentage);

            uint256 amount = 1_000_000; // 1,000,000 units

            uint256 feeAmount = BpsUtils.applyBpsDiscount(amount, bps);
            assertEq(feeAmount, 900_000); // 10% fee = 900,000 units
        }
        {
            Percentage percentage = toPercentage(100);
            Bps bps = BpsUtils.percentageToBps(percentage);

            uint256 amount = 1_000_000; // 1,000,000 units

            uint256 feeAmount = BpsUtils.applyBpsDiscount(amount, bps);
            assertEq(feeAmount, 0); // 100% fee = 0 units
        }
        {
            Percentage percentage = toPercentage(0);
            Bps bps = BpsUtils.percentageToBps(percentage);

            uint256 amount = 1_000_000; // 1,000,000 units

            uint256 feeAmount = BpsUtils.applyBpsDiscount(amount, bps);
            assertEq(feeAmount, 1_000_000); // 0% fee = 1,000,000 units
        }
    }
}
