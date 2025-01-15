// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerToken} from "../../src/contracts/SummerToken.sol";
import {SummerVestingWallet} from "../../src/contracts/SummerVestingWallet.sol";
import {ISummerToken} from "../../src/interfaces/ISummerToken.sol";
import {ISummerVestingWallet} from "../../src/interfaces/ISummerVestingWallet.sol";
import {SummerTokenTestBase} from "../token/SummerTokenTestBase.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Test, console} from "forge-std/Test.sol";

contract SummerVestingTest is SummerTokenTestBase {
    address public beneficiary;
    address public foundation;
    address public nonFoundation;
    uint256[] goalAmounts;

    uint256 constant TIME_BASED_AMOUNT = 800000 ether;
    uint256 constant GOAL_1_AMOUNT = 30000 ether;
    uint256 constant GOAL_2_AMOUNT = 40000 ether;
    uint256 constant GOAL_3_AMOUNT = 50000 ether;
    uint256 constant GOAL_4_AMOUNT = 60000 ether;
    uint256 constant TOTAL_VESTING_AMOUNT =
        TIME_BASED_AMOUNT +
            GOAL_1_AMOUNT +
            GOAL_2_AMOUNT +
            GOAL_3_AMOUNT +
            GOAL_4_AMOUNT;

    function setUp() public override {
        super.setUp();

        // Setup test addresses
        foundation = address(0x3);
        nonFoundation = address(0x4);
        beneficiary = address(0x1);

        // Grant foundation role explicitly for this test suite
        vm.startPrank(address(timelockA));
        accessManagerA.grantFoundationRole(foundation);
        vm.stopPrank();

        // Setup token transfers and approvals
        enableTransfers();
        vm.prank(owner);
        aSummerToken.transfer(foundation, aSummerToken.cap());
        vm.prank(foundation);
        aSummerToken.approve(
            address(vestingWalletFactoryA),
            TOTAL_VESTING_AMOUNT
        );

        // Initialize goalAmounts array
        goalAmounts = new uint256[](4);
        goalAmounts[0] = GOAL_1_AMOUNT;
        goalAmounts[1] = GOAL_2_AMOUNT;
        goalAmounts[2] = GOAL_3_AMOUNT;
        goalAmounts[3] = GOAL_4_AMOUNT;
    }

    function test_CreateVestingWallet() public {
        vm.prank(foundation);
        vestingWalletFactoryA.createVestingWallet(
            beneficiary,
            TIME_BASED_AMOUNT,
            goalAmounts,
            ISummerVestingWallet.VestingType.TeamVesting
        );
        address vestingWalletAddress = vestingWalletFactoryA.vestingWallets(
            beneficiary
        );
        assertNotEq(
            vestingWalletAddress,
            address(0),
            "Vesting wallet should be created"
        );
        assertEq(
            aSummerToken.balanceOf(vestingWalletAddress),
            TOTAL_VESTING_AMOUNT,
            "Vesting wallet should receive tokens"
        );
    }

    function testFail_NonFoundationCreateVestingWallet() public {
        vm.prank(nonFoundation);
        vestingWalletFactoryA.createVestingWallet(
            beneficiary,
            TIME_BASED_AMOUNT,
            goalAmounts,
            ISummerVestingWallet.VestingType.TeamVesting
        );
    }

    function testFail_DuplicateVestingWallet() public {
        vm.prank(foundation);
        vestingWalletFactoryA.createVestingWallet(
            beneficiary,
            TIME_BASED_AMOUNT,
            goalAmounts,
            ISummerVestingWallet.VestingType.TeamVesting
        );
        vm.prank(foundation);
        vestingWalletFactoryA.createVestingWallet(
            beneficiary,
            TIME_BASED_AMOUNT,
            goalAmounts,
            ISummerVestingWallet.VestingType.TeamVesting
        );
    }

    function testFail_InvalidVestingType() public {
        vm.prank(foundation);
        vestingWalletFactoryA.createVestingWallet(
            beneficiary,
            TIME_BASED_AMOUNT,
            goalAmounts,
            ISummerVestingWallet.VestingType(
                uint8(type(ISummerVestingWallet.VestingType).max) + 1
            )
        );
    }

    function test_TeamVesting() public {
        vm.prank(foundation);
        vestingWalletFactoryA.createVestingWallet(
            beneficiary,
            TIME_BASED_AMOUNT,
            goalAmounts,
            ISummerVestingWallet.VestingType.TeamVesting
        );
        address vestingWalletAddress = vestingWalletFactoryA.vestingWallets(
            beneficiary
        );
        SummerVestingWallet vestingWallet = SummerVestingWallet(
            payable(vestingWalletAddress)
        );

        // Before cliff
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            0,
            "No tokens should be vested before cliff"
        );

        // After cliff (6 months)
        vm.warp(block.timestamp + 180 days);
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            TIME_BASED_AMOUNT / 4,
            "1/4 of time-based tokens should be vested after cliff"
        );

        // After 1 year (12 months)
        vm.warp(block.timestamp + 180 days);
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            TIME_BASED_AMOUNT / 2,
            "Half of time-based tokens should be vested after 1 year"
        );

        // After 2 years (24 months)
        vm.warp(block.timestamp + 360 days);
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            TIME_BASED_AMOUNT,
            "All time-based tokens should be vested after 2 years"
        );
    }

    function test_InvestorExTeamVesting() public {
        vm.prank(foundation);
        vestingWalletFactoryA.createVestingWallet(
            beneficiary,
            TIME_BASED_AMOUNT,
            new uint256[](0),
            ISummerVestingWallet.VestingType.InvestorExTeamVesting
        );
        address vestingWalletAddress = vestingWalletFactoryA.vestingWallets(
            beneficiary
        );
        SummerVestingWallet vestingWallet = SummerVestingWallet(
            payable(vestingWalletAddress)
        );

        // Before cliff
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            0,
            "No tokens should be vested before cliff"
        );

        // After cliff (6 months)
        vm.warp(block.timestamp + 180 days);
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            TIME_BASED_AMOUNT / 4,
            "1/4 of tokens should be vested after cliff"
        );

        // After 1 year (12 months)
        vm.warp(block.timestamp + 180 days);
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            TIME_BASED_AMOUNT / 2,
            "Half of tokens should be vested after 1 year"
        );

        // After 2 years (24 months)
        vm.warp(block.timestamp + 360 days);
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            TIME_BASED_AMOUNT,
            "All tokens should be vested after 2 years"
        );
    }

    function test_PerformanceBasedVesting() public {
        vm.startPrank(foundation);
        vestingWalletFactoryA.createVestingWallet(
            beneficiary,
            TIME_BASED_AMOUNT,
            goalAmounts,
            ISummerVestingWallet.VestingType.TeamVesting
        );
        address vestingWalletAddress = vestingWalletFactoryA.vestingWallets(
            beneficiary
        );
        SummerVestingWallet vestingWallet = SummerVestingWallet(
            payable(vestingWalletAddress)
        );

        // Mark goals as reached
        vestingWallet.markGoalReached(1);
        vestingWallet.markGoalReached(3);
        vm.stopPrank();

        // After 1 year
        vm.warp(block.timestamp + 365 days);
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            TIME_BASED_AMOUNT / 2 + goalAmounts[0] + goalAmounts[2],
            "Half of time-based tokens plus reached goals should be vested"
        );
    }

    function test_ReleaseVestedTokens() public {
        vm.prank(foundation);
        vestingWalletFactoryA.createVestingWallet(
            beneficiary,
            TIME_BASED_AMOUNT,
            goalAmounts,
            ISummerVestingWallet.VestingType.TeamVesting
        );
        address vestingWalletAddress = vestingWalletFactoryA.vestingWallets(
            beneficiary
        );
        SummerVestingWallet vestingWallet = SummerVestingWallet(
            payable(vestingWalletAddress)
        );

        vm.warp(block.timestamp + 365 days);
        uint256 initialBalance = aSummerToken.balanceOf(beneficiary);

        vestingWallet.release(address(aSummerToken));

        uint256 finalBalance = aSummerToken.balanceOf(beneficiary);
        assertEq(
            finalBalance - initialBalance,
            TIME_BASED_AMOUNT / 2,
            "Beneficiary should receive vested tokens"
        );
    }

    function test_RecallUnvestedTokens() public {
        vm.startPrank(foundation);
        vestingWalletFactoryA.createVestingWallet(
            beneficiary,
            TIME_BASED_AMOUNT,
            goalAmounts,
            ISummerVestingWallet.VestingType.TeamVesting
        );
        address vestingWalletAddress = vestingWalletFactoryA.vestingWallets(
            beneficiary
        );
        SummerVestingWallet vestingWallet = SummerVestingWallet(
            payable(vestingWalletAddress)
        );

        vm.warp(block.timestamp + 365 days);
        vestingWallet.markGoalReached(1);
        vestingWallet.markGoalReached(3);
        uint256 initialBalance = aSummerToken.balanceOf(foundation);

        vestingWallet.recallUnvestedTokens();

        uint256 finalBalance = aSummerToken.balanceOf(foundation);
        assertEq(
            finalBalance - initialBalance,
            goalAmounts[1] + goalAmounts[3],
            "Foundation should receive unvested tokens"
        );
        vm.stopPrank();
    }

    function test_VariableNumberOfGoals() public {
        uint256[] memory customGoalAmounts = new uint256[](3);
        customGoalAmounts[0] = 30000 ether;
        customGoalAmounts[1] = 40000 ether;
        customGoalAmounts[2] = 50000 ether;

        vm.prank(foundation);
        vestingWalletFactoryA.createVestingWallet(
            beneficiary,
            TIME_BASED_AMOUNT,
            customGoalAmounts,
            ISummerVestingWallet.VestingType.TeamVesting
        );
        address vestingWalletAddress = vestingWalletFactoryA.vestingWallets(
            beneficiary
        );
        SummerVestingWallet vestingWallet = SummerVestingWallet(
            payable(vestingWalletAddress)
        );

        // Mark goals as reached
        vm.startPrank(foundation);
        vestingWallet.markGoalReached(1);
        vestingWallet.markGoalReached(3);
        vm.stopPrank();

        // After 1 year
        vm.warp(block.timestamp + 365 days);
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            TIME_BASED_AMOUNT / 2 + customGoalAmounts[0] + customGoalAmounts[2],
            "Half of time-based tokens plus reached goals should be vested"
        );
    }

    function test_AddNewGoal() public {
        vm.startPrank(foundation);
        vestingWalletFactoryA.createVestingWallet(
            beneficiary,
            TIME_BASED_AMOUNT,
            goalAmounts,
            ISummerVestingWallet.VestingType.TeamVesting
        );
        address vestingWalletAddress = vestingWalletFactoryA.vestingWallets(
            beneficiary
        );
        SummerVestingWallet vestingWallet = SummerVestingWallet(
            payable(vestingWalletAddress)
        );

        uint256 initialGoalCount = goalAmounts.length;
        uint256 newGoalAmount = 60000 ether;

        // Add a new goal
        deal(address(aSummerToken), foundation, newGoalAmount);
        aSummerToken.approve(address(vestingWallet), newGoalAmount);
        vestingWallet.addNewGoal(newGoalAmount);
        vm.stopPrank();

        // Check that the new goal was added
        assertEq(
            vestingWallet.goalAmounts(initialGoalCount),
            newGoalAmount,
            "New goal amount should be added"
        );
        assertEq(
            vestingWallet.goalsReached(initialGoalCount),
            false,
            "New goal should not be reached"
        );

        // Mark the new goal as reached
        vm.prank(foundation);
        vestingWallet.markGoalReached(initialGoalCount + 1);

        // After 1 year
        vm.warp(block.timestamp + 365 days);
        uint256 expectedVestedAmount = TIME_BASED_AMOUNT / 2 + newGoalAmount;
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            expectedVestedAmount,
            "Half of time-based tokens plus new goal amount should be vested"
        );

        // Try to add a goal from a non-foundation address
        vm.expectRevert(
            abi.encodeWithSignature(
                "CallerIsNotFoundation(address)",
                nonFoundation
            )
        );
        vm.prank(nonFoundation);
        vestingWallet.addNewGoal(10000 ether);
    }

    function test_ZeroAddressToken() public {
        uint64 startTimestamp = uint64(block.timestamp);

        vm.startPrank(foundation);
        // Expect revert with the full error including the address parameter
        vm.expectRevert(
            abi.encodeWithSignature("InvalidToken(address)", address(0))
        );
        new SummerVestingWallet(
            address(0),
            beneficiary,
            startTimestamp,
            ISummerVestingWallet.VestingType.TeamVesting,
            TIME_BASED_AMOUNT,
            goalAmounts,
            address(accessManagerA)
        );
        vm.stopPrank();
    }

    function test_RecallUnvestedTokens_CantRecallTwice() public {
        // Create a vesting wallet with team vesting type
        vm.startPrank(foundation);
        vestingWalletFactoryA.createVestingWallet(
            beneficiary,
            TIME_BASED_AMOUNT,
            goalAmounts,
            ISummerVestingWallet.VestingType.TeamVesting
        );
        vm.stopPrank();

        address vestingWalletAddress = vestingWalletFactoryA.vestingWallets(
            beneficiary
        );
        SummerVestingWallet vestingWallet = SummerVestingWallet(
            payable(vestingWalletAddress)
        );

        // Warp time and mark some goals as reached (goals 1 and 3)
        vm.warp(block.timestamp + 365 days);
        vm.startPrank(foundation);
        vestingWallet.markGoalReached(1);
        vestingWallet.markGoalReached(3);
        vm.stopPrank();

        // Calculate expected unvested amount (goals 2 and 4 are not reached)
        uint256 expectedUnvestedAmount = goalAmounts[1] + goalAmounts[3];

        // First recall of unvested tokens
        vm.startPrank(foundation);
        uint256 initialBalance = aSummerToken.balanceOf(foundation);
        vestingWallet.recallUnvestedTokens();
        uint256 firstRecallBalance = aSummerToken.balanceOf(foundation);
        vm.stopPrank();

        // Verify first recall worked as expected
        assertEq(
            firstRecallBalance - initialBalance,
            expectedUnvestedAmount,
            "First recall should receive unvested tokens"
        );

        // Second recall of unvested tokens should return 0
        vm.startPrank(foundation);
        vestingWallet.recallUnvestedTokens();
        uint256 secondRecallBalance = aSummerToken.balanceOf(foundation);
        vm.stopPrank();

        // Verify that the second recall didn't transfer any tokens
        assertEq(
            secondRecallBalance,
            firstRecallBalance,
            "Second recall should not transfer any tokens"
        );

        // Verify that unreached goal amounts were reset to 0
        assertEq(
            vestingWallet.goalAmounts(1),
            0,
            "Unreached goal 2 should be reset to 0"
        );
        assertEq(
            vestingWallet.goalAmounts(3),
            0,
            "Unreached goal 4 should be reset to 0"
        );

        // Verify that reached goal amounts remain unchanged
        assertEq(
            vestingWallet.goalAmounts(0),
            goalAmounts[0],
            "Reached goal 1 should remain unchanged"
        );
        assertEq(
            vestingWallet.goalAmounts(2),
            goalAmounts[2],
            "Reached goal 3 should remain unchanged"
        );
    }

    function test_TimeBasedVestingCap() public {
        // Create vesting wallet with team vesting type
        vm.startPrank(foundation);
        vestingWalletFactoryA.createVestingWallet(
            beneficiary,
            TIME_BASED_AMOUNT,
            goalAmounts,
            ISummerVestingWallet.VestingType.TeamVesting
        );
        vm.stopPrank();

        address vestingWalletAddress = vestingWalletFactoryA.vestingWallets(
            beneficiary
        );
        SummerVestingWallet vestingWallet = SummerVestingWallet(
            payable(vestingWalletAddress)
        );

        // Warp time to well after vesting period (e.g., 3 years)
        vm.warp(block.timestamp + 1095 days); // 3 years

        // Check vested amount
        uint256 vestedAmount = vestingWallet.vestedAmount(
            address(aSummerToken),
            SafeCast.toUint64(block.timestamp)
        );

        // Verify that time-based vesting is capped
        assertEq(
            vestedAmount,
            TIME_BASED_AMOUNT,
            "Time-based vesting should be capped at TIME_BASED_AMOUNT even after vesting period"
        );

        // Mark no goals as reached
        uint256 initialBalance = aSummerToken.balanceOf(beneficiary);

        // Release tokens
        vestingWallet.release(address(aSummerToken));

        // Verify released amount
        uint256 finalBalance = aSummerToken.balanceOf(beneficiary);
        assertEq(
            finalBalance - initialBalance,
            TIME_BASED_AMOUNT,
            "Only time-based tokens should be released, even after vesting period"
        );

        // Verify remaining tokens are still locked
        assertEq(
            aSummerToken.balanceOf(address(vestingWallet)),
            GOAL_1_AMOUNT + GOAL_2_AMOUNT + GOAL_3_AMOUNT + GOAL_4_AMOUNT,
            "Performance-based tokens should remain locked"
        );
    }

    function test_InvestorExTeamVestingWithGoals() public {
        assertGt(goalAmounts.length, 0, "Goal amount should be greater than 0");

        vm.startPrank(foundation);
        // Try to create an InvestorExTeamVesting wallet with goals
        vm.expectRevert(abi.encodeWithSignature("OnlyTeamVesting()"));
        vestingWalletFactoryA.createVestingWallet(
            beneficiary,
            TIME_BASED_AMOUNT,
            goalAmounts,
            ISummerVestingWallet.VestingType.InvestorExTeamVesting
        );
        vm.stopPrank();
    }
}
