// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {SummerToken} from "../../src/contracts/SummerToken.sol";
import {SummerVestingWallet} from "../../src/contracts/SummerVestingWallet.sol";
import {ISummerToken} from "../../src/interfaces/ISummerToken.sol";

import {SummerTokenTest} from "./SummerToken.t.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Test, console} from "forge-std/Test.sol";

contract SummerVestingTest is SummerTokenTest {
    address public beneficiary;
    address public nonGovernance;

    uint256 constant VESTING_AMOUNT = 1000000 ether;

    function setUp() public override {
        super.setUp();
        beneficiary = address(0x1);
        nonGovernance = address(0x2);
    }

    function test_CreateVestingWallet() public {
        aSummerToken.createVestingWallet(
            beneficiary,
            VESTING_AMOUNT,
            SummerVestingWallet.VestingType.SixMonthCliff
        );
        address vestingWalletAddress = aSummerToken.vestingWallets(beneficiary);
        assertNotEq(
            vestingWalletAddress,
            address(0),
            "Vesting wallet should be created"
        );
        assertEq(
            aSummerToken.balanceOf(vestingWalletAddress),
            VESTING_AMOUNT,
            "Vesting wallet should receive tokens"
        );
    }

    function testFail_NonGovernanceCreateVestingWallet() public {
        vm.prank(nonGovernance);
        aSummerToken.createVestingWallet(
            beneficiary,
            VESTING_AMOUNT,
            SummerVestingWallet.VestingType.SixMonthCliff
        );
    }

    function testFail_DuplicateVestingWallet() public {
        aSummerToken.createVestingWallet(
            beneficiary,
            VESTING_AMOUNT,
            SummerVestingWallet.VestingType.SixMonthCliff
        );
        aSummerToken.createVestingWallet(
            beneficiary,
            VESTING_AMOUNT,
            SummerVestingWallet.VestingType.SixMonthCliff
        );
    }

    function testFail_InvalidVestingType() public {
        aSummerToken.createVestingWallet(
            beneficiary,
            VESTING_AMOUNT,
            SummerVestingWallet.VestingType(
                uint8(type(SummerVestingWallet.VestingType).max) + 1
            )
        );
    }

    function test_SixMonthCliffVesting() public {
        aSummerToken.createVestingWallet(
            beneficiary,
            VESTING_AMOUNT,
            SummerVestingWallet.VestingType.SixMonthCliff
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

        // After cliff
        vm.warp(block.timestamp + 181 days);
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            VESTING_AMOUNT,
            "All tokens should be vested after cliff"
        );

        // Long after cliff
        vm.warp(block.timestamp + 365 days);
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            VESTING_AMOUNT,
            "All tokens should remain vested long after cliff"
        );
    }

    function test_TwoYearQuarterlyVesting() public {
        aSummerToken.createVestingWallet(
            beneficiary,
            VESTING_AMOUNT,
            SummerVestingWallet.VestingType.TwoYearQuarterly
        );
        address vestingWalletAddress = aSummerToken.vestingWallets(beneficiary);
        console.log("Vesting wallet address:", vestingWalletAddress);
        SummerVestingWallet vestingWallet = SummerVestingWallet(
            payable(vestingWalletAddress)
        );
        // At start
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            0,
            "No tokens should be vested at start"
        );
        assertEq(
            aSummerToken.balanceOf(vestingWalletAddress),
            VESTING_AMOUNT,
            "Vesting wallet should receive tokens"
        );
        // After one quarter
        vm.warp(block.timestamp + 91 days);

        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            VESTING_AMOUNT / 8,
            "1/8 of tokens should be vested after one quarter"
        );

        // After one year
        vm.warp(block.timestamp + 274 days);
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            VESTING_AMOUNT / 2,
            "Half of tokens should be vested after one year"
        );

        // After two years
        vm.warp(block.timestamp + 365 days);
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            VESTING_AMOUNT,
            "All tokens should be vested after two years"
        );
    }

    function test_QuarterlyVestingEdgeCase() public {
        aSummerToken.createVestingWallet(
            beneficiary,
            VESTING_AMOUNT,
            SummerVestingWallet.VestingType.TwoYearQuarterly
        );
        address vestingWalletAddress = aSummerToken.vestingWallets(beneficiary);
        SummerVestingWallet vestingWallet = SummerVestingWallet(
            payable(vestingWalletAddress)
        );
        uint64 timestamp = uint64(block.timestamp % 2 ** 64);
        // Just before quarter end
        vm.warp(block.timestamp + 90 days);
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            0,
            "No tokens should be vested just before quarter end"
        );

        // At quarter end
        vm.warp(block.timestamp + 1 days);
        assertEq(
            vestingWallet.vestedAmount(
                address(aSummerToken),
                SafeCast.toUint64(block.timestamp)
            ),
            VESTING_AMOUNT / 8,
            "1/8 of tokens should be vested at quarter end"
        );
    }

    function test_ReleaseVestedTokens() public {
        aSummerToken.createVestingWallet(
            beneficiary,
            VESTING_AMOUNT,
            SummerVestingWallet.VestingType.SixMonthCliff
        );
        address vestingWalletAddress = aSummerToken.vestingWallets(beneficiary);
        SummerVestingWallet vestingWallet = SummerVestingWallet(
            payable(vestingWalletAddress)
        );

        vm.warp(block.timestamp + 181 days);
        uint256 initialBalance = aSummerToken.balanceOf(beneficiary);

        vm.prank(beneficiary);
        vestingWallet.release(address(aSummerToken));

        uint256 finalBalance = aSummerToken.balanceOf(beneficiary);
        assertEq(
            finalBalance - initialBalance,
            VESTING_AMOUNT,
            "Beneficiary should receive vested tokens"
        );
    }

    function test_NonBeneficiaryRelease() public {
        uint256 beneficiaryBeforeBalance = aSummerToken.balanceOf(beneficiary);
        aSummerToken.createVestingWallet(
            beneficiary,
            VESTING_AMOUNT,
            SummerVestingWallet.VestingType.SixMonthCliff
        );
        address vestingWalletAddress = aSummerToken.vestingWallets(beneficiary);
        SummerVestingWallet vestingWallet = SummerVestingWallet(
            payable(vestingWalletAddress)
        );

        vm.warp(block.timestamp + 181 days);
        vm.prank(nonGovernance);
        vestingWallet.release(address(aSummerToken));

        uint256 beneficiaryAfterBalance = aSummerToken.balanceOf(beneficiary);
        assertEq(
            beneficiaryAfterBalance - beneficiaryBeforeBalance,
            VESTING_AMOUNT,
            "Non-beneficiary should be able to release tokens to the owner"
        );
    }
}
