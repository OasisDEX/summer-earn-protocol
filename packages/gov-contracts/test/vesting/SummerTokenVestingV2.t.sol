// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerVestingWalletV2} from "../../src/contracts/SummerVestingWalletV2.sol";
import {SummerVestingWalletFactoryV2} from "../../src/contracts/SummerVestingWalletFactoryV2.sol";
import {ISummerVestingWalletV2} from "../../src/interfaces/ISummerVestingWalletV2.sol";
import {ISummerVestingWalletFactoryV2} from "../../src/interfaces/ISummerVestingWalletFactoryV2.sol";
import {SummerTokenTestBase} from "../token/SummerTokenTestBase.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Test, console} from "forge-std/Test.sol";

contract SummerVestingV2Test is SummerTokenTestBase {
    SummerVestingWalletFactoryV2 public factoryV2;
    address public beneficiary;
    address public foundation;
    address public nonFoundation;

    // Constants for the hypothetical example from requirements
    uint256 constant CLIFF_AMOUNT = 2000006 ether;
    uint256 constant TIME_VESTING_TOTAL = 5999994 ether;
    uint256 constant VESTING_PERIODS = 18;
    uint256 constant PERFORMANCE_GOAL_1 = 1000000 ether; // 500M TVL
    uint256 constant PERFORMANCE_GOAL_2 = 1000000 ether; // 100,000 active users
    uint256 constant TOTAL_AMOUNT = CLIFF_AMOUNT + TIME_VESTING_TOTAL + PERFORMANCE_GOAL_1 + PERFORMANCE_GOAL_2;

    // September 1st, 2025 timestamp
    uint64 constant CLIFF_END_TIMESTAMP = 1756681200;

    function setUp() public override {
        super.setUp();

        // Setup test addresses
        foundation = address(0x3);
        nonFoundation = address(0x4);
        beneficiary = address(0x1);

        // Grant foundation role
        vm.startPrank(address(timelockA));
        accessManagerA.grantFoundationRole(foundation);
        vm.stopPrank();

        // Create V2 factory
        factoryV2 = new SummerVestingWalletFactoryV2(
            address(aSummerToken),
            address(accessManagerA)
        );

        // Setup token transfers and approvals
        enableTransfers();
        vm.prank(owner);
        aSummerToken.transfer(foundation, aSummerToken.cap());
        vm.prank(foundation);
        aSummerToken.approve(address(factoryV2), TOTAL_AMOUNT);
    }

    function test_CreateVestingWalletV2() public {
        ISummerVestingWalletV2.VestingParams memory vestingParams = _getTestVestingParams();
        ISummerVestingWalletV2.PerformanceGoal[] memory performanceGoals = _getTestPerformanceGoals();

        vm.prank(foundation);
        address vestingWalletAddress = factoryV2.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );

        assertNotEq(vestingWalletAddress, address(0), "Vesting wallet should be created");
        assertEq(
            aSummerToken.balanceOf(vestingWalletAddress),
            TOTAL_AMOUNT,
            "Vesting wallet should receive all tokens"
        );
        assertEq(
            factoryV2.vestingWallets(beneficiary),
            vestingWalletAddress,
            "Factory should track vesting wallet"
        );
    }

    function test_ConfigurableCliff() public {
        ISummerVestingWalletV2.VestingParams memory vestingParams = _getTestVestingParams();
        ISummerVestingWalletV2.PerformanceGoal[] memory performanceGoals = _getTestPerformanceGoals();

        vm.prank(foundation);
        address vestingWalletAddress = factoryV2.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );

        SummerVestingWalletV2 vestingWallet = SummerVestingWalletV2(payable(vestingWalletAddress));

        // Before cliff
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            0,
            "No tokens should be vested before cliff"
        );

        // At cliff end timestamp
        vm.warp(CLIFF_END_TIMESTAMP);
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            CLIFF_AMOUNT,
            "Cliff amount should be vested at cliff end"
        );
    }

    function test_ConfigurableVestingPeriods() public {
        ISummerVestingWalletV2.VestingParams memory vestingParams = _getTestVestingParams();
        ISummerVestingWalletV2.PerformanceGoal[] memory performanceGoals = _getTestPerformanceGoals();

        vm.prank(foundation);
        address vestingWalletAddress = factoryV2.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );

        SummerVestingWalletV2 vestingWallet = SummerVestingWalletV2(payable(vestingWalletAddress));

        uint256 expectedAmountPerPeriod = TIME_VESTING_TOTAL / VESTING_PERIODS;
        assertEq(
            vestingWallet.getAmountPerPeriod(),
            expectedAmountPerPeriod,
            "Amount per period should be calculated correctly"
        );

        // Test vesting after cliff + 1 month
        vm.warp(CLIFF_END_TIMESTAMP + 30 days);
        uint256 expectedVested = CLIFF_AMOUNT + expectedAmountPerPeriod;
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            expectedVested,
            "Cliff + 1 period should be vested"
        );

        // Test vesting after cliff + 6 months
        vm.warp(CLIFF_END_TIMESTAMP + 180 days);
        expectedVested = CLIFF_AMOUNT + (expectedAmountPerPeriod * 6);
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            expectedVested,
            "Cliff + 6 periods should be vested"
        );

        // Test vesting after all periods
        vm.warp(CLIFF_END_TIMESTAMP + (VESTING_PERIODS * 30 days));
        expectedVested = CLIFF_AMOUNT + TIME_VESTING_TOTAL;
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            expectedVested,
            "All time-based tokens should be vested after all periods"
        );
    }

    function test_PerformanceGoalsWithDescriptions() public {
        ISummerVestingWalletV2.VestingParams memory vestingParams = _getTestVestingParams();
        ISummerVestingWalletV2.PerformanceGoal[] memory performanceGoals = _getTestPerformanceGoals();

        vm.prank(foundation);
        address vestingWalletAddress = factoryV2.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );

        SummerVestingWalletV2 vestingWallet = SummerVestingWalletV2(payable(vestingWalletAddress));

        // Check performance goals
        assertEq(vestingWallet.getPerformanceGoalsCount(), 2, "Should have 2 performance goals");

        ISummerVestingWalletV2.PerformanceGoal memory goal1 = vestingWallet.performanceGoals(0);
        assertEq(goal1.amount, PERFORMANCE_GOAL_1, "Goal 1 amount should match");
        assertEq(goal1.description, "500M TVL", "Goal 1 description should match");
        assertEq(goal1.reached, false, "Goal 1 should not be reached initially");

        ISummerVestingWalletV2.PerformanceGoal memory goal2 = vestingWallet.performanceGoals(1);
        assertEq(goal2.amount, PERFORMANCE_GOAL_2, "Goal 2 amount should match");
        assertEq(goal2.description, "100,000 active users", "Goal 2 description should match");
        assertEq(goal2.reached, false, "Goal 2 should not be reached initially");

        // Mark goal 1 as reached
        vm.prank(foundation);
        vestingWallet.markGoalReached(0);

        // Check that performance tokens are now vested
        vm.warp(CLIFF_END_TIMESTAMP);
        uint256 expectedVested = CLIFF_AMOUNT + PERFORMANCE_GOAL_1;
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            expectedVested,
            "Cliff + reached performance goal should be vested"
        );
    }

    function test_AddNewGoalWithDescription() public {
        ISummerVestingWalletV2.VestingParams memory vestingParams = _getTestVestingParams();
        ISummerVestingWalletV2.PerformanceGoal[] memory performanceGoals = _getTestPerformanceGoals();

        vm.prank(foundation);
        address vestingWalletAddress = factoryV2.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );

        SummerVestingWalletV2 vestingWallet = SummerVestingWalletV2(payable(vestingWalletAddress));

        uint256 newGoalAmount = 500000 ether;
        string memory newGoalDescription = "1B TVL milestone";

        // Add a new goal
        vm.startPrank(foundation);
        deal(address(aSummerToken), foundation, newGoalAmount);
        aSummerToken.approve(address(vestingWallet), newGoalAmount);
        vestingWallet.addNewGoal(newGoalAmount, newGoalDescription);
        vm.stopPrank();

        // Check that the new goal was added
        assertEq(vestingWallet.getPerformanceGoalsCount(), 3, "Should have 3 performance goals");

        ISummerVestingWalletV2.PerformanceGoal memory newGoal = vestingWallet.performanceGoals(2);
        assertEq(newGoal.amount, newGoalAmount, "New goal amount should match");
        assertEq(newGoal.description, newGoalDescription, "New goal description should match");
        assertEq(newGoal.reached, false, "New goal should not be reached initially");
    }

    function test_RecallBothTimeAndPerformanceTokens() public {
        ISummerVestingWalletV2.VestingParams memory vestingParams = _getTestVestingParams();
        ISummerVestingWalletV2.PerformanceGoal[] memory performanceGoals = _getTestPerformanceGoals();

        vm.prank(foundation);
        address vestingWalletAddress = factoryV2.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );

        SummerVestingWalletV2 vestingWallet = SummerVestingWalletV2(payable(vestingWalletAddress));

        // Warp to middle of vesting period
        vm.warp(CLIFF_END_TIMESTAMP + (9 * 30 days)); // 9 months after cliff

        // Mark only goal 1 as reached
        vm.prank(foundation);
        vestingWallet.markGoalReached(0);

        uint256 initialFoundationBalance = aSummerToken.balanceOf(foundation);

        // Recall unvested tokens
        vm.prank(foundation);
        (uint256 timeBasedRecalled, uint256 performanceBasedRecalled) = vestingWallet.recallUnvestedTokens();

        uint256 finalFoundationBalance = aSummerToken.balanceOf(foundation);

        // Calculate expected recalls
        uint256 expectedAmountPerPeriod = TIME_VESTING_TOTAL / VESTING_PERIODS;
        uint256 expectedTimeBasedRecalled = TIME_VESTING_TOTAL - (9 * expectedAmountPerPeriod); // 9 periods already vested
        uint256 expectedPerformanceBasedRecalled = PERFORMANCE_GOAL_2; // Goal 2 not reached

        assertEq(timeBasedRecalled, expectedTimeBasedRecalled, "Time-based recall should match expected");
        assertEq(performanceBasedRecalled, expectedPerformanceBasedRecalled, "Performance-based recall should match expected");
        assertEq(
            finalFoundationBalance - initialFoundationBalance,
            timeBasedRecalled + performanceBasedRecalled,
            "Foundation should receive recalled tokens"
        );

        // Check that unreached goal amount was reset
        ISummerVestingWalletV2.PerformanceGoal memory goal2 = vestingWallet.performanceGoals(1);
        assertEq(goal2.amount, 0, "Unreached goal amount should be reset to 0");
    }

    function test_CannotRecallTwice() public {
        ISummerVestingWalletV2.VestingParams memory vestingParams = _getTestVestingParams();
        ISummerVestingWalletV2.PerformanceGoal[] memory performanceGoals = _getTestPerformanceGoals();

        vm.prank(foundation);
        address vestingWalletAddress = factoryV2.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );

        SummerVestingWalletV2 vestingWallet = SummerVestingWalletV2(payable(vestingWalletAddress));

        // Warp to middle of vesting period
        vm.warp(CLIFF_END_TIMESTAMP + (9 * 30 days));

        vm.startPrank(foundation);
        // First recall
        (uint256 timeBasedRecalled1, uint256 performanceBasedRecalled1) = vestingWallet.recallUnvestedTokens();

        // Second recall should return 0
        (uint256 timeBasedRecalled2, uint256 performanceBasedRecalled2) = vestingWallet.recallUnvestedTokens();
        vm.stopPrank();

        assertGt(timeBasedRecalled1 + performanceBasedRecalled1, 0, "First recall should have tokens");
        assertEq(timeBasedRecalled2, 0, "Second time-based recall should be 0");
        assertEq(performanceBasedRecalled2, 0, "Second performance-based recall should be 0");
    }

    function test_InvalidVestingParams() public {
        // Test with cliff in the past
        ISummerVestingWalletV2.VestingParams memory invalidParams = ISummerVestingWalletV2.VestingParams({
            cliffEndTimestamp: uint64(block.timestamp - 1),
            cliffAmount: CLIFF_AMOUNT,
            vestingPeriods: VESTING_PERIODS,
            totalVestingAmount: TIME_VESTING_TOTAL
        });

        ISummerVestingWalletV2.PerformanceGoal[] memory performanceGoals = new ISummerVestingWalletV2.PerformanceGoal[](0);

        vm.expectRevert(ISummerVestingWalletV2.InvalidVestingParams.selector);
        vm.prank(foundation);
        factoryV2.createVestingWallet(beneficiary, invalidParams, performanceGoals);
    }

    function test_ReleaseVestedTokens() public {
        ISummerVestingWalletV2.VestingParams memory vestingParams = _getTestVestingParams();
        ISummerVestingWalletV2.PerformanceGoal[] memory performanceGoals = _getTestPerformanceGoals();

        vm.prank(foundation);
        address vestingWalletAddress = factoryV2.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );

        SummerVestingWalletV2 vestingWallet = SummerVestingWalletV2(payable(vestingWalletAddress));

        // Warp to cliff + 3 months and mark goal 1 as reached
        vm.warp(CLIFF_END_TIMESTAMP + (3 * 30 days));
        vm.prank(foundation);
        vestingWallet.markGoalReached(0);

        uint256 initialBeneficiaryBalance = aSummerToken.balanceOf(beneficiary);

        // Release vested tokens
        vestingWallet.release(address(aSummerToken));

        uint256 finalBeneficiaryBalance = aSummerToken.balanceOf(beneficiary);

        uint256 expectedAmountPerPeriod = TIME_VESTING_TOTAL / VESTING_PERIODS;
        uint256 expectedReleased = CLIFF_AMOUNT + (3 * expectedAmountPerPeriod) + PERFORMANCE_GOAL_1;

        assertEq(
            finalBeneficiaryBalance - initialBeneficiaryBalance,
            expectedReleased,
            "Beneficiary should receive vested tokens"
        );
    }

    function testFail_NonFoundationCannotCreateVestingWallet() public {
        ISummerVestingWalletV2.VestingParams memory vestingParams = _getTestVestingParams();
        ISummerVestingWalletV2.PerformanceGoal[] memory performanceGoals = _getTestPerformanceGoals();

        vm.prank(nonFoundation);
        factoryV2.createVestingWallet(beneficiary, vestingParams, performanceGoals);
    }

    function testFail_DuplicateVestingWallet() public {
        ISummerVestingWalletV2.VestingParams memory vestingParams = _getTestVestingParams();
        ISummerVestingWalletV2.PerformanceGoal[] memory performanceGoals = _getTestPerformanceGoals();

        vm.prank(foundation);
        factoryV2.createVestingWallet(beneficiary, vestingParams, performanceGoals);

        vm.prank(foundation);
        factoryV2.createVestingWallet(beneficiary, vestingParams, performanceGoals);
    }

    // Helper functions
    function _getTestVestingParams() private pure returns (ISummerVestingWalletV2.VestingParams memory) {
        return ISummerVestingWalletV2.VestingParams({
            cliffEndTimestamp: CLIFF_END_TIMESTAMP,
            cliffAmount: CLIFF_AMOUNT,
            vestingPeriods: VESTING_PERIODS,
            totalVestingAmount: TIME_VESTING_TOTAL
        });
    }

    function _getTestPerformanceGoals() private pure returns (ISummerVestingWalletV2.PerformanceGoal[] memory) {
        ISummerVestingWalletV2.PerformanceGoal[] memory goals = new ISummerVestingWalletV2.PerformanceGoal[](2);
        
        goals[0] = ISummerVestingWalletV2.PerformanceGoal({
            amount: PERFORMANCE_GOAL_1,
            description: "500M TVL",
            reached: false
        });
        
        goals[1] = ISummerVestingWalletV2.PerformanceGoal({
            amount: PERFORMANCE_GOAL_2,
            description: "100,000 active users",
            reached: false
        });
        
        return goals;
    }
} 