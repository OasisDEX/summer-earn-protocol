// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {ArkTestHelpers} from "../helpers/ArkHelpers.sol";
import {RebalanceData} from "../../src/types/FleetCommanderTypes.sol";

import {FleetCommanderStorageWriter} from "../helpers/FleetCommanderStorageWriter.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

/**
 * @title Lifecycle test suite for FleetCommander
 * @dev Test suite of full lifecycle tests EG Deposit -> Rebalance -> ForceWithdraw
 */
contract LifecycleTest is Test, ArkTestHelpers, FleetCommanderTestBase {
    address public mockUser2 = address(5);

    function setUp() public {
        // Each fleet uses a default setup from the FleetCommanderTestBase contract,
        // but you can create and initialize your own custom fleet if you wish.
        fleetCommander = FleetCommander(Clones.clone(address(fleetCommanderImp)));
        fleetCommander.initialize(fleetCommanderParams);
        fleetCommanderStorageWriter = new FleetCommanderStorageWriter(
            address(fleetCommander)
        );

        vm.startPrank(governor);
        accessManager.grantKeeperRole(keeper);
        mockArk1.grantCommanderRole(address(fleetCommander));
        mockArk2.grantCommanderRole(address(fleetCommander));
        mockArk3.grantCommanderRole(address(fleetCommander));
        vm.stopPrank();
    }

    function test_DepositRebalanceForceWithdraw() public {
        // Arrange
        uint256 user1Deposit = ark1_MAX_ALLOCATION;
        uint256 user2Deposit = ark2_MAX_ALLOCATION;
        uint256 depositCap = ark1_MAX_ALLOCATION + ark2_MAX_ALLOCATION;
        uint256 minBufferBalance = 1000 * 10 ** 6;

        // Set initial buffer balance and min buffer balance
        fleetCommanderStorageWriter.setMinFundsBufferBalance(minBufferBalance);

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
            fromArk: address(fleetCommander),
            toArk: ark1,
            amount: user1Deposit
        });
        rebalanceData[1] = RebalanceData({
            fromArk: address(fleetCommander),
            toArk: ark2,
            amount: user2Deposit
        });

        vm.prank(keeper);
        fleetCommander.adjustBuffer(rebalanceData);

        // Advance time and update Ark1 and Ark2 balances to simulate interest accrual
        vm.warp(block.timestamp + 1 days);

        mockToken.mint(ark1, (user1Deposit * 5) / 100);
        mockToken.mint(ark2, (user2Deposit * 10) / 100);

        // User 1 withdraws
        vm.startPrank(mockUser);
        uint256 user1Shares = fleetCommander.balanceOf(mockUser);
        uint256 user1Assets = fleetCommander.previewRedeem(user1Shares);
        fleetCommander.forceWithdraw(user1Assets, mockUser, mockUser);

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
        fleetCommander.forceWithdraw(user2Assets, mockUser2, mockUser2);

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
