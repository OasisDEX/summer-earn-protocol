// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerToken} from "../src/contracts/SummerToken.sol";
import {SummerVestingWallet} from "../src/contracts/SummerVestingWallet.sol";

import {ISummerToken} from "../src/interfaces/ISummerToken.sol";
import {ISummerVestingWallet} from "../src/interfaces/ISummerVestingWallet.sol";

import {SummerTokenTestBase} from "./SummerTokenTestBase.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Test, console} from "forge-std/Test.sol";

contract SummerVestingTest is SummerTokenTestBase {
    address public beneficiary;
    address public nonGovernance;
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
        enableTransfers();
        aSummerToken.mint(address(this), INITIAL_SUPPLY * 10 ** 18);
        aSummerToken.approve(
            address(vestingWalletFactoryA),
            TOTAL_VESTING_AMOUNT
        );
        beneficiary = address(0x1);
        nonGovernance = address(0x2);

        // Initialize goalAmounts array
        goalAmounts = new uint256[](4);
        goalAmounts[0] = GOAL_1_AMOUNT;
        goalAmounts[1] = GOAL_2_AMOUNT;
        goalAmounts[2] = GOAL_3_AMOUNT;
        goalAmounts[3] = GOAL_4_AMOUNT;
    }

    function test_CreateVestingWallet() public {
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

    function testFail_NonGovernanceCreateVestingWallet() public {
        vm.prank(nonGovernance);
        vestingWalletFactoryA.createVestingWallet(
            beneficiary,
            TIME_BASED_AMOUNT,
            goalAmounts,
            ISummerVestingWallet.VestingType.TeamVesting
        );
    }

    function testFail_DuplicateVestingWallet() public {
        vestingWalletFactoryA.createVestingWallet(
            beneficiary,
            TIME_BASED_AMOUNT,
            goalAmounts,
            ISummerVestingWallet.VestingType.TeamVesting
        );
        vestingWalletFactoryA.createVestingWallet(
            beneficiary,
            TIME_BASED_AMOUNT,
            goalAmounts,
            ISummerVestingWallet.VestingType.TeamVesting
        );
    }

    function testFail_InvalidVestingType() public {
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

        // After 1 year
        vm.warp(block.timestamp + 185 days);
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            TIME_BASED_AMOUNT / 2,
            "Half of time-based tokens should be vested after 1 year"
        );

        // After 2 years
        vm.warp(block.timestamp + 365 days);
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

        // After 1 year
        vm.warp(block.timestamp + 185 days);
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            TIME_BASED_AMOUNT / 2,
            "Half of tokens should be vested after 1 year"
        );

        // After 2 years
        vm.warp(block.timestamp + 365 days);
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
        uint256 initialBalance = aSummerToken.balanceOf(address(this));

        vestingWallet.recallUnvestedTokens();

        uint256 finalBalance = aSummerToken.balanceOf(address(this));
        assertEq(
            finalBalance - initialBalance,
            goalAmounts[1] + goalAmounts[3],
            "Admin should receive unvested tokens"
        );
    }

    function test_VariableNumberOfGoals() public {
        uint256[] memory customGoalAmounts = new uint256[](3);
        customGoalAmounts[0] = 30000 ether;
        customGoalAmounts[1] = 40000 ether;
        customGoalAmounts[2] = 50000 ether;

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
        vestingWallet.markGoalReached(1);
        vestingWallet.markGoalReached(3);

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
        deal(address(aSummerToken), address(this), newGoalAmount);
        aSummerToken.approve(address(vestingWallet), newGoalAmount);
        vestingWallet.addNewGoal(newGoalAmount);

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

        // Try to add a goal from a non-guardian address
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                nonGovernance,
                vestingWallet.GUARDIAN_ROLE()
            )
        );
        vm.prank(nonGovernance);
        vestingWallet.addNewGoal(10000 ether);
    }
}
