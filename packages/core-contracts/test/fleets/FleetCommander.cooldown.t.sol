// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {TestHelpers} from "../helpers/TestHelpers.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";
import {FleetCommanderParams} from "../../src/types/FleetCommanderTypes.sol";
import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

/**
| * @title Cooldown test suite for FleetCommander
| * @dev Test suite for the FleetCommander contract's cooldown functionality
| *
| * Test coverage:
| * - Deposit cooldown enforcement
| * - Cooldown timestamp propagation on transfers
| * - Cooldown period configuration
| * - Error cases and edge scenarios
| */
contract FleetCommanderCooldownTest is TestHelpers, FleetCommanderTestBase {
    uint256 constant DEPOSIT_AMOUNT = 1000 * 10 ** 6;
    uint256 constant MAX_DEPOSIT_CAP = 100000 * 10 ** 6;

    FleetCommander public cooldownFleet;

    function setUp() public {
        uint256 initialTipRate = 0;

        // Initialize base contracts using the base class method
        initializeFleetCommanderWithMockArks(initialTipRate);

        // Create a new FleetCommander with cooldown enabled for testing
        // Use the same params but with userCooldownPeriod = 1
        FleetCommanderParams memory cooldownParams = fleetCommanderParams;
        cooldownParams.name = "CooldownFleet";
        cooldownParams.symbol = "COOL-FLEET";
        cooldownParams.userCooldownPeriod = 1; // 1 second cooldown

        vm.prank(governor);
        cooldownFleet = new FleetCommander(cooldownParams);
    }

    function test_DepositSetsCooldownTimestamp() public {
        uint256 amount = DEPOSIT_AMOUNT;

        _mockArkTotalAssets(ark1, 0);
        _mockArkTotalAssets(ark2, 0);

        mockToken.mint(mockUser, amount * 10);

        vm.startPrank(mockUser);
        mockToken.approve(address(cooldownFleet), amount);
        cooldownFleet.deposit(amount, mockUser);
        vm.stopPrank();

        // Verify cooldown timestamp was set
        assertEq(
            cooldownFleet.lastDepositTimestamp(mockUser),
            block.timestamp,
            "Cooldown timestamp should be set to current block timestamp"
        );
    }

    function test_WithdrawRevertsWithinCooldownPeriod() public {
        uint256 amount = DEPOSIT_AMOUNT;

        _mockArkTotalAssets(ark1, 0);
        _mockArkTotalAssets(ark2, 0);

        mockToken.mint(mockUser, amount * 10);

        vm.startPrank(mockUser);
        mockToken.approve(address(cooldownFleet), amount);
        cooldownFleet.deposit(amount, mockUser);

        // Try to withdraw immediately - should revert
        vm.expectRevert();
        cooldownFleet.withdraw(amount, mockUser, mockUser);
        vm.stopPrank();
    }

    function test_WithdrawSucceedsAfterCooldownPeriod() public {
        uint256 amount = DEPOSIT_AMOUNT;

        _mockArkTotalAssets(ark1, 0);
        _mockArkTotalAssets(ark2, 0);

        mockToken.mint(mockUser, amount * 10);

        vm.startPrank(mockUser);
        mockToken.approve(address(cooldownFleet), amount);
        cooldownFleet.deposit(amount, mockUser);

        // Wait for cooldown period to pass (1 second)
        vm.warp(block.timestamp + 2);

        // Should succeed now
        vm.startPrank(mockUser);
        cooldownFleet.withdraw(amount, mockUser, mockUser);
        vm.stopPrank();
    }

    function test_RedeemRevertsWithinCooldownPeriod() public {
        uint256 amount = DEPOSIT_AMOUNT;

        _mockArkTotalAssets(ark1, 0);
        _mockArkTotalAssets(ark2, 0);

        mockToken.mint(mockUser, amount * 10);

        vm.startPrank(mockUser);
        mockToken.approve(address(cooldownFleet), amount);
        uint256 shares = cooldownFleet.deposit(amount, mockUser);

        // Try to redeem immediately - should revert
        vm.expectRevert();
        cooldownFleet.redeem(shares, mockUser, mockUser);
        vm.stopPrank();
    }

    function test_RedeemSucceedsAfterCooldownPeriod() public {
        uint256 amount = DEPOSIT_AMOUNT;

        _mockArkTotalAssets(ark1, 0);
        _mockArkTotalAssets(ark2, 0);

        mockToken.mint(mockUser, amount * 10);

        vm.startPrank(mockUser);
        mockToken.approve(address(cooldownFleet), amount);
        uint256 shares = cooldownFleet.deposit(amount, mockUser);

        // Wait for cooldown period to pass
        vm.warp(block.timestamp + 2);

        vm.startPrank(mockUser);
        cooldownFleet.redeem(shares, mockUser, mockUser);
        vm.stopPrank();
    }

    function test_CooldownPropagationOnTransfer() public {
        uint256 amount = DEPOSIT_AMOUNT;

        _mockArkTotalAssets(ark1, 0);
        _mockArkTotalAssets(ark2, 0);

        mockToken.mint(mockUser, amount * 10);

        vm.startPrank(mockUser);
        mockToken.approve(address(cooldownFleet), amount);
        uint256 shares = cooldownFleet.deposit(amount, mockUser);

        // Transfer shares to another user
        vm.startPrank(mockUser);
        cooldownFleet.transfer(mockUser2, shares);
        vm.stopPrank();

        // Verify cooldown timestamp was propagated
        assertEq(
            cooldownFleet.lastDepositTimestamp(mockUser2),
            block.timestamp,
            "Cooldown timestamp should be propagated to recipient"
        );

        // Transfer back - cooldown should remain
        vm.startPrank(mockUser2);
        cooldownFleet.transfer(mockUser, shares);
        vm.stopPrank();

        // Cooldown should still be the original timestamp
        assertEq(
            cooldownFleet.lastDepositTimestamp(mockUser2),
            block.timestamp,
            "Cooldown timestamp should remain"
        );
    }

    function test_NoCooldownWhenPeriodIsZero() public {
        uint256 amount = DEPOSIT_AMOUNT;

        _mockArkTotalAssets(ark1, 0);
        _mockArkTotalAssets(ark2, 0);

        // Use the base fleetCommander which has userCooldownPeriod: 0
        mockToken.mint(mockUser, amount * 10);

        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), amount);
        fleetCommander.deposit(amount, mockUser);

        // Should be able to withdraw immediately
        fleetCommander.withdraw(amount, mockUser, mockUser);
        vm.stopPrank();
    }

    function test_WithdrawFromBufferRevertsWithinCooldownPeriod() public {
        uint256 amount = DEPOSIT_AMOUNT;

        _mockArkTotalAssets(ark1, 0);
        _mockArkTotalAssets(ark2, 0);

        mockToken.mint(mockUser, amount * 10);

        vm.startPrank(mockUser);
        mockToken.approve(address(cooldownFleet), amount);
        cooldownFleet.deposit(amount, mockUser);

        // Try to withdraw from buffer immediately - should revert
        vm.expectRevert();
        cooldownFleet.withdrawFromBuffer(amount, mockUser, mockUser);
        vm.stopPrank();
    }

    function test_WithdrawFromArksRevertsWithinCooldownPeriod() public {
        uint256 amount = DEPOSIT_AMOUNT;

        _mockArkTotalAssets(ark1, 0);
        _mockArkTotalAssets(ark2, 0);

        mockToken.mint(mockUser, amount * 10);

        vm.startPrank(mockUser);
        mockToken.approve(address(cooldownFleet), amount);
        cooldownFleet.deposit(amount, mockUser);

        // Try to withdraw from arks immediately - should revert
        vm.expectRevert();
        cooldownFleet.withdrawFromArks(amount, mockUser, mockUser);
        vm.stopPrank();
    }
}
