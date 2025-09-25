// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerVestingWalletV2} from "../../src/contracts/SummerVestingWalletV2.sol";
import {SummerVestingWalletFactoryV2} from "../../src/contracts/SummerVestingWalletFactoryV2.sol";
import {ISummerVestingWalletV2} from "../../src/interfaces/ISummerVestingWalletV2.sol";
import {ISummerVestingWalletFactoryV2} from "../../src/interfaces/ISummerVestingWalletFactoryV2.sol";
import {SummerTokenTestBase} from "../token/SummerTokenTestBase.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Test, console} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

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
    uint256 constant TOTAL_AMOUNT =
        CLIFF_AMOUNT +
            TIME_VESTING_TOTAL +
            PERFORMANCE_GOAL_1 +
            PERFORMANCE_GOAL_2;

    // September 1st, 2025 timestamp
    uint64 constant CLIFF_END_TIMESTAMP = 1756681200;

    function setUp() public override {
        super.setUp();

        // Setup test addresses
        foundation = address(0x3);
        nonFoundation = address(0x4);
        beneficiary = address(0x1);

        // Create V2 factory (foundation is initial owner)
        factoryV2 = new SummerVestingWalletFactoryV2(
            address(aSummerToken),
            foundation // foundation is the owner instead of using access manager
        );

        // Setup token transfers and approvals
        enableTransfers();
        vm.prank(owner);
        aSummerToken.transfer(foundation, aSummerToken.cap());
        vm.prank(foundation);
        aSummerToken.approve(address(factoryV2), TOTAL_AMOUNT);
    }

    function test_CreateVestingWalletV2() public {
        ISummerVestingWalletV2.VestingParams
            memory vestingParams = _getTestVestingParams();
        ISummerVestingWalletV2.PerformanceGoal[]
            memory performanceGoals = _getTestPerformanceGoals();

        vm.prank(foundation);
        address vestingWalletAddress = factoryV2.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );

        assertNotEq(
            vestingWalletAddress,
            address(0),
            "Vesting wallet should be created"
        );
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
        ISummerVestingWalletV2.VestingParams
            memory vestingParams = _getTestVestingParams();
        ISummerVestingWalletV2.PerformanceGoal[]
            memory performanceGoals = _getTestPerformanceGoals();

        vm.prank(foundation);
        address vestingWalletAddress = factoryV2.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );

        SummerVestingWalletV2 vestingWallet = SummerVestingWalletV2(
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
        ISummerVestingWalletV2.VestingParams
            memory vestingParams = _getTestVestingParams();
        ISummerVestingWalletV2.PerformanceGoal[]
            memory performanceGoals = _getTestPerformanceGoals();

        vm.prank(foundation);
        address vestingWalletAddress = factoryV2.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );

        SummerVestingWalletV2 vestingWallet = SummerVestingWalletV2(
            payable(vestingWalletAddress)
        );

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
        ISummerVestingWalletV2.VestingParams
            memory vestingParams = _getTestVestingParams();
        ISummerVestingWalletV2.PerformanceGoal[]
            memory performanceGoals = _getTestPerformanceGoals();

        vm.prank(foundation);
        address vestingWalletAddress = factoryV2.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );

        SummerVestingWalletV2 vestingWallet = SummerVestingWalletV2(
            payable(vestingWalletAddress)
        );

        // Check performance goals
        assertEq(
            vestingWallet.getPerformanceGoalsCount(),
            2,
            "Should have 2 performance goals"
        );

        ISummerVestingWalletV2.PerformanceGoal memory goal1 = vestingWallet
            .performanceGoals(1);
        assertEq(
            goal1.amount,
            PERFORMANCE_GOAL_1,
            "Goal 1 amount should match"
        );
        assertEq(
            goal1.description,
            "500M TVL",
            "Goal 1 description should match"
        );
        assertEq(
            goal1.reached,
            false,
            "Goal 1 should not be reached initially"
        );

        ISummerVestingWalletV2.PerformanceGoal memory goal2 = vestingWallet
            .performanceGoals(2);
        assertEq(
            goal2.amount,
            PERFORMANCE_GOAL_2,
            "Goal 2 amount should match"
        );
        assertEq(
            goal2.description,
            "100,000 active users",
            "Goal 2 description should match"
        );
        assertEq(
            goal2.reached,
            false,
            "Goal 2 should not be reached initially"
        );

        // Mark goal 1 as reached
        vm.prank(foundation);
        vestingWallet.markGoalReached(1);

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
        ISummerVestingWalletV2.VestingParams
            memory vestingParams = _getTestVestingParams();
        ISummerVestingWalletV2.PerformanceGoal[]
            memory performanceGoals = _getTestPerformanceGoals();

        vm.prank(foundation);
        address vestingWalletAddress = factoryV2.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );

        SummerVestingWalletV2 vestingWallet = SummerVestingWalletV2(
            payable(vestingWalletAddress)
        );

        uint256 newGoalAmount = 500000 ether;
        string memory newGoalDescription = "1B TVL milestone";

        // Add a new goal
        vm.startPrank(foundation);
        deal(address(aSummerToken), foundation, newGoalAmount);
        aSummerToken.approve(address(vestingWallet), newGoalAmount);
        vestingWallet.addNewGoal(newGoalAmount, newGoalDescription);
        vm.stopPrank();

        // Check that the new goal was added
        assertEq(
            vestingWallet.getPerformanceGoalsCount(),
            3,
            "Should have 3 performance goals"
        );

        ISummerVestingWalletV2.PerformanceGoal memory newGoal = vestingWallet
            .performanceGoals(3);
        assertEq(newGoal.amount, newGoalAmount, "New goal amount should match");
        assertEq(
            newGoal.description,
            newGoalDescription,
            "New goal description should match"
        );
        assertEq(
            newGoal.reached,
            false,
            "New goal should not be reached initially"
        );
    }

    function test_RecallTakesEverything() public {
        ISummerVestingWalletV2.VestingParams
            memory vestingParams = _getTestVestingParams();
        ISummerVestingWalletV2.PerformanceGoal[]
            memory performanceGoals = _getTestPerformanceGoals();

        vm.prank(foundation);
        address vestingWalletAddress = factoryV2.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );

        SummerVestingWalletV2 vestingWallet = SummerVestingWalletV2(
            payable(vestingWalletAddress)
        );

        // Warp to middle of vesting period - some tokens are now vested
        vm.warp(CLIFF_END_TIMESTAMP + (9 * 30 days)); // 9 months after cliff

        // Mark a performance goal as reached
        vm.prank(foundation);
        vestingWallet.markGoalReached(1);

        uint256 initialFoundationBalance = aSummerToken.balanceOf(foundation);
        uint256 initialWalletBalance = aSummerToken.balanceOf(
            address(vestingWallet)
        );

        // Gentleman's agreement: beneficiary should claim before recall
        // But admin can take EVERYTHING regardless of vesting status
        vm.prank(foundation);
        vm.expectEmit(true, true, true, true);
        emit ISummerVestingWalletV2.UnvestedTokensRecalled(
            initialWalletBalance
        );
        vestingWallet.recallUnvestedTokens();

        uint256 finalFoundationBalance = aSummerToken.balanceOf(foundation);

        assertEq(
            finalFoundationBalance - initialFoundationBalance,
            initialWalletBalance,
            "Foundation should receive ALL tokens from wallet"
        );

        // Wallet should be completely empty and bricked
        assertEq(
            aSummerToken.balanceOf(address(vestingWallet)),
            0,
            "Wallet should be empty"
        );
        assertTrue(
            vestingWallet.isRecalled(),
            "Wallet should be marked as recalled"
        );

        // No more vesting after recall
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                uint64(block.timestamp)
            ),
            0,
            "No vesting after recall"
        );
    }

    function test_RecallBricksWallet() public {
        ISummerVestingWalletV2.VestingParams
            memory vestingParams = _getTestVestingParams();
        ISummerVestingWalletV2.PerformanceGoal[]
            memory performanceGoals = _getTestPerformanceGoals();

        vm.prank(foundation);
        address vestingWalletAddress = factoryV2.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );

        SummerVestingWalletV2 vestingWallet = SummerVestingWalletV2(
            payable(vestingWalletAddress)
        );

        // Warp to middle of vesting period (9 months after cliff)
        vm.warp(CLIFF_END_TIMESTAMP + (9 * 30 days));

        uint256 balanceBefore = aSummerToken.balanceOf(address(vestingWallet));
        uint256 adminBalanceBefore = aSummerToken.balanceOf(foundation);

        vm.prank(foundation);
        // First recall should take ALL tokens and brick the wallet
        vm.expectEmit(true, true, true, true);
        emit ISummerVestingWalletV2.UnvestedTokensRecalled(balanceBefore);
        vestingWallet.recallUnvestedTokens();

        // Check that wallet is now bricked
        assertTrue(
            vestingWallet.isRecalled(),
            "Wallet should be marked as recalled"
        );

        // Check that ALL tokens were transferred
        assertEq(
            aSummerToken.balanceOf(address(vestingWallet)),
            0,
            "Wallet should be empty"
        );
        assertEq(
            aSummerToken.balanceOf(foundation),
            adminBalanceBefore + balanceBefore,
            "Admin should receive all tokens"
        );

        // No more vesting should be possible
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                uint64(block.timestamp)
            ),
            0,
            "No vesting after recall"
        );

        // Second recall should fail
        vm.expectRevert(ISummerVestingWalletV2.TokensAlreadyRecalled.selector);
        vm.prank(foundation);
        vestingWallet.recallUnvestedTokens();
    }

    function test_InvalidVestingParams() public {
        // Test with cliff in the past
        ISummerVestingWalletV2.VestingParams
            memory invalidParams = ISummerVestingWalletV2.VestingParams({
                cliffEndTimestamp: uint64(block.timestamp - 1),
                cliffAmount: CLIFF_AMOUNT,
                vestingPeriods: VESTING_PERIODS,
                totalVestingAmount: TIME_VESTING_TOTAL
            });

        ISummerVestingWalletV2.PerformanceGoal[]
            memory performanceGoals = new ISummerVestingWalletV2.PerformanceGoal[](
                0
            );

        vm.expectRevert(ISummerVestingWalletV2.InvalidVestingParams.selector);
        vm.prank(foundation);
        factoryV2.createVestingWallet(
            beneficiary,
            invalidParams,
            performanceGoals
        );

        // Test with positive amount but 0 periods
        invalidParams = ISummerVestingWalletV2.VestingParams({
            cliffEndTimestamp: uint64(block.timestamp + 180 days),
            cliffAmount: CLIFF_AMOUNT,
            vestingPeriods: 0,
            totalVestingAmount: TIME_VESTING_TOTAL
        });

        vm.expectRevert(ISummerVestingWalletV2.InvalidVestingParams.selector);
        vm.prank(foundation);
        factoryV2.createVestingWallet(
            beneficiary,
            invalidParams,
            performanceGoals
        );
    }

    function test_ZeroVestingPeriodsWithZeroAmount() public {
        // Test cliff + performance only vesting (no time-based vesting)
        ISummerVestingWalletV2.VestingParams
            memory vestingParams = ISummerVestingWalletV2.VestingParams({
                cliffEndTimestamp: CLIFF_END_TIMESTAMP,
                cliffAmount: CLIFF_AMOUNT,
                vestingPeriods: 0, // No time-based vesting periods
                totalVestingAmount: 0 // No time-based vesting amount
            });

        ISummerVestingWalletV2.PerformanceGoal[]
            memory performanceGoals = _getTestPerformanceGoals();

        uint256 totalAmount = vestingParams.cliffAmount +
            PERFORMANCE_GOAL_1 +
            PERFORMANCE_GOAL_2;

        vm.prank(foundation);
        aSummerToken.approve(address(factoryV2), totalAmount);

        vm.prank(foundation);
        address vestingWalletAddress = factoryV2.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );

        SummerVestingWalletV2 vestingWallet = SummerVestingWalletV2(
            payable(vestingWalletAddress)
        );

        // Check that amount per period is 0
        assertEq(
            vestingWallet.getAmountPerPeriod(),
            0,
            "Amount per period should be 0"
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

        // At cliff
        vm.warp(CLIFF_END_TIMESTAMP);
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            CLIFF_AMOUNT,
            "Only cliff amount should be vested"
        );

        // Mark performance goal as reached
        vm.prank(foundation);
        vestingWallet.markGoalReached(1);

        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            CLIFF_AMOUNT + PERFORMANCE_GOAL_1,
            "Cliff + performance goal should be vested"
        );

        // Even after a long time, no additional time-based vesting
        vm.warp(CLIFF_END_TIMESTAMP + 365 days);
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            CLIFF_AMOUNT + PERFORMANCE_GOAL_1,
            "Should still only have cliff + performance goal"
        );
    }

    function test_ReleaseVestedTokens() public {
        ISummerVestingWalletV2.VestingParams
            memory vestingParams = _getTestVestingParams();
        ISummerVestingWalletV2.PerformanceGoal[]
            memory performanceGoals = _getTestPerformanceGoals();

        vm.prank(foundation);
        address vestingWalletAddress = factoryV2.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );

        SummerVestingWalletV2 vestingWallet = SummerVestingWalletV2(
            payable(vestingWalletAddress)
        );

        // Warp to cliff + 3 months and mark goal 1 as reached
        vm.warp(CLIFF_END_TIMESTAMP + (3 * 30 days));
        vm.prank(foundation);
        vestingWallet.markGoalReached(1);

        uint256 initialBeneficiaryBalance = aSummerToken.balanceOf(beneficiary);

        // Release vested tokens
        vestingWallet.release(address(aSummerToken));

        uint256 finalBeneficiaryBalance = aSummerToken.balanceOf(beneficiary);

        uint256 expectedAmountPerPeriod = TIME_VESTING_TOTAL / VESTING_PERIODS;
        uint256 expectedReleased = CLIFF_AMOUNT +
            (3 * expectedAmountPerPeriod) +
            PERFORMANCE_GOAL_1;

        assertEq(
            finalBeneficiaryBalance - initialBeneficiaryBalance,
            expectedReleased,
            "Beneficiary should receive vested tokens"
        );
    }

    function test_NonFoundationCannotCreateVestingWallet() public {
        ISummerVestingWalletV2.VestingParams
            memory vestingParams = _getTestVestingParams();
        ISummerVestingWalletV2.PerformanceGoal[]
            memory performanceGoals = _getTestPerformanceGoals();

        vm.prank(nonFoundation);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                nonFoundation
            )
        );
        factoryV2.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );
    }

    function test_OnlyFactoryOwnerCanManageVestingWallet() public {
        // Create vesting wallet
        ISummerVestingWalletV2.VestingParams
            memory vestingParams = _getTestVestingParams();
        ISummerVestingWalletV2.PerformanceGoal[]
            memory performanceGoals = _getTestPerformanceGoals();

        vm.prank(foundation);
        address vestingWalletAddress = factoryV2.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );

        SummerVestingWalletV2 vestingWallet = SummerVestingWalletV2(
            payable(vestingWalletAddress)
        );

        // Non-owner cannot add goals
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerVestingWalletV2.CallerIsNotFactoryOwner.selector,
                nonFoundation
            )
        );
        vm.prank(nonFoundation);
        vestingWallet.addNewGoal(1000 ether, "Test goal");

        // Non-owner cannot mark goals as reached
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerVestingWalletV2.CallerIsNotFactoryOwner.selector,
                nonFoundation
            )
        );
        vm.prank(nonFoundation);
        vestingWallet.markGoalReached(1);

        // Non-owner cannot recall tokens
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerVestingWalletV2.CallerIsNotFactoryOwner.selector,
                nonFoundation
            )
        );
        vm.prank(nonFoundation);
        vestingWallet.recallUnvestedTokens();

        // Factory owner (foundation) can manage the vesting wallet
        vm.prank(foundation);
        vestingWallet.markGoalReached(1); // This should work
    }

    function test_FactoryOwnershipTransfer() public {
        address newOwner = address(0x999);

        // Create vesting wallet first (before ownership transfer)
        ISummerVestingWalletV2.VestingParams
            memory vestingParams = _getTestVestingParams();
        ISummerVestingWalletV2.PerformanceGoal[]
            memory performanceGoals = _getTestPerformanceGoals();

        vm.prank(foundation);
        address vestingWalletAddress = factoryV2.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );

        SummerVestingWalletV2 vestingWallet = SummerVestingWalletV2(
            payable(vestingWalletAddress)
        );

        // Transfer ownership to new address (simulating multisig transfer)
        vm.prank(foundation);
        factoryV2.transferOwnership(newOwner);

        // Verify ownership changed
        assertEq(
            factoryV2.owner(),
            newOwner,
            "Ownership should be transferred"
        );

        // Old owner cannot manage anymore
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerVestingWalletV2.CallerIsNotFactoryOwner.selector,
                foundation
            )
        );
        vm.prank(foundation);
        vestingWallet.markGoalReached(1);

        // New owner can manage
        vm.prank(newOwner);
        vestingWallet.markGoalReached(1); // This should work
    }

    function test_DuplicateVestingWallet() public {
        ISummerVestingWalletV2.VestingParams
            memory vestingParams = _getTestVestingParams();
        ISummerVestingWalletV2.PerformanceGoal[]
            memory performanceGoals = _getTestPerformanceGoals();

        vm.prank(foundation);

        factoryV2.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );
        vm.prank(foundation);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerVestingWalletFactoryV2
                    .VestingWalletAlreadyExists
                    .selector,
                beneficiary
            )
        );
        factoryV2.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );
    }

    // Helper functions
    function _getTestVestingParams()
        private
        pure
        returns (ISummerVestingWalletV2.VestingParams memory)
    {
        return
            ISummerVestingWalletV2.VestingParams({
                cliffEndTimestamp: CLIFF_END_TIMESTAMP,
                cliffAmount: CLIFF_AMOUNT,
                vestingPeriods: VESTING_PERIODS,
                totalVestingAmount: TIME_VESTING_TOTAL
            });
    }

    function _getTestPerformanceGoals()
        private
        pure
        returns (ISummerVestingWalletV2.PerformanceGoal[] memory)
    {
        ISummerVestingWalletV2.PerformanceGoal[]
            memory goals = new ISummerVestingWalletV2.PerformanceGoal[](2);

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
