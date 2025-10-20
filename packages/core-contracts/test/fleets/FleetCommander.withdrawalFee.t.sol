// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {TestHelpers} from "../helpers/TestHelpers.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";
import {FleetCommanderParams} from "../../src/types/FleetCommanderTypes.sol";
import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {FleetCommanderWithdrawalFeeTestHarness} from "./FleetCommanderWithdrawalFeeTestHarness.sol";
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
 * - Fee shares go to tipJar (protocol treasury)
 * - Share price remains constant (no MEV opportunity)
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
    FleetCommanderWithdrawalFeeTestHarness public feeFleetHarness;

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

        // Create test harness for testing internal functions
        vm.prank(governor);
        feeFleetHarness = new FleetCommanderWithdrawalFeeTestHarness(feeParams);
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
        uint256 calculatedFee = feeFleetHarness.calculateWithdrawalFee(amount);
        assertEq(
            calculatedFee,
            expectedFee,
            "Fee calculation should be correct"
        );
    }

    function test_CalculateWithdrawalFeeShares() public {
        uint256 shares = 1000 * 10 ** 6;
        uint256 expectedFee = (shares * DEFAULT_WITHDRAWAL_FEE) /
            (100 * Constants.WAD);

        uint256 calculatedFee = feeFleetHarness.calculateWithdrawalFeeShares(
            shares
        );
        assertEq(
            calculatedFee,
            expectedFee,
            "Share-based fee calculation should be correct"
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
        uint256 initialTipJarShares = feeFleet.balanceOf(feeFleet.tipJar());

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

        // Check that buffer balance decreased by assets after fee
        uint256 finalBufferBalance = IArk(feeFleet.bufferArk()).totalAssets();
        uint256 bufferDecrease = initialBufferBalance - finalBufferBalance;
        assertEq(
            bufferDecrease,
            expectedAssetsAfterFee,
            "Buffer should decrease by assets minus fee"
        );

        // Check that tipJar received fee shares
        uint256 finalTipJarShares = feeFleet.balanceOf(feeFleet.tipJar());
        uint256 tipJarIncrease = finalTipJarShares - initialTipJarShares;
        assertGt(tipJarIncrease, 0, "TipJar should receive fee shares");
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
        uint256 initialTipJarShares = feeFleet.balanceOf(feeFleet.tipJar());

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

        // Check that buffer balance decreased by assets after fee
        uint256 finalBufferBalance = IArk(feeFleet.bufferArk()).totalAssets();
        uint256 bufferDecrease = initialBufferBalance - finalBufferBalance;
        assertEq(
            bufferDecrease,
            expectedAssetsAfterFee,
            "Buffer should decrease by assets minus fee"
        );

        // Check that tipJar received fee shares
        uint256 finalTipJarShares = feeFleet.balanceOf(feeFleet.tipJar());
        uint256 tipJarIncrease = finalTipJarShares - initialTipJarShares;
        assertGt(tipJarIncrease, 0, "TipJar should receive fee shares");
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
        uint256 initialTipJarShares = feeFleet.balanceOf(feeFleet.tipJar());

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

        // Check that tipJar received fee shares
        uint256 finalTipJarShares = feeFleet.balanceOf(feeFleet.tipJar());
        uint256 tipJarIncrease = finalTipJarShares - initialTipJarShares;
        assertGt(tipJarIncrease, 0, "TipJar should receive fee shares");
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
        uint256 initialTipJarShares = feeFleet.balanceOf(feeFleet.tipJar());

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

        // Check that tipJar received fee shares
        uint256 finalTipJarShares = feeFleet.balanceOf(feeFleet.tipJar());
        uint256 tipJarIncrease = finalTipJarShares - initialTipJarShares;
        assertGt(tipJarIncrease, 0, "TipJar should receive fee shares");
    }

    function test_NoMEVOpportunityWithWithdrawalFee() public {
        uint256 whaleAmount = 10000 * 10 ** 6; // 10,000 USDC
        uint256 attackerAmount = 1000 * 10 ** 6; // 1,000 USDC

        address whale = makeAddr("whale");
        address attacker = makeAddr("attacker");

        _mockArkTotalAssets(ark1, 0);
        _mockArkTotalAssets(ark2, 0);

        // Setup: Both users deposit
        mockToken.mint(whale, whaleAmount * 2);
        mockToken.mint(attacker, attackerAmount * 2);

        vm.startPrank(whale);
        mockToken.approve(address(feeFleet), whaleAmount);
        feeFleet.deposit(whaleAmount, whale);
        vm.stopPrank();

        vm.startPrank(attacker);
        mockToken.approve(address(feeFleet), attackerAmount);
        feeFleet.deposit(attackerAmount, attacker);
        vm.stopPrank();

        // Record share price before
        uint256 sharePriceBefore = feeFleet.convertToAssets(1e18);

        // Whale withdraws
        vm.startPrank(whale);
        feeFleet.withdrawFromBuffer(whaleAmount, whale, whale);
        vm.stopPrank();

        // Verify share price unchanged
        uint256 sharePriceAfter = feeFleet.convertToAssets(1e18);
        assertEq(
            sharePriceBefore,
            sharePriceAfter,
            "Share price should not change"
        );

        // Attacker tries to profit by withdrawing immediately
        uint256 attackerBalanceBefore = mockToken.balanceOf(attacker);
        vm.startPrank(attacker);
        feeFleet.withdrawFromBuffer(attackerAmount, attacker, attacker);
        vm.stopPrank();
        uint256 attackerBalanceAfter = mockToken.balanceOf(attacker);

        // Verify attacker didn't profit beyond normal fee
        uint256 attackerFee = (attackerAmount * DEFAULT_WITHDRAWAL_FEE) /
            (100 * Constants.WAD);
        uint256 expectedAttackerReceived = attackerAmount - attackerFee;
        uint256 actualAttackerReceived = attackerBalanceAfter -
            attackerBalanceBefore;
        assertEq(
            actualAttackerReceived,
            expectedAttackerReceived,
            "Attacker should not profit from whale's withdrawal"
        );
    }

    function test_TipJarReceivesFeesFromAllWithdrawalMethods() public {
        uint256 amount = DEPOSIT_AMOUNT;

        _mockArkTotalAssets(ark1, amount);
        _mockArkTotalAssets(ark2, 0);

        mockToken.mint(mockUser, amount * 10);

        vm.startPrank(mockUser);
        mockToken.approve(address(feeFleet), amount);
        uint256 shares = feeFleet.deposit(amount, mockUser);
        vm.stopPrank();

        uint256 initialTipJarShares = feeFleet.balanceOf(feeFleet.tipJar());
        uint256 cumulativeFees = 0;

        // Test withdrawFromBuffer
        vm.startPrank(mockUser);
        feeFleet.withdrawFromBuffer(amount / 4, mockUser, mockUser);
        vm.stopPrank();
        uint256 tipJarAfterBuffer = feeFleet.balanceOf(feeFleet.tipJar());
        uint256 bufferFee = tipJarAfterBuffer - initialTipJarShares;
        cumulativeFees += bufferFee;
        assertGt(
            bufferFee,
            0,
            "TipJar should receive fee from withdrawFromBuffer"
        );

        // Test redeemFromBuffer
        vm.startPrank(mockUser);
        feeFleet.redeemFromBuffer(shares / 4, mockUser, mockUser);
        vm.stopPrank();
        uint256 tipJarAfterRedeem = feeFleet.balanceOf(feeFleet.tipJar());
        uint256 redeemFee = tipJarAfterRedeem - tipJarAfterBuffer;
        cumulativeFees += redeemFee;
        assertGt(
            redeemFee,
            0,
            "TipJar should receive fee from redeemFromBuffer"
        );

        // Test withdrawFromArks
        vm.startPrank(mockUser);
        feeFleet.withdrawFromArks(amount / 4, mockUser, mockUser);
        vm.stopPrank();
        uint256 tipJarAfterArksWithdraw = feeFleet.balanceOf(feeFleet.tipJar());
        uint256 arksWithdrawFee = tipJarAfterArksWithdraw - tipJarAfterRedeem;
        cumulativeFees += arksWithdrawFee;
        assertGt(
            arksWithdrawFee,
            0,
            "TipJar should receive fee from withdrawFromArks"
        );

        // Test redeemFromArks
        vm.startPrank(mockUser);
        feeFleet.redeemFromArks(shares / 4, mockUser, mockUser);
        vm.stopPrank();
        uint256 tipJarAfterArksRedeem = feeFleet.balanceOf(feeFleet.tipJar());
        uint256 arksRedeemFee = tipJarAfterArksRedeem - tipJarAfterArksWithdraw;
        cumulativeFees += arksRedeemFee;
        assertGt(
            arksRedeemFee,
            0,
            "TipJar should receive fee from redeemFromArks"
        );

        // Verify cumulative fees are correct
        uint256 totalTipJarIncrease = tipJarAfterArksRedeem -
            initialTipJarShares;
        assertEq(
            totalTipJarIncrease,
            cumulativeFees,
            "Cumulative fees should match total tipJar increase"
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

        _mockArkTotalAssets(ark1, 0);
        _mockArkTotalAssets(ark2, 0);

        mockToken.mint(mockUser, dustAmount * 10);

        vm.startPrank(mockUser);
        mockToken.approve(address(feeFleet), dustAmount);
        feeFleet.deposit(dustAmount, mockUser);
        vm.stopPrank();

        // For dust amounts, fee might be 0 due to rounding
        feeFleetHarness.calculateWithdrawalFee(dustAmount);

        // Withdraw from buffer
        vm.startPrank(mockUser);
        feeFleet.withdrawFromBuffer(dustAmount, mockUser, mockUser);
        vm.stopPrank();

        // Should not revert even with dust amounts
        assertTrue(true, "Dust amount withdrawal should not revert");
    }

    function test_MaxWithdrawalWithFee() public {
        uint256 amount = DEPOSIT_AMOUNT;

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
        feeFleet.deposit(amount, mockUser);
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
