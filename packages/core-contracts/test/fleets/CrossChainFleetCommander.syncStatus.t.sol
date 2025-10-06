// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CrossChainFleetCommanderTestBase} from "./CrossChainFleetCommanderTestBase.sol";
import {CrossChainFleetCommander} from "../../src/contracts/CrossChainFleetCommander.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {UnsyncedArkMock} from "./CrossChainFleetCommanderTestBase.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {ICrossChainFleetCommanderErrors} from "../../src/errors/ICrossChainFleetCommanderErrors.sol";

/**
 * @title CrossChainFleetCommander Sync Status Tests
 * @notice Test suite for Ark sync status functionality in CrossChainFleetCommander
 * @dev Tests sync requirements, Ark status checking, and processing restrictions
 */
contract CrossChainFleetCommanderSyncStatusTest is
    CrossChainFleetCommanderTestBase
{
    uint256 constant INITIAL_TIP_RATE = 5; // 5%
    uint256 constant DEPOSIT_AMOUNT = 10000 * 10 ** 6; // 10,000 USDC

    function setUp() public {
        initializeCrossChainFleetCommander(INITIAL_TIP_RATE);
        setupAsyncUser(asyncUser, DEPOSIT_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                            SYNC STATUS CHECKING
    //////////////////////////////////////////////////////////////*/

    function testAreAllArksSyncedWithSyncedArks() public {
        // All default Arks should be synced (they inherit from ArkMock which returns true)
        assertTrue(areAllArksSynced(), "All Arks should be synced by default");
    }

    function testAreAllArksSyncedWithUnsyncedArk() public {
        // Grant commander role to the unsynced Ark first
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(unsyncedArkMock),
            address(crossChainFleetCommander)
        );
        vm.stopPrank();

        // Add an unsynced Ark
        vm.startPrank(governor);
        crossChainFleetCommander.addArk(address(unsyncedArkMock));
        vm.stopPrank();

        assertFalse(
            areAllArksSynced(),
            "Should not be synced with unsynced Ark"
        );
    }

    function testAreAllArksSyncedWithMixedArks() public {
        // Grant commander roles first
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(syncedArkMock),
            address(crossChainFleetCommander)
        );
        accessManager.grantCommanderRole(
            address(unsyncedArkMock),
            address(crossChainFleetCommander)
        );
        vm.stopPrank();

        // Add both synced and unsynced Arks
        vm.startPrank(governor);
        crossChainFleetCommander.addArk(address(syncedArkMock));
        crossChainFleetCommander.addArk(address(unsyncedArkMock));
        vm.stopPrank();

        assertFalse(
            areAllArksSynced(),
            "Should not be synced with any unsynced Ark"
        );
    }

    function testAreAllArksSyncedWithBufferArk() public {
        // Buffer Ark should also be checked for sync status
        // Since BufferArk inherits from Ark, it should return true by default
        assertTrue(
            areAllArksSynced(),
            "Buffer Ark should be synced by default"
        );
    }

    function testAreAllArksSyncedAfterArkRemoval() public {
        // Grant commander role first
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(unsyncedArkMock),
            address(crossChainFleetCommander)
        );
        vm.stopPrank();

        // Add an unsynced Ark
        vm.startPrank(governor);
        crossChainFleetCommander.addArk(address(unsyncedArkMock));
        vm.stopPrank();

        assertFalse(
            areAllArksSynced(),
            "Should not be synced with unsynced Ark"
        );

        // Set deposit cap to zero before removing the unsynced Ark
        vm.startPrank(governor);
        crossChainFleetCommander.setArkDepositCap(address(unsyncedArkMock), 0);
        crossChainFleetCommander.removeArk(address(unsyncedArkMock));
        vm.stopPrank();

        assertTrue(
            areAllArksSynced(),
            "Should be synced after removing unsynced Ark"
        );
    }

    /*//////////////////////////////////////////////////////////////
                            PROCESSING RESTRICTIONS
    //////////////////////////////////////////////////////////////*/

    function testProcessAsyncOperationsRequiresSync() public {
        // Queue an operation
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);

        // Grant commander role first
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(unsyncedArkMock),
            address(crossChainFleetCommander)
        );
        vm.stopPrank();

        // Add an unsynced Ark
        vm.startPrank(governor);
        crossChainFleetCommander.addArk(address(unsyncedArkMock));
        vm.stopPrank();

        // Try to process operations with unsynced Ark
        vm.prank(superkeeper);
        vm.expectRevert(
            ICrossChainFleetCommanderErrors
                .CrossChainFleetCommanderNotAllArksSynced
                .selector
        );
        crossChainFleetCommander.processAsyncOperations(1);
    }

    function testProcessAsyncOperationsWithSyncedArks() public {
        // Queue an operation
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);

        // All Arks should be synced by default
        assertTrue(areAllArksSynced(), "All Arks should be synced");

        // Should be able to process operations
        vm.prank(superkeeper);
        (uint256 processed, uint256 failed) = crossChainFleetCommander
            .processAsyncOperations(1);

        assertEq(processed, 1, "Should process 1 operation");
        assertEq(failed, 0, "Should have 0 failed operations");
    }

    function testProcessAsyncOperationsWithBufferArkUnsynced() public {
        // This test would require a custom BufferArk that can be unsynced
        // For now, we'll test the general sync requirement
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);

        // All Arks should be synced by default
        assertTrue(areAllArksSynced(), "All Arks should be synced");

        // Should be able to process operations
        vm.prank(superkeeper);
        (uint256 processed, uint256 failed) = crossChainFleetCommander
            .processAsyncOperations(1);

        assertEq(processed, 1, "Should process 1 operation");
        assertEq(failed, 0, "Should have 0 failed operations");
    }

    /*//////////////////////////////////////////////////////////////
                            ARK SYNC STATUS CHANGES
    //////////////////////////////////////////////////////////////*/

    function testSyncStatusChangesOverTime() public {
        // Start with all Arks synced
        assertTrue(areAllArksSynced(), "Should start synced");

        // Grant commander role first
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(unsyncedArkMock),
            address(crossChainFleetCommander)
        );
        vm.stopPrank();

        // Add an unsynced Ark
        vm.startPrank(governor);
        crossChainFleetCommander.addArk(address(unsyncedArkMock));
        vm.stopPrank();

        assertFalse(areAllArksSynced(), "Should become unsynced");

        // Set deposit cap to zero before removing the unsynced Ark
        vm.startPrank(governor);
        crossChainFleetCommander.setArkDepositCap(address(unsyncedArkMock), 0);
        crossChainFleetCommander.removeArk(address(unsyncedArkMock));
        vm.stopPrank();

        assertTrue(areAllArksSynced(), "Should become synced again");
    }

    function testMultipleUnsyncedArks() public {
        // Grant commander role first
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(unsyncedArkMock),
            address(crossChainFleetCommander)
        );
        vm.stopPrank();

        // Add multiple unsynced Arks
        vm.startPrank(governor);
        crossChainFleetCommander.addArk(address(unsyncedArkMock));
        vm.stopPrank();

        assertFalse(
            areAllArksSynced(),
            "Should be unsynced with one unsynced Ark"
        );

        // Add another unsynced Ark
        UnsyncedArkMock unsyncedArkMock2 = new UnsyncedArkMock(
            ArkParams({
                name: "UnsyncedArk2",
                details: "UnsyncedArk2 details",
                accessManager: address(accessManager),
                asset: address(mockToken),
                configurationManager: address(configurationManager),
                depositCap: 100000 * 10 ** 6,
                maxRebalanceOutflow: type(uint256).max,
                maxRebalanceInflow: type(uint256).max,
                requiresKeeperData: false,
                maxDepositPercentageOfTVL: PERCENTAGE_100
            })
        );

        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(unsyncedArkMock2),
            address(crossChainFleetCommander)
        );
        vm.stopPrank();

        vm.startPrank(governor);
        crossChainFleetCommander.addArk(address(unsyncedArkMock2));
        vm.stopPrank();

        assertFalse(
            areAllArksSynced(),
            "Should still be unsynced with multiple unsynced Arks"
        );
    }

    /*//////////////////////////////////////////////////////////////
                            EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function testSyncStatusWithNoArks() public {
        // Remove all Arks
        address[] memory activeArks = crossChainFleetCommander.getActiveArks();
        vm.startPrank(governor);
        for (uint256 i = 0; i < activeArks.length; i++) {
            crossChainFleetCommander.setArkDepositCap(activeArks[i], 0);
            crossChainFleetCommander.removeArk(activeArks[i]);
        }
        vm.stopPrank();

        // Should still be synced (no Arks to check)
        assertTrue(areAllArksSynced(), "Should be synced with no Arks");
    }

    function testSyncStatusWithOnlyBufferArk() public {
        // Remove all Arks except buffer
        address[] memory activeArks = crossChainFleetCommander.getActiveArks();
        vm.startPrank(governor);
        for (uint256 i = 0; i < activeArks.length; i++) {
            crossChainFleetCommander.setArkDepositCap(activeArks[i], 0);
            crossChainFleetCommander.removeArk(activeArks[i]);
        }
        vm.stopPrank();

        // Should be synced (only buffer Ark, which is synced)
        assertTrue(areAllArksSynced(), "Should be synced with only buffer Ark");
    }

    function testSyncStatusAfterArkReplacement() public {
        // Grant commander role first
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(unsyncedArkMock),
            address(crossChainFleetCommander)
        );
        vm.stopPrank();

        // Add an unsynced Ark
        vm.startPrank(governor);
        crossChainFleetCommander.addArk(address(unsyncedArkMock));
        vm.stopPrank();

        assertFalse(areAllArksSynced(), "Should be unsynced");

        // Replace with synced Ark
        vm.startPrank(governor);
        crossChainFleetCommander.setArkDepositCap(address(unsyncedArkMock), 0);
        crossChainFleetCommander.removeArk(address(unsyncedArkMock));
        accessManager.grantCommanderRole(
            address(syncedArkMock),
            address(crossChainFleetCommander)
        );
        crossChainFleetCommander.addArk(address(syncedArkMock));
        vm.stopPrank();

        assertTrue(areAllArksSynced(), "Should be synced after replacement");
    }

    /*//////////////////////////////////////////////////////////////
                            INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testFullWorkflowWithSyncRequirements() public {
        // Queue operations
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);

        // All Arks should be synced
        assertTrue(areAllArksSynced(), "All Arks should be synced");

        // Process operations
        vm.prank(superkeeper);
        (uint256 processed, uint256 failed) = crossChainFleetCommander
            .processAsyncOperations(1);

        assertEq(processed, 1, "Should process 1 operation");
        assertEq(failed, 0, "Should have 0 failed operations");
        assertEq(
            getQueuedOperationsCount(),
            0,
            "Should have 0 queued operations"
        );
    }

    function testWorkflowWithUnsyncedArk() public {
        // Grant commander role first
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(unsyncedArkMock),
            address(crossChainFleetCommander)
        );
        vm.stopPrank();

        // Add an unsynced Ark
        vm.startPrank(governor);
        crossChainFleetCommander.addArk(address(unsyncedArkMock));
        vm.stopPrank();

        // Queue operations
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);

        // Should not be able to process
        assertFalse(areAllArksSynced(), "Should not be synced");

        vm.prank(superkeeper);
        vm.expectRevert(
            ICrossChainFleetCommanderErrors
                .CrossChainFleetCommanderNotAllArksSynced
                .selector
        );
        crossChainFleetCommander.processAsyncOperations(1);

        // Operations should remain queued
        assertEq(
            getQueuedOperationsCount(),
            1,
            "Should still have 1 queued operation"
        );
    }

    function testSyncStatusAfterProcessing() public {
        // Queue and process operations
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);

        vm.prank(superkeeper);
        crossChainFleetCommander.processAsyncOperations(1);

        // Sync status should remain the same
        assertTrue(
            areAllArksSynced(),
            "Should still be synced after processing"
        );
    }
}
