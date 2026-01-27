// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerStaking} from "../../src/contracts/SummerStaking.sol";
import {ISummerStaking} from "../../src/interfaces/ISummerStaking.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {Test} from "forge-std/Test.sol";
import {SummerStakingTestBase} from "./SummerStakingTestBase.sol";
import {console} from "forge-std/console.sol";

/*
 * @title SummerStaking Lockup Tests
 * @dev Comprehensive test suite for SummerStaking contract with helper methods and extensive coverage.
 */
contract SummerStakingLockupTest is SummerStakingTestBase {
    address public user3 = address(0x1003);

    function setUp() public override {
        super.setUp();

        vm.startPrank(whale);
        axSumr.burn(axSumr.balanceOf(whale));
        bxSumr.burn(bxSumr.balanceOf(whale));
        vm.stopPrank();
    }

    // Struct for multiplier test cases
    struct MultiplierTestCase {
        uint256 timeDays;
        uint256 timeSeconds;
        uint256 expectedMultiplierWad; // Expected multiplier in WAD format (18 decimals)
    }

    function test_MultiplierCalculation_AllTimePoints() public view {
        MultiplierTestCase[] memory testCases = new MultiplierTestCase[](45);

        // Populate test cases from the new spreadsheet data
        testCases[0] = MultiplierTestCase(0, 0, 1.000000000000000 * 1e18);
        testCases[1] = MultiplierTestCase(
            15,
            1296000,
            1.001175731200000 * 1e18
        );
        testCases[2] = MultiplierTestCase(
            30,
            2592000,
            1.004702924800000 * 1e18
        );
        testCases[3] = MultiplierTestCase(
            60,
            5184000,
            1.018811699200000 * 1e18
        );
        testCases[4] = MultiplierTestCase(
            90,
            7776000,
            1.042326323200000 * 1e18
        );
        testCases[5] = MultiplierTestCase(
            91,
            7862400,
            1.043272133632000 * 1e18
        );
        testCases[6] = MultiplierTestCase(
            100,
            8640000,
            1.052254720000000 * 1e18
        );
        testCases[7] = MultiplierTestCase(
            105,
            9072000,
            1.057610828800000 * 1e18
        );
        testCases[8] = MultiplierTestCase(
            109,
            9460800,
            1.062654715648000 * 1e18
        ); // 109.5 days (rounded down for integer)
        testCases[9] = MultiplierTestCase(
            110,
            9504000,
            1.063228211200000 * 1e18
        );
        testCases[10] = MultiplierTestCase(
            115,
            9936000,
            1.069106867200000 * 1e18
        );
        testCases[11] = MultiplierTestCase(
            120,
            10368000,
            1.075246796800000 * 1e18
        );
        testCases[12] = MultiplierTestCase(
            150,
            12960000,
            1.117573120000000 * 1e18
        );
        testCases[13] = MultiplierTestCase(
            180,
            15552000,
            1.169305292800000 * 1e18
        );
        testCases[14] = MultiplierTestCase(
            210,
            18144000,
            1.230443315200000 * 1e18
        );
        testCases[15] = MultiplierTestCase(
            240,
            20736000,
            1.300987187200000 * 1e18
        );
        testCases[16] = MultiplierTestCase(
            270,
            23328000,
            1.380936908800000 * 1e18
        );
        testCases[17] = MultiplierTestCase(
            300,
            25920000,
            1.470292480000000 * 1e18
        );
        testCases[18] = MultiplierTestCase(
            330,
            28512000,
            1.569053900800000 * 1e18
        );
        testCases[19] = MultiplierTestCase(
            360,
            31104000,
            1.677221171200000 * 1e18
        );
        testCases[20] = MultiplierTestCase(
            390,
            33696000,
            1.794794291200000 * 1e18
        );
        testCases[21] = MultiplierTestCase(
            420,
            36288000,
            1.921773260800000 * 1e18
        );
        testCases[22] = MultiplierTestCase(
            450,
            38880000,
            2.058158080000000 * 1e18
        );
        testCases[23] = MultiplierTestCase(
            480,
            41472000,
            2.203948748800000 * 1e18
        );
        testCases[24] = MultiplierTestCase(
            510,
            44064000,
            2.359145267200000 * 1e18
        );
        testCases[25] = MultiplierTestCase(
            540,
            46656000,
            2.523747635200000 * 1e18
        );
        testCases[26] = MultiplierTestCase(
            570,
            49248000,
            2.697755852800000 * 1e18
        );
        testCases[27] = MultiplierTestCase(
            600,
            51840000,
            2.881169920000000 * 1e18
        );
        testCases[28] = MultiplierTestCase(
            630,
            54432000,
            3.073989836800000 * 1e18
        );
        testCases[29] = MultiplierTestCase(
            660,
            57024000,
            3.276215603200000 * 1e18
        );
        testCases[30] = MultiplierTestCase(
            690,
            59616000,
            3.487847219200000 * 1e18
        );
        testCases[31] = MultiplierTestCase(
            720,
            62208000,
            3.708884684800000 * 1e18
        );
        testCases[32] = MultiplierTestCase(
            750,
            64800000,
            3.939328000000000 * 1e18
        );
        testCases[33] = MultiplierTestCase(
            780,
            67392000,
            4.179177164800000 * 1e18
        );
        testCases[34] = MultiplierTestCase(
            810,
            69984000,
            4.428432179200000 * 1e18
        );
        testCases[35] = MultiplierTestCase(
            840,
            72576000,
            4.687093043200000 * 1e18
        );
        testCases[36] = MultiplierTestCase(
            870,
            75168000,
            4.955159756800000 * 1e18
        );
        testCases[37] = MultiplierTestCase(
            900,
            77760000,
            5.232632320000000 * 1e18
        );
        testCases[38] = MultiplierTestCase(
            930,
            80352000,
            5.519510732800000 * 1e18
        );
        testCases[39] = MultiplierTestCase(
            960,
            82944000,
            5.815794995200000 * 1e18
        );
        testCases[40] = MultiplierTestCase(
            990,
            85536000,
            6.121485107200000 * 1e18
        );
        testCases[41] = MultiplierTestCase(
            1020,
            88128000,
            6.436581068800000 * 1e18
        );
        testCases[42] = MultiplierTestCase(
            1050,
            90720000,
            6.761082880000000 * 1e18
        );
        testCases[43] = MultiplierTestCase(
            1080,
            93312000,
            7.094990540800000 * 1e18
        );
        testCases[44] = MultiplierTestCase(
            1095,
            94608000,
            7.265471564800000 * 1e18
        );

        _runMultiplierTests(testCases);
    }

    /**
     * @notice Helper method to run multiplier tests for given test cases
     * @param testCases Array of test cases with time periods and expected multipliers
     */
    function _runMultiplierTests(
        MultiplierTestCase[] memory testCases
    ) internal view {
        uint256 stakeAmount = 1000 ether;

        for (uint256 i = 0; i < testCases.length; i++) {
            MultiplierTestCase memory testCase = testCases[i];

            // Get actual weighted amount from contract
            uint256 actualWeightedAmount = aStaking.calculateWeightedStake(
                stakeAmount,
                testCase.timeSeconds
            );

            // Calculate actual multiplier for comparison
            uint256 actualMultiplierWad = (actualWeightedAmount * 1e18) /
                stakeAmount;

            // Allow for small precision differences (0.01% tolerance)
            uint256 tolerance = testCase.expectedMultiplierWad / 10000; // 0.01%
            uint256 diff = actualMultiplierWad > testCase.expectedMultiplierWad
                ? actualMultiplierWad - testCase.expectedMultiplierWad
                : testCase.expectedMultiplierWad - actualMultiplierWad;

            // Optional: Enable for debugging
            console.log("=== Test Case %d ===", i);
            console.log("Days:", testCase.timeDays);
            console.log(
                "Expected vs Actual:",
                testCase.expectedMultiplierWad,
                actualMultiplierWad
            );
            if (testCase.timeDays == 0) {
                assertEq(
                    stakeAmount,
                    actualWeightedAmount,
                    "Weighted amount should be equal to stake amount for zero lockup period"
                );
            }
            assertLe(
                diff,
                tolerance,
                string(
                    abi.encodePacked(
                        "Multiplier mismatch for ",
                        vm.toString(testCase.timeDays),
                        " days. Expected: ",
                        vm.toString(testCase.expectedMultiplierWad),
                        ", Actual: ",
                        vm.toString(actualMultiplierWad),
                        ", Diff: ",
                        vm.toString(diff)
                    )
                )
            );
        }
    }
}
