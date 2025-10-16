// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {TestHelpers} from "../helpers/TestHelpers.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";
import {FleetCommanderParams} from "../../src/types/FleetCommanderTypes.sol";
import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {IWithdrawalFee} from "../../src/utils/WithdrawalFee/IWithdrawalFee.sol";
import {IArk} from "../../src/interfaces/IArk.sol";
import {Constants} from "@summerfi/constants/Constants.sol";

/**
 * @title Withdrawal Fee test suite for FleetCommander
 * @dev Test suite for the FleetCommander contract's withdrawal fee functionality
 *
 * Test coverage:
 * - Withdrawal fee calculation and application
 * - Fee collection on all withdrawal methods
 * - Fee goes to buffer (increases buffer balance)
 * - Governance can update fee
 * - Fee caps are enforced
 * - Zero fee disables mechanism
 * - Fee edge cases (dust amounts, max withdrawals)
 */
contract FleetCommanderWithdrawalFeeTest is
    TestHelpers,
    FleetCommanderTestBase
{
    uint256 constant DEPOSIT_AMOUNT = 1000 * 10 ** 6; // 1000 USDC (6 decimals)
    uint256 constant MAX_DEPOSIT_CAP = 100000 * 10 ** 6; // 100,000 USDC (6 decimals)

    // Default withdrawal fee: 0.025% = 0.00025 * WAD
    uint256 constant DEFAULT_WITHDRAWAL_FEE = 25000000000000000; // 0.025%
    uint256 constant HIGH_WITHDRAWAL_FEE = (1 * Constants.WAD) / 100; // 1%
    uint256 constant MAX_WITHDRAWAL_FEE = 10 * Constants.WAD; // 10%

    FleetCommander public feeFleet;

    function setUp() public {
        uint256 initialTipRate = 0;

        // Initialize base contracts using the base class method
        initializeFleetCommanderWithMockArks(initialTipRate);

        // Create a new FleetCommander with withdrawal fee enabled for testing
        FleetCommanderParams memory feeParams = fleetCommanderParams;
        feeParams.name = "FeeFleet";
        feeParams.symbol = "FEE-FLEET";
        feeParams.initialWithdrawalFee = Percentage.wrap(
            DEFAULT_WITHDRAWAL_FEE
        );

        vm.prank(governor);
        feeFleet = new FleetCommander(feeParams);
    }

    function test_WithdrawalFeeCalculation() public {
        uint256 amount = DEPOSIT_AMOUNT;
        uint256 expectedFee = (amount * DEFAULT_WITHDRAWAL_FEE) /
            (100 * Constants.WAD);

        _mockArkTotalAssets(ark1, 0);
        _mockArkTotalAssets(ark2, 0);

        mockToken.mint(mockUser, amount * 10);

        vm.startPrank(mockUser);
        mockToken.approve(address(feeFleet), amount);
        feeFleet.deposit(amount, mockUser);
        vm.stopPrank();

        // Check fee calculation
        uint256 calculatedFee = feeFleet._calculateWithdrawalFee(amount);
        assertEq(
            calculatedFee,
            expectedFee,
            "Fee calculation should be correct"
        );
    }

    function test_WithdrawFromBufferAppliesFee() public {
        uint256 amount = DEPOSIT_AMOUNT;
        uint256 expectedFee = (amount * DEFAULT_WITHDRAWAL_FEE) /
            (100 * Constants.WAD);
        uint256 expectedAssetsAfterFee = amount - expectedFee;

        _mockArkTotalAssets(ark1, 0);
        _mockArkTotalAssets(ark2, 0);

        mockToken.mint(mockUser, amount * 10);

        vm.startPrank(mockUser);
        mockToken.approve(address(feeFleet), amount);
        feeFleet.deposit(amount, mockUser);
        vm.stopPrank();

        uint256 initialBufferBalance = IArk(feeFleet.bufferArk()).totalAssets();
        uint256 initialUserBalance = mockToken.balanceOf(mockUser);

        // Withdraw from buffer
        vm.startPrank(mockUser);
        feeFleet.withdrawFromBuffer(amount, mockUser, mockUser);
        vm.stopPrank();

        // Check that user received less than requested (due to fee)
        uint256 finalUserBalance = mockToken.balanceOf(mockUser);
        uint256 actualReceived = finalUserBalance - initialUserBalance;
        assertEq(
            actualReceived,
            expectedAssetsAfterFee,
            "User should receive assets minus fee"
        );

        // Check that buffer balance decreased by less than requested (fee stayed in buffer)
        uint256 finalBufferBalance = IArk(feeFleet.bufferArk()).totalAssets();
        uint256 bufferDecrease = initialBufferBalance - finalBufferBalance;
        assertEq(
            bufferDecrease,
            expectedAssetsAfterFee,
            "Buffer should decrease by assets minus fee"
        );
    }

    function test_RedeemFromBufferAppliesFee() public {
        uint256 amount = DEPOSIT_AMOUNT;
        uint256 expectedFee = (amount * DEFAULT_WITHDRAWAL_FEE) /
            (100 * Constants.WAD);
        uint256 expectedAssetsAfterFee = amount - expectedFee;

        _mockArkTotalAssets(ark1, 0);
        _mockArkTotalAssets(ark2, 0);

        mockToken.mint(mockUser, amount * 10);

        vm.startPrank(mockUser);
        mockToken.approve(address(feeFleet), amount);
        uint256 shares = feeFleet.deposit(amount, mockUser);
        vm.stopPrank();

        uint256 initialBufferBalance = IArk(feeFleet.bufferArk()).totalAssets();
        uint256 initialUserBalance = mockToken.balanceOf(mockUser);

        // Redeem from buffer
        vm.startPrank(mockUser);
        feeFleet.redeemFromBuffer(shares, mockUser, mockUser);
        vm.stopPrank();

        // Check that user received less than requested (due to fee)
        uint256 finalUserBalance = mockToken.balanceOf(mockUser);
        uint256 actualReceived = finalUserBalance - initialUserBalance;
        assertEq(
            actualReceived,
            expectedAssetsAfterFee,
            "User should receive assets minus fee"
        );

        // Check that buffer balance decreased by less than requested (fee stayed in buffer)
        uint256 finalBufferBalance = IArk(feeFleet.bufferArk()).totalAssets();
        uint256 bufferDecrease = initialBufferBalance - finalBufferBalance;
        assertEq(
            bufferDecrease,
            expectedAssetsAfterFee,
            "Buffer should decrease by assets minus fee"
        );
    }

    function test_WithdrawFromArksAppliesFee() public {
        uint256 amount = DEPOSIT_AMOUNT;
        uint256 expectedFee = (amount * DEFAULT_WITHDRAWAL_FEE) /
            (100 * Constants.WAD);
        uint256 expectedAssetsAfterFee = amount - expectedFee;

        // Set up arks with assets
        _mockArkTotalAssets(ark1, amount);
        _mockArkTotalAssets(ark2, 0);

        mockToken.mint(mockUser, amount * 10);

        vm.startPrank(mockUser);
        mockToken.approve(address(feeFleet), amount);
        feeFleet.deposit(amount, mockUser);
        vm.stopPrank();

        uint256 initialUserBalance = mockToken.balanceOf(mockUser);

        // Withdraw from arks
        vm.startPrank(mockUser);
        feeFleet.withdrawFromArks(amount, mockUser, mockUser);
        vm.stopPrank();

        // Check that user received less than requested (due to fee)
        uint256 finalUserBalance = mockToken.balanceOf(mockUser);
        uint256 actualReceived = finalUserBalance - initialUserBalance;
        assertEq(
            actualReceived,
            expectedAssetsAfterFee,
            "User should receive assets minus fee"
        );

        // Check that fee was re-deposited to buffer
        uint256 finalBufferBalance = IArk(feeFleet.bufferArk()).totalAssets();
        assertEq(
            finalBufferBalance,
            expectedFee,
            "Buffer should contain exactly the fee amount after withdrawal"
        );
    }

    function test_RedeemFromArksAppliesFee() public {
        uint256 amount = DEPOSIT_AMOUNT;
        uint256 expectedFee = (amount * DEFAULT_WITHDRAWAL_FEE) /
            (100 * Constants.WAD);
        uint256 expectedAssetsAfterFee = amount - expectedFee;

        // Set up arks with assets
        _mockArkTotalAssets(ark1, amount);
        _mockArkTotalAssets(ark2, 0);

        mockToken.mint(mockUser, amount * 10);

        vm.startPrank(mockUser);
        mockToken.approve(address(feeFleet), amount);
        uint256 shares = feeFleet.deposit(amount, mockUser);
        vm.stopPrank();

        uint256 initialUserBalance = mockToken.balanceOf(mockUser);

        // Redeem from arks
        vm.startPrank(mockUser);
        feeFleet.redeemFromArks(shares, mockUser, mockUser);
        vm.stopPrank();

        // Check that user received less than requested (due to fee)
        uint256 finalUserBalance = mockToken.balanceOf(mockUser);
        uint256 actualReceived = finalUserBalance - initialUserBalance;
        assertEq(
            actualReceived,
            expectedAssetsAfterFee,
            "User should receive assets minus fee"
        );

        // Check that fee was re-deposited to buffer
        uint256 finalBufferBalance = IArk(feeFleet.bufferArk()).totalAssets();
        assertEq(
            finalBufferBalance,
            expectedFee,
            "Buffer should contain exactly the fee amount after redemption"
        );
    }

    function test_GovernanceCanUpdateWithdrawalFee() public {
        uint256 newFee = HIGH_WITHDRAWAL_FEE; // 1%

        // Update fee as governor
        vm.prank(governor);
        feeFleet.updateWithdrawalFee(Percentage.wrap(newFee));

        // Check that fee was updated
        assertEq(
            Percentage.unwrap(feeFleet.getWithdrawalFee()),
            newFee,
            "Withdrawal fee should be updated"
        );
    }

    function test_NonGovernorCannotUpdateWithdrawalFee() public {
        uint256 newFee = HIGH_WITHDRAWAL_FEE; // 1%

        // Try to update fee as non-governor
        vm.prank(mockUser);
        vm.expectRevert();
        feeFleet.updateWithdrawalFee(Percentage.wrap(newFee));
    }

    function test_WithdrawalFeeTooHighReverts() public {
        uint256 tooHighFee = MAX_WITHDRAWAL_FEE + 1; // > 10%

        // Try to set fee too high
        vm.prank(governor);
        vm.expectRevert();
        feeFleet.updateWithdrawalFee(Percentage.wrap(tooHighFee));
    }

    function test_ZeroWithdrawalFeeDisablesMechanism() public {
        uint256 amount = DEPOSIT_AMOUNT;

        // Set fee to zero
        vm.prank(governor);
        feeFleet.updateWithdrawalFee(Percentage.wrap(0));

        _mockArkTotalAssets(ark1, 0);
        _mockArkTotalAssets(ark2, 0);

        mockToken.mint(mockUser, amount * 10);

        vm.startPrank(mockUser);
        mockToken.approve(address(feeFleet), amount);
        feeFleet.deposit(amount, mockUser);
        vm.stopPrank();

        uint256 initialUserBalance = mockToken.balanceOf(mockUser);

        // Withdraw from buffer - should receive full amount
        vm.startPrank(mockUser);
        feeFleet.withdrawFromBuffer(amount, mockUser, mockUser);
        vm.stopPrank();

        // Check that user received full amount (no fee)
        uint256 finalUserBalance = mockToken.balanceOf(mockUser);
        uint256 actualReceived = finalUserBalance - initialUserBalance;
        assertEq(
            actualReceived,
            amount,
            "User should receive full amount when fee is zero"
        );
    }

    function test_WithdrawalFeeEventEmitted() public {
        uint256 amount = DEPOSIT_AMOUNT;
        uint256 expectedFee = (amount * DEFAULT_WITHDRAWAL_FEE) /
            (100 * Constants.WAD);

        _mockArkTotalAssets(ark1, 0);
        _mockArkTotalAssets(ark2, 0);

        mockToken.mint(mockUser, amount * 10);

        vm.startPrank(mockUser);
        mockToken.approve(address(feeFleet), amount);
        feeFleet.deposit(amount, mockUser);
        vm.stopPrank();

        // Expect withdrawal fee event
        vm.expectEmit(true, false, false, true);
        emit IWithdrawalFee.WithdrawalFeeCollected(
            mockUser,
            amount,
            expectedFee
        );

        // Withdraw from buffer
        vm.startPrank(mockUser);
        feeFleet.withdrawFromBuffer(amount, mockUser, mockUser);
        vm.stopPrank();
    }

    function test_WithdrawalFeeUpdateEventEmitted() public {
        uint256 newFee = HIGH_WITHDRAWAL_FEE; // 1%

        // Expect withdrawal fee update event
        vm.expectEmit(false, false, false, true);
        emit IWithdrawalFee.WithdrawalFeeUpdated(
            Percentage.wrap(DEFAULT_WITHDRAWAL_FEE),
            Percentage.wrap(newFee)
        );

        // Update fee as governor
        vm.prank(governor);
        feeFleet.updateWithdrawalFee(Percentage.wrap(newFee));
    }

    function test_DustAmountWithdrawalFee() public {
        uint256 dustAmount = 1; // Very small amount
        uint256 expectedFee = (dustAmount * DEFAULT_WITHDRAWAL_FEE) /
            (100 * Constants.WAD);

        _mockArkTotalAssets(ark1, 0);
        _mockArkTotalAssets(ark2, 0);

        mockToken.mint(mockUser, dustAmount * 10);

        vm.startPrank(mockUser);
        mockToken.approve(address(feeFleet), dustAmount);
        feeFleet.deposit(dustAmount, mockUser);
        vm.stopPrank();

        // For dust amounts, fee might be 0 due to rounding
        uint256 calculatedFee = feeFleet._calculateWithdrawalFee(dustAmount);

        // Withdraw from buffer
        vm.startPrank(mockUser);
        feeFleet.withdrawFromBuffer(dustAmount, mockUser, mockUser);
        vm.stopPrank();

        // Should not revert even with dust amounts
        assertTrue(true, "Dust amount withdrawal should not revert");
    }

    function test_MaxWithdrawalWithFee() public {
        uint256 amount = DEPOSIT_AMOUNT;
        uint256 expectedFee = (amount * DEFAULT_WITHDRAWAL_FEE) /
            (100 * Constants.WAD);
        uint256 expectedAssetsAfterFee = amount - expectedFee;

        _mockArkTotalAssets(ark1, 0);
        _mockArkTotalAssets(ark2, 0);

        mockToken.mint(mockUser, amount * 10);

        vm.startPrank(mockUser);
        mockToken.approve(address(feeFleet), amount);
        feeFleet.deposit(amount, mockUser);
        vm.stopPrank();

        uint256 initialUserBalance = mockToken.balanceOf(mockUser);

        // Withdraw max amount
        vm.startPrank(mockUser);
        feeFleet.withdraw(type(uint256).max, mockUser, mockUser);
        vm.stopPrank();

        // Check that user received less than their full balance (due to fee)
        uint256 finalUserBalance = mockToken.balanceOf(mockUser);
        uint256 actualReceived = finalUserBalance - initialUserBalance;
        assertLt(
            actualReceived,
            amount,
            "User should receive less than full amount due to fee"
        );
    }

    function test_WithdrawWithFeesCorrect() public {
        uint256 amount = DEPOSIT_AMOUNT;
        uint256 expectedFee = (amount * DEFAULT_WITHDRAWAL_FEE) /
            (100 * Constants.WAD);
        uint256 expectedAssetsAfterFee = amount - expectedFee;

        _mockArkTotalAssets(ark1, 0);
        _mockArkTotalAssets(ark2, 0);

        mockToken.mint(mockUser, amount * 10);

        vm.startPrank(mockUser);
        mockToken.approve(address(feeFleet), amount);
        uint256 shares = feeFleet.deposit(amount, mockUser);
        vm.stopPrank();

        // Test main withdraw() function (automatically routes to buffer or arks)
        uint256 initialUserBalance = mockToken.balanceOf(mockUser);
        vm.startPrank(mockUser);
        feeFleet.withdraw(amount, mockUser, mockUser);
        vm.stopPrank();
        uint256 autoWithdrawReceived = mockToken.balanceOf(mockUser) -
            initialUserBalance;

        assertEq(
            autoWithdrawReceived,
            expectedAssetsAfterFee,
            "Withdraw should apply correct fee"
        );
    }

    function test_RedeemWithFeesCorrect() public {
        uint256 amount = DEPOSIT_AMOUNT;
        uint256 expectedFee = (amount * DEFAULT_WITHDRAWAL_FEE) /
            (100 * Constants.WAD);
        uint256 expectedAssetsAfterFee = amount - expectedFee;

        _mockArkTotalAssets(ark1, 0);
        _mockArkTotalAssets(ark2, 0);

        mockToken.mint(mockUser, amount * 10);

        vm.startPrank(mockUser);
        mockToken.approve(address(feeFleet), amount);
        uint256 shares = feeFleet.deposit(amount, mockUser);
        vm.stopPrank();

        // Test main redeem() function (automatically routes to buffer or arks)
        uint256 initialUserBalance = mockToken.balanceOf(mockUser);
        vm.startPrank(mockUser);
        feeFleet.redeem(shares, mockUser, mockUser);
        vm.stopPrank();
        uint256 autoRedeemReceived = mockToken.balanceOf(mockUser) -
            initialUserBalance;

        assertEq(
            autoRedeemReceived,
            expectedAssetsAfterFee,
            "Redeem should apply correct fee"
        );
    }
}
