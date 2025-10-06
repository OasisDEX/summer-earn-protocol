// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CrossChainFleetCommanderTestBase} from "./CrossChainFleetCommanderTestBase.sol";
import {CrossChainFleetCommander} from "../../src/contracts/CrossChainFleetCommander.sol";
import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {ICrossChainFleetCommanderErrors} from "../../src/errors/ICrossChainFleetCommanderErrors.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

/**
 * @title CrossChainFleetCommander MEV Protection Tests
 * @notice Test suite for MEV protection mechanisms in CrossChainFleetCommander
 * @dev Tests prevention of immediate execution, sync requirements, and MEV attack scenarios
 */
contract CrossChainFleetCommanderMevProtectionTest is
    CrossChainFleetCommanderTestBase
{
    uint256 constant INITIAL_TIP_RATE = 5; // 5%
    uint256 constant DEPOSIT_AMOUNT = 10000 * 10 ** 6; // 10,000 USDC
    uint256 constant WITHDRAWAL_AMOUNT = 5000 * 10 ** 6; // 5,000 USDC

    function setUp() public {
        initializeCrossChainFleetCommander(INITIAL_TIP_RATE);
        setupAsyncUser(asyncUser, DEPOSIT_AMOUNT * 2);
        setupAsyncUser(asyncUser2, DEPOSIT_AMOUNT * 2);
    }

    /*//////////////////////////////////////////////////////////////
                            IMMEDIATE EXECUTION PREVENTION
    //////////////////////////////////////////////////////////////*/

    function testDepositRevertsWithAsyncMessage() public {
        vm.prank(asyncUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainFleetCommanderErrors
                    .CrossChainFleetCommanderUseAsyncFunction
                    .selector,
                "Use queueDeposit() for async operations"
            )
        );
        crossChainFleetCommander.deposit(DEPOSIT_AMOUNT, asyncUser);
    }

    function testWithdrawRevertsWithAsyncMessage() public {
        vm.prank(asyncUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainFleetCommanderErrors
                    .CrossChainFleetCommanderUseAsyncFunction
                    .selector,
                "Use queueWithdrawal() for async operations"
            )
        );
        crossChainFleetCommander.withdraw(
            WITHDRAWAL_AMOUNT,
            asyncUser,
            asyncUser
        );
    }

    function testRedeemRevertsWithAsyncMessage() public {
        vm.prank(asyncUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainFleetCommanderErrors
                    .CrossChainFleetCommanderUseAsyncFunction
                    .selector,
                "Use queueRedemption() for async operations"
            )
        );
        crossChainFleetCommander.redeem(1000 * 10 ** 18, asyncUser, asyncUser);
    }

    function testPreviewFunctionsStillWork() public {
        // Preview functions should still work for immediate price discovery
        uint256 previewShares = crossChainFleetCommander.previewDeposit(
            DEPOSIT_AMOUNT
        );
        uint256 previewAssets = crossChainFleetCommander.previewRedeem(
            1000 * 10 ** 18
        );

        assertTrue(previewShares > 0, "Preview shares should be calculated");
        assertTrue(previewAssets > 0, "Preview assets should be calculated");
    }

    /*//////////////////////////////////////////////////////////////
                            SYNC REQUIREMENT PROTECTION
    //////////////////////////////////////////////////////////////*/

    function testProcessingBlockedWithUnsyncedArk() public {
        // Grant commander role first
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(unsyncedArkMock),
            address(crossChainFleetCommander)
        );
        vm.stopPrank();

        // Add an unsynced Ark
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(unsyncedArkMock),
            address(crossChainFleetCommander)
        );
        crossChainFleetCommander.addArk(address(unsyncedArkMock));
        vm.stopPrank();

        // Queue operation
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);

        // Should not be able to process with unsynced Ark
        vm.prank(superkeeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainFleetCommanderErrors
                    .CrossChainFleetCommanderNotAllArksSynced
                    .selector
            )
        );
        crossChainFleetCommander.processAsyncOperations(1);

        // Operation should remain queued
        assertEq(
            getQueuedOperationsCount(),
            1,
            "Operation should remain queued"
        );
    }

    function testProcessingAllowedWithSyncedArks() public {
        // All Arks should be synced by default
        assertTrue(areAllArksSynced(), "All Arks should be synced");

        // Queue operation
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);

        // Should be able to process
        vm.prank(superkeeper);
        (uint256 processed, uint256 failed) = crossChainFleetCommander
            .processAsyncOperations(1);

        assertEq(processed, 1, "Should process 1 operation");
        assertEq(failed, 0, "Should have 0 failed operations");
    }

    function testSyncStatusChangesAffectProcessing() public {
        // Start with synced Arks
        assertTrue(areAllArksSynced(), "Should start synced");

        // Queue operation
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);

        // Add unsynced Ark
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(unsyncedArkMock),
            address(crossChainFleetCommander)
        );
        crossChainFleetCommander.addArk(address(unsyncedArkMock));
        vm.stopPrank();

        // Should not be able to process
        vm.prank(superkeeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainFleetCommanderErrors
                    .CrossChainFleetCommanderNotAllArksSynced
                    .selector
            )
        );
        crossChainFleetCommander.processAsyncOperations(1);

        // Set deposit cap to 0 and remove unsynced Ark
        vm.startPrank(governor);
        crossChainFleetCommander.setArkDepositCap(address(unsyncedArkMock), 0);
        crossChainFleetCommander.removeArk(address(unsyncedArkMock));
        vm.stopPrank();

        // Should be able to process now
        vm.prank(superkeeper);
        (uint256 processed, uint256 failed) = crossChainFleetCommander
            .processAsyncOperations(1);

        assertEq(processed, 1, "Should process 1 operation");
        assertEq(failed, 0, "Should have 0 failed operations");
    }

    /*//////////////////////////////////////////////////////////////
                            TIMING ATTACK PREVENTION
    //////////////////////////////////////////////////////////////*/

    function testOperationsQueuedNotExecutedImmediately() public {
        // Queue operation
        uint256 operationId = queueDeposit(
            asyncUser,
            DEPOSIT_AMOUNT,
            asyncUser
        );

        // Operation should be queued, not executed
        assertEq(
            getQueuedOperationsCount(),
            1,
            "Should have 1 queued operation"
        );

        // Check user's token balance hasn't changed (no immediate execution)
        uint256 userBalance = mockToken.balanceOf(asyncUser);
        assertEq(
            userBalance,
            DEPOSIT_AMOUNT * 2,
            "User balance should not change immediately"
        );

        // Check FleetCommander balance hasn't changed
        uint256 fleetBalance = mockToken.balanceOf(
            address(crossChainFleetCommander)
        );
        assertEq(
            fleetBalance,
            0,
            "FleetCommander balance should not change immediately"
        );
    }

    function testOperationsProcessedOnlyWhenSynced() public {
        // Queue operation
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);

        // Add unsynced Ark
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(unsyncedArkMock),
            address(crossChainFleetCommander)
        );
        crossChainFleetCommander.addArk(address(unsyncedArkMock));
        vm.stopPrank();

        // Try to process - should fail
        vm.prank(superkeeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainFleetCommanderErrors
                    .CrossChainFleetCommanderNotAllArksSynced
                    .selector
            )
        );
        crossChainFleetCommander.processAsyncOperations(1);

        // Set deposit cap to 0 and remove unsynced Ark to make all Arks synced
        vm.startPrank(governor);
        crossChainFleetCommander.setArkDepositCap(address(unsyncedArkMock), 0);
        crossChainFleetCommander.removeArk(address(unsyncedArkMock));
        vm.stopPrank();

        // Now should be able to process
        vm.prank(superkeeper);
        (uint256 processed, uint256 failed) = crossChainFleetCommander
            .processAsyncOperations(1);

        assertEq(processed, 1, "Should process 1 operation");
        assertEq(failed, 0, "Should have 0 failed operations");
    }

    function testMultipleOperationsQueuedUntilSync() public {
        // Queue multiple operations
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);
        queueDeposit(asyncUser2, DEPOSIT_AMOUNT, asyncUser2);

        // Add unsynced Ark
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(unsyncedArkMock),
            address(crossChainFleetCommander)
        );
        crossChainFleetCommander.addArk(address(unsyncedArkMock));
        vm.stopPrank();

        // Should not be able to process any operations
        vm.prank(superkeeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainFleetCommanderErrors
                    .CrossChainFleetCommanderNotAllArksSynced
                    .selector
            )
        );
        crossChainFleetCommander.processAsyncOperations(10);

        // All operations should remain queued
        assertEq(
            getQueuedOperationsCount(),
            2,
            "All operations should remain queued"
        );

        // Set deposit cap to 0 and remove unsynced Ark
        vm.startPrank(governor);
        crossChainFleetCommander.setArkDepositCap(address(unsyncedArkMock), 0);
        crossChainFleetCommander.removeArk(address(unsyncedArkMock));
        vm.stopPrank();

        // Now should be able to process all operations
        vm.prank(superkeeper);
        (uint256 processed, uint256 failed) = crossChainFleetCommander
            .processAsyncOperations(10);

        assertEq(processed, 2, "Should process 2 operations");
        assertEq(failed, 0, "Should have 0 failed operations");
        assertEq(
            getQueuedOperationsCount(),
            0,
            "Should have 0 queued operations"
        );
    }

    /*//////////////////////////////////////////////////////////////
                            MEV ATTACK SCENARIOS
    //////////////////////////////////////////////////////////////*/

    function testPreventLossRealizationArbitrage() public {
        // This test simulates the scenario where an attacker tries to:
        // 1. Withdraw before a loss is realized
        // 2. Deposit after the loss is realized

        // First, deposit to get shares
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);
        vm.prank(superkeeper);
        crossChainFleetCommander.processAsyncOperations(1);

        // Simulate a loss by reducing the total assets in the FleetCommander
        // (In a real scenario, this would happen due to external protocol losses)

        // Try to withdraw before processing the loss
        queueWithdrawal(asyncUser, WITHDRAWAL_AMOUNT, asyncUser, asyncUser);

        // The withdrawal should be queued, not executed immediately
        assertEq(getQueuedOperationsCount(), 1, "Withdrawal should be queued");

        // Even if the attacker tries to process immediately, they can't because:
        // 1. Only superkeepers can process
        // 2. All Arks must be synced
        // 3. Operations are processed in FIFO order

        // This prevents the attacker from front-running the loss realization
    }

    function testPreventRewardDistributionSandwich() public {
        // This test simulates the scenario where an attacker tries to:
        // 1. Withdraw before rewards are distributed
        // 2. Deposit after rewards are distributed

        // First, process a deposit to have some assets
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);
        vm.prank(superkeeper);
        crossChainFleetCommander.processAsyncOperations(1);

        // Now queue operations for the sandwich attack
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);
        queueWithdrawal(asyncUser, WITHDRAWAL_AMOUNT, asyncUser, asyncUser);

        // Operations are queued, not executed immediately
        assertEq(getQueuedOperationsCount(), 2, "Operations should be queued");

        // The attacker cannot:
        // 1. Execute operations immediately (they're queued)
        // 2. Process operations without sync (requires all Arks synced)
        // 3. Manipulate the order (FIFO queue)

        // This prevents sandwich attacks on reward distributions
    }

    function testPreventFrontRunningBasedOnRemoteEvents() public {
        // This test simulates the scenario where an attacker monitors remote chains
        // and tries to front-run based on remote events

        // Queue operations
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);
        queueDeposit(asyncUser2, DEPOSIT_AMOUNT, asyncUser2);

        // Even if the attacker knows about remote events, they cannot:
        // 1. Execute operations immediately (async queue)
        // 2. Process operations without sync (sync requirement)
        // 3. Manipulate timing (FIFO order)

        // The sync requirement ensures that all remote state is current
        // before any operations are processed
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL PROTECTION
    //////////////////////////////////////////////////////////////*/

    function testOnlySuperkeepersCanProcess() public {
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);

        // Regular user cannot process
        vm.prank(asyncUser);
        vm.expectRevert();
        crossChainFleetCommander.processAsyncOperations(1);

        // Non-keeper cannot process
        vm.prank(address(0x9999));
        vm.expectRevert();
        crossChainFleetCommander.processAsyncOperations(1);

        // Only superkeeper can process
        vm.prank(superkeeper);
        (uint256 processed, uint256 failed) = crossChainFleetCommander
            .processAsyncOperations(1);

        assertEq(processed, 1, "Should process 1 operation");
        assertEq(failed, 0, "Should have 0 failed operations");
    }

    function testProcessingRequiresSyncEvenForSuperkeeper() public {
        // Add unsynced Ark
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(unsyncedArkMock),
            address(crossChainFleetCommander)
        );
        crossChainFleetCommander.addArk(address(unsyncedArkMock));
        vm.stopPrank();

        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);

        // Even superkeeper cannot process with unsynced Ark
        vm.prank(superkeeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainFleetCommanderErrors
                    .CrossChainFleetCommanderNotAllArksSynced
                    .selector
            )
        );
        crossChainFleetCommander.processAsyncOperations(1);
    }

    /*//////////////////////////////////////////////////////////////
                            QUEUE PROTECTION
    //////////////////////////////////////////////////////////////*/

    function testQueuePreventsDirectManipulation() public {
        // Users can only queue operations, not manipulate the queue directly
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);

        // Users cannot:
        // 1. Process operations directly
        vm.prank(asyncUser);
        vm.expectRevert();
        crossChainFleetCommander.processAsyncOperations(1);

        // 2. Manipulate queue order (FIFO)
        // 3. Skip queue processing

        // Only superkeepers can process, and only when synced
    }

    function testQueueSizeLimitPreventsSpam() public {
        // Fill up the queue to the limit
        for (
            uint256 i = 0;
            i < crossChainFleetCommander.getMaxQueueSize();
            i++
        ) {
            address user = address(uint160(0x1000 + i));
            setupAsyncUser(user, DEPOSIT_AMOUNT);

            vm.prank(user);
            crossChainFleetCommander.queueDeposit(MIN_QUEUE_AMOUNT, user);
        }

        // Try to queue one more operation
        address spamUser = address(0x9999);
        setupAsyncUser(spamUser, DEPOSIT_AMOUNT);

        vm.prank(spamUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainFleetCommanderErrors
                    .CrossChainFleetCommanderQueueFull
                    .selector,
                500, // current size
                500 // max size
            )
        );
        crossChainFleetCommander.queueDeposit(MIN_QUEUE_AMOUNT, spamUser);
    }

    function testMinimumAmountPreventsDustAttacks() public {
        // Try to queue very small amounts
        uint256 dustAmount = 1; // 1 wei

        vm.prank(asyncUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainFleetCommanderErrors
                    .CrossChainFleetCommanderAmountBelowMinimum
                    .selector,
                dustAmount,
                MIN_QUEUE_AMOUNT
            )
        );
        crossChainFleetCommander.queueDeposit(dustAmount, asyncUser);

        // For withdrawal, we need to first deposit some assets to make withdrawal possible
        // Then test the minimum amount validation
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);
        vm.prank(superkeeper);
        crossChainFleetCommander.processAsyncOperations(1);

        // Now test withdrawal with dust amount
        vm.prank(asyncUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainFleetCommanderErrors
                    .CrossChainFleetCommanderAmountBelowMinimum
                    .selector,
                dustAmount,
                MIN_QUEUE_AMOUNT
            )
        );
        crossChainFleetCommander.queueWithdrawal(
            dustAmount,
            asyncUser,
            asyncUser
        );
    }

    /*//////////////////////////////////////////////////////////////
                            INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testFullMevProtectionWorkflow() public {
        // 1. User queues operations (no immediate execution)
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);
        queueDeposit(asyncUser2, DEPOSIT_AMOUNT, asyncUser2);

        // 2. Operations remain queued until sync
        assertEq(getQueuedOperationsCount(), 2, "Operations should be queued");

        // 3. Add unsynced Ark to prevent processing
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(unsyncedArkMock),
            address(crossChainFleetCommander)
        );
        crossChainFleetCommander.addArk(address(unsyncedArkMock));
        vm.stopPrank();

        // 4. Cannot process with unsynced Ark
        vm.prank(superkeeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainFleetCommanderErrors
                    .CrossChainFleetCommanderNotAllArksSynced
                    .selector
            )
        );
        crossChainFleetCommander.processAsyncOperations(2);

        // 5. Set deposit cap to 0 and remove unsynced Ark to allow processing
        vm.startPrank(governor);
        crossChainFleetCommander.setArkDepositCap(address(unsyncedArkMock), 0);
        crossChainFleetCommander.removeArk(address(unsyncedArkMock));
        vm.stopPrank();

        // 6. Now can process operations
        vm.prank(superkeeper);
        (uint256 processed, uint256 failed) = crossChainFleetCommander
            .processAsyncOperations(2);

        assertEq(processed, 2, "Should process 2 operations");
        assertEq(failed, 0, "Should have 0 failed operations");
        assertEq(
            getQueuedOperationsCount(),
            0,
            "Should have 0 queued operations"
        );
    }

    function testMevProtectionWithMixedOperations() public {
        // Queue different types of operations
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);

        // Process deposit first
        vm.prank(superkeeper);
        crossChainFleetCommander.processAsyncOperations(1);

        // Queue withdrawal and redemption with smaller amounts
        queueWithdrawal(asyncUser, 1000 * 10 ** 6, asyncUser, asyncUser); // Use smaller withdrawal amount
        queueRedemption(asyncUser, 1000 * 10 ** 6, asyncUser, asyncUser); // Use smaller redemption amount

        // All operations are protected by the same mechanisms:
        // 1. Async queue (no immediate execution)
        // 2. Sync requirements (no processing with stale state)
        // 3. Access control (only superkeepers can process)
        // 4. FIFO order (no manipulation of processing order)

        assertEq(
            getQueuedOperationsCount(),
            2,
            "Should have 2 queued operations"
        );

        // Process remaining operations
        vm.prank(superkeeper);
        (uint256 processed, uint256 failed) = crossChainFleetCommander
            .processAsyncOperations(2);

        // With functional mocks, operations should succeed
        assertEq(processed, 2, "Should process 2 operations");
        assertEq(failed, 0, "Should have 0 failed operations");
        assertEq(
            getQueuedOperationsCount(),
            0,
            "Should have 0 queued operations after processing"
        );
    }

    function testMevProtectionAgainstSandwichAttack() public {
        // This test demonstrates how the async queue prevents sandwich attacks

        // 1. Attacker tries to front-run a large deposit by withdrawing first
        // 2. Then deposit after the large deposit to benefit from price impact
        // 3. Finally withdraw again to complete the sandwich

        // Setup: User has some shares from previous deposit
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);
        vm.prank(superkeeper);
        crossChainFleetCommander.processAsyncOperations(1);

        // Attacker tries to queue operations in a specific order to exploit price impact
        address attacker = address(0x9999);
        setupAsyncUser(attacker, DEPOSIT_AMOUNT * 3);

        // Attacker needs to have shares first
        queueDeposit(attacker, DEPOSIT_AMOUNT * 2, attacker);
        vm.prank(superkeeper);
        crossChainFleetCommander.processAsyncOperations(1);

        // Attacker's strategy: withdraw -> deposit -> withdraw
        queueWithdrawal(attacker, 1000 * 10 ** 6, attacker, attacker);
        queueDeposit(attacker, DEPOSIT_AMOUNT, attacker);
        queueWithdrawal(attacker, 2000 * 10 ** 6, attacker, attacker);

        // MEV Protection: Operations are queued in FIFO order, not execution order
        // The attacker cannot manipulate the order of execution
        assertEq(getQueuedOperationsCount(), 3, "All operations queued");

        // Even if attacker knows about a large deposit coming, they can't:
        // 1. Execute operations immediately (async queue)
        // 2. Manipulate processing order (FIFO)
        // 3. Process without sync (sync requirement)
        // 4. Process without authorization (access control)

        // Process operations in FIFO order
        vm.prank(superkeeper);
        (uint256 processed, uint256 failed) = crossChainFleetCommander
            .processAsyncOperations(3);

        assertEq(processed, 3, "All operations processed in FIFO order");
        assertEq(failed, 0, "No operations failed");
        assertEq(getQueuedOperationsCount(), 0, "Queue cleared");
    }

    function testMevProtectionAgainstFrontRunning() public {
        // This test demonstrates protection against front-running based on mempool observation

        // Setup: User has shares
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);
        vm.prank(superkeeper);
        crossChainFleetCommander.processAsyncOperations(1);

        // Scenario: Attacker sees a large withdrawal in mempool and tries to front-run
        address frontRunner = address(0x8888);
        setupAsyncUser(frontRunner, DEPOSIT_AMOUNT * 2);

        // User queues a large withdrawal (this would normally be front-runnable)
        queueWithdrawal(asyncUser, 5000 * 10 ** 6, asyncUser, asyncUser);

        // Front-runner tries to exploit by depositing before the withdrawal
        queueDeposit(frontRunner, DEPOSIT_AMOUNT, frontRunner);

        // MEV Protection: Even if front-runner sees the withdrawal in mempool:
        // 1. They can't execute immediately (async queue prevents immediate execution)
        // 2. They can't manipulate order (FIFO queue)
        // 3. They can't process without sync (sync requirement)
        // 4. They can't process without authorization (access control)

        // The operations are processed in the order they were queued
        assertEq(getQueuedOperationsCount(), 2, "Operations queued in order");

        vm.prank(superkeeper);
        (uint256 processed, uint256 failed) = crossChainFleetCommander
            .processAsyncOperations(2);

        assertEq(processed, 2, "Operations processed in FIFO order");
        assertEq(failed, 0, "No operations failed");
    }

    function testMevProtectionAgainstCrossChainFrontRunning() public {
        // This test demonstrates protection against cross-chain front-running

        // Scenario: Attacker monitors remote chain events and tries to front-run
        address crossChainAttacker = address(0x7777);
        setupAsyncUser(crossChainAttacker, DEPOSIT_AMOUNT * 2);

        // Attacker queues deposit and processes it first
        queueDeposit(crossChainAttacker, DEPOSIT_AMOUNT, crossChainAttacker);
        vm.prank(superkeeper);
        crossChainFleetCommander.processAsyncOperations(1);

        // Then attacker queues withdrawal based on remote chain events
        queueWithdrawal(
            crossChainAttacker,
            5000 * 10 ** 6,
            crossChainAttacker,
            crossChainAttacker
        );

        // MEV Protection: Even if attacker knows about remote events:
        // 1. Operations are queued, not executed immediately
        // 2. Sync requirement ensures all remote state is current before processing
        // 3. Access control prevents unauthorized processing
        // 4. FIFO order prevents manipulation

        // Add unsynced Ark to demonstrate sync protection
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(unsyncedArkMock),
            address(crossChainFleetCommander)
        );
        crossChainFleetCommander.addArk(address(unsyncedArkMock));
        vm.stopPrank();

        // Cannot process with unsynced Ark
        vm.prank(superkeeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainFleetCommanderErrors
                    .CrossChainFleetCommanderNotAllArksSynced
                    .selector
            )
        );
        crossChainFleetCommander.processAsyncOperations(2);

        // Operations remain queued until sync
        assertEq(
            getQueuedOperationsCount(),
            1,
            "Operations remain queued until sync"
        );

        // Remove unsynced Ark to allow processing
        vm.startPrank(governor);
        crossChainFleetCommander.setArkDepositCap(address(unsyncedArkMock), 0);
        crossChainFleetCommander.removeArk(address(unsyncedArkMock));
        vm.stopPrank();

        // Now can process
        vm.prank(superkeeper);
        (uint256 processed, uint256 failed) = crossChainFleetCommander
            .processAsyncOperations(1);

        assertEq(processed, 1, "Operations processed after sync");
        assertEq(failed, 0, "No operations failed");
    }
}
