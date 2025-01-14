// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {RebalanceData} from "../../src/types/FleetCommanderTypes.sol";
import {TestHelpers} from "../helpers/TestHelpers.sol";

import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";

/**
 * @title Lifecycle test suite for FleetCommander
 * @dev Test suite of full lifecycle tests EG Deposit -> Rebalance -> WithdrawFromArks
 */
contract LifecycleTest is TestHelpers, FleetCommanderTestBase {
    function setUp() public {
        uint256 initialTipRate = 0;
        initializeFleetCommanderWithMockArks(initialTipRate);
    }

    function test_DepositRebalanceWithdrawFromArks() public {
        // Arrange
        uint256 user1Deposit = ARK1_MAX_ALLOCATION;
        uint256 user2Deposit = ARK2_MAX_ALLOCATION;
        uint256 depositCap = ARK1_MAX_ALLOCATION + ARK2_MAX_ALLOCATION;
        uint256 minBufferBalance = 0;

        // Set initial buffer balance and min buffer balance
        fleetCommanderStorageWriter.setminimumBufferBalance(minBufferBalance);

        // Set deposit cap
        fleetCommanderStorageWriter.setDepositCap(depositCap);

        // Mint tokens for users
        mockToken.mint(mockUser, user1Deposit);
        mockToken.mint(mockUser2, user2Deposit);

        // User 1 deposits
        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), user1Deposit);
        uint256 user1PreviewShares = fleetCommander.previewDeposit(
            user1Deposit
        );
        uint256 user1DepositedShares = fleetCommander.deposit(
            user1Deposit,
            mockUser
        );
        assertEq(
            user1PreviewShares,
            user1DepositedShares,
            "Preview and deposited shares should be equal"
        );
        assertEq(
            fleetCommander.balanceOf(mockUser),
            user1Deposit,
            "User 1 balance should be equal to deposit"
        );
        vm.stopPrank();

        // User 2 deposits
        vm.startPrank(mockUser2);
        mockToken.approve(address(fleetCommander), user2Deposit);
        uint256 user2PreviewShares = fleetCommander.previewDeposit(
            user2Deposit
        );
        uint256 user2DepositedShares = fleetCommander.deposit(
            user2Deposit,
            mockUser2
        );
        assertEq(
            user2PreviewShares,
            user2DepositedShares,
            "Preview and deposited shares should be equal"
        );
        assertEq(
            fleetCommander.balanceOf(mockUser2),
            user2Deposit,
            "User 2 balance should be equal to deposit"
        );
        vm.stopPrank();

        // Rebalance funds to Ark1 and Ark2
        RebalanceData[] memory rebalanceData = new RebalanceData[](2);
        rebalanceData[0] = RebalanceData({
            fromArk: bufferArkAddress,
            toArk: ark1,
            amount: user1Deposit,
            boardData: bytes(""),
            disembarkData: bytes("")
        });
        rebalanceData[1] = RebalanceData({
            fromArk: bufferArkAddress,
            toArk: ark2,
            amount: user2Deposit,
            boardData: bytes(""),
            disembarkData: bytes("")
        });

        // Advance time to move past cooldown window
        vm.warp(block.timestamp + 1 days);
        vm.prank(keeper);
        fleetCommander.rebalance(rebalanceData);

        // Advance time and update Ark1 and Ark2 balances to simulate interest accrual
        vm.warp(block.timestamp + 1 days);

        mockToken.mint(ark1, (user1Deposit * 5) / 100);
        mockToken.mint(ark2, (user2Deposit * 10) / 100);

        // User 1 withdraws
        vm.startPrank(mockUser);
        uint256 user1Shares = fleetCommander.balanceOf(mockUser);
        uint256 user1Assets = fleetCommander.previewRedeem(user1Shares);
        fleetCommander.withdrawFromArks(user1Assets, mockUser, mockUser);

        assertEq(
            fleetCommander.balanceOf(mockUser),
            0,
            "User 1 balance should be 0"
        );
        assertEq(
            mockToken.balanceOf(mockUser),
            user1Assets,
            "User 1 should receive assets"
        );
        vm.stopPrank();

        // User 2 withdraws
        vm.startPrank(mockUser2);
        uint256 user2Shares = fleetCommander.balanceOf(mockUser2);
        uint256 user2Assets = fleetCommander.previewRedeem(user2Shares);
        fleetCommander.withdrawFromArks(user2Assets, mockUser2, mockUser2);

        assertEq(
            fleetCommander.balanceOf(mockUser2),
            0,
            "User 2 balance should be 0"
        );
        assertEq(
            mockToken.balanceOf(mockUser2),
            user2Assets,
            "User 2 should receive assets"
        );
        vm.stopPrank();

        // Assert
        // TODO: One wei off due to rounding error
        assertEq(
            fleetCommander.totalAssets(),
            1,
            "Total assets should be 0 after withdrawals"
        );
    }
}
