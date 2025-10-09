// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CrossChainFleetCommanderTestBase} from "./CrossChainFleetCommanderTestBase.sol";
import {ICrossChainFleetCommanderErrors} from "../../src/errors/ICrossChainFleetCommanderErrors.sol";
import {RebalanceData} from "../../src/types/FleetCommanderTypes.sol";

/**
 * @title CrossChainFleetCommanderSyncTest
 * @notice Test suite for CrossChainFleetCommander sync functionality
 * @dev Tests the sync check functionality for cross-chain operations.
 *      - Deposits are blocked when arks are unsynced (for safety)
 *      - Withdrawals and redemptions are allowed even when arks are unsynced
 *        to ensure users can always access their funds.
 */
contract CrossChainFleetCommanderSyncTest is CrossChainFleetCommanderTestBase {
    uint256 public constant DEPOSIT_AMOUNT = 1000 * 10 ** 6;
    uint256 public constant WITHDRAW_AMOUNT = 500 * 10 ** 6;

    function setUp() public {
        initializeCrossChainFleetCommander(1); // 1% tip rate
        setupUser(user1, 10000 * 10 ** 6);
    }

    /*//////////////////////////////////////////////////////////////
                            BASIC SYNC TESTS
    //////////////////////////////////////////////////////////////*/

    function testAreAllArksSynced_DefaultState() public {
        // By default, all arks should be synced
        assertTrue(crossChainFleetCommander.areAllArksSynced());
    }

    function testGetUnsyncedArks_DefaultState() public {
        // By default, no arks should be unsynced
        address[] memory unsyncedArks = crossChainFleetCommander
            .getUnsyncedArks();
        assertEq(unsyncedArks.length, 0);
    }

    function testWithdraw_WithSyncedArks() public {
        // Perform a deposit first
        performDeposit(user1, DEPOSIT_AMOUNT, user1);

        // Fast forward past cooldown period
        vm.warp(block.timestamp + COOLDOWN_PERIOD + 1);

        // Withdrawal should succeed when all arks are synced
        uint256 shares = performWithdrawal(
            user1,
            WITHDRAW_AMOUNT,
            user1,
            user1
        );
        assertGt(shares, 0);
    }

    function testRedeem_WithSyncedArks() public {
        // Perform a deposit first
        performDeposit(user1, DEPOSIT_AMOUNT, user1);

        // Fast forward past cooldown period
        vm.warp(block.timestamp + COOLDOWN_PERIOD + 1);

        // Redemption should succeed when all arks are synced
        uint256 assets = performRedemption(user1, 250 * 10 ** 6, user1, user1);
        assertGt(assets, 0);
    }

    function testDeposit_WithSyncedArks() public {
        // Deposit should work regardless of sync status
        uint256 shares = performDeposit(user1, DEPOSIT_AMOUNT, user1);
        assertGt(shares, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            UNSYNCED ARK TESTS
    //////////////////////////////////////////////////////////////*/

    function testWithdraw_WithUnsyncedArks() public {
        // Perform a deposit first while arks are synced
        performDeposit(user1, DEPOSIT_AMOUNT, user1);

        // Fast forward past cooldown period
        vm.warp(block.timestamp + COOLDOWN_PERIOD + 1);

        // Now add an unsynced ark to the fleet
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(unsyncedArkMock),
            address(crossChainFleetCommander)
        );
        crossChainFleetCommander.addArk(address(unsyncedArkMock));
        vm.stopPrank();

        // Withdrawal should succeed even when arks are unsynced
        // (users should be able to withdraw their funds regardless of sync status)
        uint256 shares = performWithdrawal(
            user1,
            WITHDRAW_AMOUNT,
            user1,
            user1
        );
        assertGt(shares, 0);
    }

    function testRedeem_WithUnsyncedArks() public {
        // Perform a deposit first while arks are synced
        performDeposit(user1, DEPOSIT_AMOUNT, user1);

        // Fast forward past cooldown period
        vm.warp(block.timestamp + COOLDOWN_PERIOD + 1);

        // Now add an unsynced ark to the fleet
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(unsyncedArkMock),
            address(crossChainFleetCommander)
        );
        crossChainFleetCommander.addArk(address(unsyncedArkMock));
        vm.stopPrank();

        // Redemption should succeed even when arks are unsynced
        // (users should be able to redeem their shares regardless of sync status)
        uint256 assets = performRedemption(user1, 250 * 10 ** 6, user1, user1);
        assertGt(assets, 0);
    }

    function testDeposit_WithUnsyncedArks() public {
        // Add an unsynced ark to the fleet
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(unsyncedArkMock),
            address(crossChainFleetCommander)
        );
        crossChainFleetCommander.addArk(address(unsyncedArkMock));
        vm.stopPrank();

        // Deposit should fail when arks are unsynced
        // (users shouldn't deposit into unsynced arks for safety)
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainFleetCommanderErrors
                    .CrossChainFleetCommanderArksNotSynced
                    .selector
            )
        );
        performDeposit(user1, DEPOSIT_AMOUNT, user1);
    }

    function testAreAllArksSynced_WithUnsyncedArks() public {
        // Initially should be synced
        assertTrue(crossChainFleetCommander.areAllArksSynced());

        // Add an unsynced ark to the fleet
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(unsyncedArkMock),
            address(crossChainFleetCommander)
        );
        crossChainFleetCommander.addArk(address(unsyncedArkMock));
        vm.stopPrank();

        // Should now be unsynced
        assertFalse(crossChainFleetCommander.areAllArksSynced());
    }

    function testGetUnsyncedArks_WithUnsyncedArks() public {
        // Initially should be empty
        address[] memory unsyncedArks = crossChainFleetCommander
            .getUnsyncedArks();
        assertEq(unsyncedArks.length, 0);

        // Add an unsynced ark to the fleet
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(unsyncedArkMock),
            address(crossChainFleetCommander)
        );
        crossChainFleetCommander.addArk(address(unsyncedArkMock));
        vm.stopPrank();

        // Should return the unsynced ark
        unsyncedArks = crossChainFleetCommander.getUnsyncedArks();
        assertEq(unsyncedArks.length, 1);
        assertEq(unsyncedArks[0], address(unsyncedArkMock));
    }

    /*//////////////////////////////////////////////////////////////
                            REBALANCE SYNC TESTS
    //////////////////////////////////////////////////////////////*/

    // Note: rebalance and forceRebalance functions don't have sync checks
    // since they can't be easily overridden without modifying the parent class.
    // This is intentional as rebalancing operations may need to work even
    // when some arks are temporarily unsynced during maintenance.

    function testForceRebalance_WithSyncedArks() public {
        // Perform a deposit first to have assets to rebalance
        performDeposit(user1, DEPOSIT_AMOUNT, user1);

        // Create rebalance data
        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: crossChainFleetCommander.bufferArk(),
            toArk: ark1,
            amount: 100 * 10 ** 6,
            boardData: "",
            disembarkData: ""
        });

        // Force rebalance should succeed when all arks are synced
        vm.prank(governor);
        crossChainFleetCommander.forceRebalance(rebalanceData);
    }

    // Note: forceRebalance doesn't have sync check since it's not overridden
    // This is intentional as forceRebalance is a governance function that should
    // be able to operate even when arks are unsynced in emergency situations
}
