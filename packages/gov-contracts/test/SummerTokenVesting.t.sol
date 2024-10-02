// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {SummerToken} from "../src/contracts/SummerToken.sol";
import {SummerVestingWallet} from "../src/contracts/SummerVestingWallet.sol";
import {ISummerToken} from "../src/interfaces/ISummerToken.sol";

import {SummerTokenTestBase} from "./SummerTokenTestBase.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Test, console} from "forge-std/Test.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract SummerVestingTest is SummerTokenTestBase {
    address public beneficiary;
    address public nonGovernance;

    uint256 constant TIME_BASED_AMOUNT = 800000 ether;
    uint256 constant GOAL_1_AMOUNT = 50000 ether;
    uint256 constant GOAL_2_AMOUNT = 50000 ether;
    uint256 constant GOAL_3_AMOUNT = 50000 ether;
    uint256 constant GOAL_4_AMOUNT = 50000 ether;
    uint256 constant TOTAL_VESTING_AMOUNT =
        TIME_BASED_AMOUNT +
            GOAL_1_AMOUNT +
            GOAL_2_AMOUNT +
            GOAL_3_AMOUNT +
            GOAL_4_AMOUNT;

    function setUp() public override {
        super.setUp();
        aSummerToken.mint(address(this), INITIAL_SUPPLY * 10 ** 18);
        beneficiary = address(0x1);
        nonGovernance = address(0x2);
    }

    function test_CreateVestingWallet() public {
        aSummerToken.createVestingWallet(
            beneficiary,
            TIME_BASED_AMOUNT,
            GOAL_1_AMOUNT,
            GOAL_2_AMOUNT,
            GOAL_3_AMOUNT,
            GOAL_4_AMOUNT,
            SummerVestingWallet.VestingType.TeamVesting
        );
        address vestingWalletAddress = aSummerToken.vestingWallets(beneficiary);
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
        aSummerToken.createVestingWallet(
            beneficiary,
            TIME_BASED_AMOUNT,
            GOAL_1_AMOUNT,
            GOAL_2_AMOUNT,
            GOAL_3_AMOUNT,
            GOAL_4_AMOUNT,
            SummerVestingWallet.VestingType.TeamVesting
        );
    }

    function testFail_DuplicateVestingWallet() public {
        aSummerToken.createVestingWallet(
            beneficiary,
            TIME_BASED_AMOUNT,
            GOAL_1_AMOUNT,
            GOAL_2_AMOUNT,
            GOAL_3_AMOUNT,
            GOAL_4_AMOUNT,
            SummerVestingWallet.VestingType.TeamVesting
        );
        aSummerToken.createVestingWallet(
            beneficiary,
            TIME_BASED_AMOUNT,
            GOAL_1_AMOUNT,
            GOAL_2_AMOUNT,
            GOAL_3_AMOUNT,
            GOAL_4_AMOUNT,
            SummerVestingWallet.VestingType.TeamVesting
        );
    }

    function testFail_InvalidVestingType() public {
        aSummerToken.createVestingWallet(
            beneficiary,
            TIME_BASED_AMOUNT,
            GOAL_1_AMOUNT,
            GOAL_2_AMOUNT,
            GOAL_3_AMOUNT,
            GOAL_4_AMOUNT,
            SummerVestingWallet.VestingType(
                uint8(type(SummerVestingWallet.VestingType).max) + 1
            )
        );
    }

    function test_TeamVesting() public {
        aSummerToken.createVestingWallet(
            beneficiary,
            TIME_BASED_AMOUNT,
            GOAL_1_AMOUNT,
            GOAL_2_AMOUNT,
            GOAL_3_AMOUNT,
            GOAL_4_AMOUNT,
            SummerVestingWallet.VestingType.TeamVesting
        );
        address vestingWalletAddress = aSummerToken.vestingWallets(beneficiary);
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
        aSummerToken.createVestingWallet(
            beneficiary,
            TIME_BASED_AMOUNT,
            0,
            0,
            0,
            0,
            SummerVestingWallet.VestingType.InvestorExTeamVesting
        );
        address vestingWalletAddress = aSummerToken.vestingWallets(beneficiary);
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
        aSummerToken.createVestingWallet(
            beneficiary,
            TIME_BASED_AMOUNT,
            GOAL_1_AMOUNT,
            GOAL_2_AMOUNT,
            GOAL_3_AMOUNT,
            GOAL_4_AMOUNT,
            SummerVestingWallet.VestingType.TeamVesting
        );
        address vestingWalletAddress = aSummerToken.vestingWallets(beneficiary);
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
            TIME_BASED_AMOUNT / 2 + GOAL_1_AMOUNT + GOAL_3_AMOUNT,
            "Half of time-based tokens plus reached goals should be vested"
        );
    }

    function test_ReleaseVestedTokens() public {
        aSummerToken.createVestingWallet(
            beneficiary,
            TIME_BASED_AMOUNT,
            GOAL_1_AMOUNT,
            GOAL_2_AMOUNT,
            GOAL_3_AMOUNT,
            GOAL_4_AMOUNT,
            SummerVestingWallet.VestingType.TeamVesting
        );
        address vestingWalletAddress = aSummerToken.vestingWallets(beneficiary);
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
        aSummerToken.createVestingWallet(
            beneficiary,
            TIME_BASED_AMOUNT,
            GOAL_1_AMOUNT,
            GOAL_2_AMOUNT,
            GOAL_3_AMOUNT,
            GOAL_4_AMOUNT,
            SummerVestingWallet.VestingType.TeamVesting
        );
        address vestingWalletAddress = aSummerToken.vestingWallets(beneficiary);
        SummerVestingWallet vestingWallet = SummerVestingWallet(
            payable(vestingWalletAddress)
        );

        vm.warp(block.timestamp + 365 days);
        uint256 initialBalance = aSummerToken.balanceOf(address(this));

        vestingWallet.recallUnvestedTokens();

        uint256 finalBalance = aSummerToken.balanceOf(address(this));
        assertEq(
            finalBalance - initialBalance,
            TOTAL_VESTING_AMOUNT - TIME_BASED_AMOUNT / 2,
            "Admin should receive unvested tokens"
        );
    }
}
