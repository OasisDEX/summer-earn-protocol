// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerStaking} from "../../src/contracts/SummerStaking.sol";
import {ISummerGovernorV2} from "../../src/interfaces/ISummerGovernorV2.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {SummerVestingWalletFactory} from "../../src/contracts/SummerVestingWalletFactory.sol";
import {SummerVestingWalletFactoryV2} from "../../src/contracts/SummerVestingWalletFactoryV2.sol";
import {StakedSummerToken} from "../../src/contracts/StakedSummerToken.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {ExposedSummerGovernor, SummerGovernorV2TestBase} from "../governorV2/SummerGovernorV2TestBase.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Constants} from "@summerfi/constants/Constants.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SummerStakingTestBase} from "./SummerStakingTestBase.sol";
import {UD60x18, ud60x18, convert} from "@prb/math/src/UD60x18.sol";

/*
 * @title SummerStaking Lockup Tests
 * @dev Comprehensive test suite for SummerStaking contract with helper methods and extensive coverage.
 */
contract SummerStakingLockupTest is SummerStakingTestBase {
    address public user3 = address(0x1003);

    function setUp() public override {
        super.setUp();

        // Setup additional test users with tokens
        deal(address(aSummerToken), user3, STAKE_AMOUNT * 10);

        // Update lockup bucket caps for enhanced testing
        vm.startPrank(address(timelockA));
        aStaking.updateLockupBucketCap(
            SummerStaking.Bucket.ThreeToSixMonths,
            1000000 ether
        );
        aStaking.updateLockupBucketCap(
            SummerStaking.Bucket.SixToTwelveMonths,
            100000 ether
        );
        aStaking.updateLockupBucketCap(
            SummerStaking.Bucket.OneToTwoYears,
            100000 ether
        );
        aStaking.updateLockupBucketCap(
            SummerStaking.Bucket.TwoToThreeYears,
            100000 ether
        );
        vm.stopPrank();

        vm.startPrank(address(timelockB));
        bStaking.updateLockupBucketCap(
            SummerStaking.Bucket.ThreeToSixMonths,
            1000000 ether
        );
        bStaking.updateLockupBucketCap(
            SummerStaking.Bucket.SixToTwelveMonths,
            100000 ether
        );
        bStaking.updateLockupBucketCap(
            SummerStaking.Bucket.OneToTwoYears,
            100000 ether
        );
        bStaking.updateLockupBucketCap(
            SummerStaking.Bucket.TwoToThreeYears,
            100000 ether
        );
        vm.stopPrank();

        // Setup reward token
        rewardToken = new MockERC20();
        deal(address(rewardToken), address(timelockA), REWARD_AMOUNT * 1000);

        vm.startPrank(whale);
        axSumr.burn(axSumr.balanceOf(whale));
        bxSumr.burn(bxSumr.balanceOf(whale));
        vm.stopPrank();
    }

    // ============ ENHANCED HELPER METHODS ============

    /**
     * @notice Helper to create a fresh staking contract with specific configuration
     */
    function createFreshStakingWithConfig() internal returns (SummerStaking) {
        SummerStaking freshStaking = createFreshStaking();

        // Configure bucket caps
        vm.startPrank(address(timelockA));
        freshStaking.updateLockupBucketCap(
            SummerStaking.Bucket.ThreeToSixMonths,
            1000000 ether
        );
        freshStaking.updateLockupBucketCap(
            SummerStaking.Bucket.SixToTwelveMonths,
            100000 ether
        );
        freshStaking.updateLockupBucketCap(
            SummerStaking.Bucket.OneToTwoYears,
            100000 ether
        );
        freshStaking.updateLockupBucketCap(
            SummerStaking.Bucket.TwoToThreeYears,
            100000 ether
        );
        vm.stopPrank();

        return freshStaking;
    }

    // Struct for multiplier test cases
    struct MultiplierTestCase {
        uint256 timeDays;
        uint256 timeSeconds;
        uint256 expectedMultiplierWad; // Expected multiplier in WAD format (18 decimals)
    }

    function test_MultiplierCalculation_AllTimePoints() public {
        MultiplierTestCase[] memory testCases = new MultiplierTestCase[](39);

        // Populate test cases from the spreadsheet data
        testCases[0] = MultiplierTestCase(0, 0, 0.050000000000000 * 1e18);
        testCases[1] = MultiplierTestCase(
            15,
            1296000,
            0.050587865600000 * 1e18
        );
        testCases[2] = MultiplierTestCase(
            30,
            2592000,
            0.052351462400000 * 1e18
        );
        testCases[3] = MultiplierTestCase(
            60,
            5184000,
            0.059405849600000 * 1e18
        );
        testCases[4] = MultiplierTestCase(
            90,
            7776000,
            0.071163161600000 * 1e18
        );
        testCases[5] = MultiplierTestCase(
            120,
            10368000,
            0.087623398400000 * 1e18
        );
        testCases[6] = MultiplierTestCase(
            150,
            12960000,
            0.108786560000000 * 1e18
        );
        testCases[7] = MultiplierTestCase(
            180,
            15552000,
            0.134652646400000 * 1e18
        );
        testCases[8] = MultiplierTestCase(
            210,
            18144000,
            0.165221657600000 * 1e18
        );
        testCases[9] = MultiplierTestCase(
            240,
            20736000,
            0.200493593600000 * 1e18
        );
        testCases[10] = MultiplierTestCase(
            270,
            23328000,
            0.240468454400000 * 1e18
        );
        testCases[11] = MultiplierTestCase(
            300,
            25920000,
            0.285146240000000 * 1e18
        );
        testCases[12] = MultiplierTestCase(
            330,
            28512000,
            0.334526950400000 * 1e18
        );
        testCases[13] = MultiplierTestCase(
            360,
            31104000,
            0.388610585600000 * 1e18
        );
        testCases[14] = MultiplierTestCase(
            390,
            33696000,
            0.447397145600000 * 1e18
        );
        testCases[15] = MultiplierTestCase(
            420,
            36288000,
            0.510886630400000 * 1e18
        );
        testCases[16] = MultiplierTestCase(
            450,
            38880000,
            0.579079040000000 * 1e18
        );
        testCases[17] = MultiplierTestCase(
            480,
            41472000,
            0.651974374400000 * 1e18
        );
        testCases[18] = MultiplierTestCase(
            510,
            44064000,
            0.729572633600000 * 1e18
        );
        testCases[19] = MultiplierTestCase(
            540,
            46656000,
            0.811873817600000 * 1e18
        );
        testCases[20] = MultiplierTestCase(
            570,
            49248000,
            0.898877926400000 * 1e18
        );
        testCases[21] = MultiplierTestCase(
            600,
            51840000,
            0.990584960000000 * 1e18
        );
        testCases[22] = MultiplierTestCase(
            630,
            54432000,
            1.086994918400000 * 1e18
        );
        testCases[23] = MultiplierTestCase(
            660,
            57024000,
            1.188107801600000 * 1e18
        );
        testCases[24] = MultiplierTestCase(
            690,
            59616000,
            1.293923609600000 * 1e18
        );
        testCases[25] = MultiplierTestCase(
            720,
            62208000,
            1.404442342400000 * 1e18
        );
        testCases[26] = MultiplierTestCase(
            750,
            64800000,
            1.519664000000000 * 1e18
        );
        testCases[27] = MultiplierTestCase(
            780,
            67392000,
            1.639588582400000 * 1e18
        );
        testCases[28] = MultiplierTestCase(
            810,
            69984000,
            1.764216089600000 * 1e18
        );
        testCases[29] = MultiplierTestCase(
            840,
            72576000,
            1.893546521600000 * 1e18
        );
        testCases[30] = MultiplierTestCase(
            870,
            75168000,
            2.027579878400000 * 1e18
        );
        testCases[31] = MultiplierTestCase(
            900,
            77760000,
            2.166316160000000 * 1e18
        );
        testCases[32] = MultiplierTestCase(
            930,
            80352000,
            2.309755366400000 * 1e18
        );
        testCases[33] = MultiplierTestCase(
            960,
            82944000,
            2.457897497600000 * 1e18
        );
        testCases[34] = MultiplierTestCase(
            990,
            85536000,
            2.610742553600000 * 1e18
        );
        testCases[35] = MultiplierTestCase(
            1020,
            88128000,
            2.768290534400000 * 1e18
        );
        testCases[36] = MultiplierTestCase(
            1050,
            90720000,
            2.930541440000000 * 1e18
        );
        testCases[37] = MultiplierTestCase(
            1080,
            93312000,
            3.097495270400000 * 1e18
        );
        testCases[38] = MultiplierTestCase(
            1095,
            94608000,
            3.182735782400000 * 1e18
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
