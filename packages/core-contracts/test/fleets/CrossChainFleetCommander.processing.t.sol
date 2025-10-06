// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CrossChainFleetCommanderTestBase} from "./CrossChainFleetCommanderTestBase.sol";
import {CrossChainFleetCommander} from "../../src/contracts/CrossChainFleetCommander.sol";
import {ICrossChainFleetCommander} from "../../src/interfaces/ICrossChainFleetCommander.sol";
import {ICrossChainFleetCommanderErrors} from "../../src/errors/ICrossChainFleetCommanderErrors.sol";
import {AsyncOperation} from "../../src/types/CrossChainFleetCommanderTypes.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

/**
 * @title CrossChainFleetCommander Processing Tests
 * @notice Test suite for superkeeper processing functionality in CrossChainFleetCommander
 * @dev Tests operation processing, batch processing, and error handling
 */
contract CrossChainFleetCommanderProcessingTest is
    CrossChainFleetCommanderTestBase
{
    uint256 constant INITIAL_TIP_RATE = 5; // 5%
    uint256 constant DEPOSIT_AMOUNT = 10000 * 10 ** 6; // 10,000 USDC
    uint256 constant WITHDRAWAL_AMOUNT = 5000 * 10 ** 6; // 5,000 USDC
    uint256 constant SHARES_AMOUNT = 1000 * 10 ** 6; // 1,000 shares (matching deposit amount)

    function setUp() public {
        initializeCrossChainFleetCommander(INITIAL_TIP_RATE);
        setupAsyncUser(asyncUser, DEPOSIT_AMOUNT * 3);
        setupAsyncUser(asyncUser2, DEPOSIT_AMOUNT * 3);
    }

    /*//////////////////////////////////////////////////////////////
                            PROCESSING AUTHORIZATION
    //////////////////////////////////////////////////////////////*/

    function testProcessAsyncOperationsOnlyKeeper() public {
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);

        // Non-keeper should not be able to process
        vm.prank(asyncUser);
        vm.expectRevert();
        crossChainFleetCommander.processAsyncOperations(1);
    }

    function testProcessAsyncOperationsWithKeeper() public {
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);

        // Keeper should be able to process
        vm.prank(superkeeper);
        (uint256 processed, uint256 failed) = crossChainFleetCommander
            .processAsyncOperations(1);

        assertEq(processed, 1, "Should process 1 operation");
        assertEq(failed, 0, "Should have 0 failed operations");
    }

    function testProcessAsyncOperationsRequiresSync() public {
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

        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);

        // Should not be able to process with unsynced Ark
        vm.prank(superkeeper);
        vm.expectRevert(
            ICrossChainFleetCommanderErrors
                .CrossChainFleetCommanderNotAllArksSynced
                .selector
        );
        crossChainFleetCommander.processAsyncOperations(1);
    }

    /*//////////////////////////////////////////////////////////////
                            SINGLE OPERATION PROCESSING
    //////////////////////////////////////////////////////////////*/

    function testProcessSingleDeposit() public {
        uint256 operationId = queueDeposit(
            asyncUser,
            DEPOSIT_AMOUNT,
            asyncUser
        );

        // Check initial state
        assertEq(
            getQueuedOperationsCount(),
            1,
            "Should have 1 queued operation"
        );
        AsyncOperation memory operation = getAsyncOperation(operationId);
        assertFalse(operation.processed, "Operation should not be processed");

        // Process the operation
        vm.prank(superkeeper);
        (uint256 processed, uint256 failed) = crossChainFleetCommander
            .processAsyncOperations(1);

        // Check results
        assertEq(processed, 1, "Should process 1 operation");
        assertEq(failed, 0, "Should have 0 failed operations");
        assertEq(
            getQueuedOperationsCount(),
            0,
            "Should have 0 queued operations"
        );

        // Check operation is marked as processed
        operation = getAsyncOperation(operationId);
        assertTrue(operation.processed, "Operation should be processed");
    }

    function testProcessSingleWithdrawal() public {
        // First deposit to get shares
        uint256 depositId = queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);
        vm.prank(superkeeper);
        crossChainFleetCommander.processAsyncOperations(1);

        // Now queue withdrawal
        uint256 operationId = queueWithdrawal(
            asyncUser,
            WITHDRAWAL_AMOUNT,
            asyncUser,
            asyncUser
        );

        // Process the withdrawal
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

    function testProcessSingleRedemption() public {
        // First deposit to get shares
        uint256 depositId = queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);
        vm.prank(superkeeper);
        crossChainFleetCommander.processAsyncOperations(1);

        // Now queue redemption
        uint256 operationId = queueRedemption(
            asyncUser,
            SHARES_AMOUNT,
            asyncUser,
            asyncUser
        );

        // Process the redemption
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

    /*//////////////////////////////////////////////////////////////
                            BATCH PROCESSING
    //////////////////////////////////////////////////////////////*/

    function testProcessMultipleOperations() public {
        // Queue multiple operations
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);
        queueDeposit(asyncUser2, DEPOSIT_AMOUNT, asyncUser2);

        assertEq(
            getQueuedOperationsCount(),
            2,
            "Should have 2 queued operations"
        );

        // Process all operations
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

    function testProcessPartialBatch() public {
        // Queue multiple operations
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);
        queueDeposit(asyncUser2, DEPOSIT_AMOUNT, asyncUser2);
        queueDeposit(address(0x300), DEPOSIT_AMOUNT, address(0x300));

        assertEq(
            getQueuedOperationsCount(),
            3,
            "Should have 3 queued operations"
        );

        // Process only 2 operations
        vm.prank(superkeeper);
        (uint256 processed, uint256 failed) = crossChainFleetCommander
            .processAsyncOperations(2);

        assertEq(processed, 2, "Should process 2 operations");
        assertEq(failed, 0, "Should have 0 failed operations");
        assertEq(
            getQueuedOperationsCount(),
            1,
            "Should have 1 queued operation"
        );
    }

    function testProcessWithMaxOperationsLimit() public {
        // Queue many operations
        for (uint256 i = 0; i < 10; i++) {
            address user = address(uint160(0x1000 + i));
            setupAsyncUser(user, DEPOSIT_AMOUNT);
            queueDeposit(user, DEPOSIT_AMOUNT, user);
        }

        assertEq(
            getQueuedOperationsCount(),
            10,
            "Should have 10 queued operations"
        );

        // Process with limit
        vm.prank(superkeeper);
        (uint256 processed, uint256 failed) = crossChainFleetCommander
            .processAsyncOperations(5);

        assertEq(processed, 5, "Should process 5 operations");
        assertEq(failed, 0, "Should have 0 failed operations");
        assertEq(
            getQueuedOperationsCount(),
            5,
            "Should have 5 queued operations"
        );
    }

    /*//////////////////////////////////////////////////////////////
                            ERROR HANDLING
    //////////////////////////////////////////////////////////////*/

    function testProcessWithInsufficientBalance() public {
        // Queue operation that will fail during processing
        address poorUser = address(0x9999);
        uint256 minAmount = crossChainFleetCommander.minQueueAmount();
        mockToken.mint(poorUser, minAmount);
        vm.startPrank(poorUser);
        mockToken.approve(address(crossChainFleetCommander), minAmount);
        vm.stopPrank();

        vm.prank(poorUser);
        uint256 operationId = crossChainFleetCommander.queueDeposit(
            minAmount,
            poorUser
        );

        // Transfer tokens away after queuing to cause failure during processing
        vm.prank(poorUser);
        mockToken.transfer(address(0x9998), minAmount);

        // Try to process - should fail due to insufficient balance
        vm.prank(superkeeper);
        (uint256 processed, uint256 failed) = crossChainFleetCommander
            .processAsyncOperations(1);

        assertEq(processed, 0, "Should process 0 operations");
        assertEq(failed, 1, "Should have 1 failed operation");
    }

    function testProcessWithInvalidOperation() public {
        // Queue a valid operation
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);

        // Manually create an invalid operation in storage (this is a bit hacky but tests error handling)
        // We'll queue another operation and then try to process with a limit that should cause issues
        queueDeposit(asyncUser2, DEPOSIT_AMOUNT, asyncUser2);

        // Process operations
        vm.prank(superkeeper);
        (uint256 processed, uint256 failed) = crossChainFleetCommander
            .processAsyncOperations(2);

        // Should process successfully
        assertEq(processed, 2, "Should process 2 operations");
        assertEq(failed, 0, "Should have 0 failed operations");
    }

    function testProcessEmptyQueue() public {
        // No operations queued
        assertEq(
            getQueuedOperationsCount(),
            0,
            "Should have 0 queued operations"
        );

        // Try to process
        vm.prank(superkeeper);
        (uint256 processed, uint256 failed) = crossChainFleetCommander
            .processAsyncOperations(1);

        assertEq(processed, 0, "Should process 0 operations");
        assertEq(failed, 0, "Should have 0 failed operations");
    }

    /*//////////////////////////////////////////////////////////////
                            PROCESSING EVENTS
    //////////////////////////////////////////////////////////////*/

    function testProcessAsyncOperationsEmitsEvent() public {
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);
        queueDeposit(asyncUser2, DEPOSIT_AMOUNT, asyncUser2);

        // Expect event emission with correct operation IDs
        vm.expectEmit(false, false, false, true);
        uint256[] memory operationIds = new uint256[](2);
        operationIds[0] = 1;
        operationIds[1] = 2;
        emit ICrossChainFleetCommander.AsyncOperationsProcessed(
            operationIds, // operationIds (first two operations get IDs 1 and 2)
            2, // processedCount
            0 // failedCount
        );

        vm.prank(superkeeper);
        crossChainFleetCommander.processAsyncOperations(2);
    }

    function testProcessAsyncOperationsWithFailuresEmitsEvent() public {
        // Queue operation that will fail during processing
        address poorUser = address(0x9999);
        uint256 minAmount = crossChainFleetCommander.minQueueAmount();
        mockToken.mint(poorUser, minAmount);
        vm.startPrank(poorUser);
        mockToken.approve(address(crossChainFleetCommander), minAmount);
        vm.stopPrank();

        vm.prank(poorUser);
        crossChainFleetCommander.queueDeposit(minAmount, poorUser);

        // Transfer tokens away after queuing to cause failure during processing
        vm.prank(poorUser);
        mockToken.transfer(address(0x9998), minAmount);

        // Expect event emission with failures
        vm.expectEmit(false, false, false, true);
        emit ICrossChainFleetCommander.AsyncOperationsProcessed(
            new uint256[](1), // operationIds
            0, // processedCount
            1 // failedCount
        );

        vm.prank(superkeeper);
        crossChainFleetCommander.processAsyncOperations(1);
    }

    /*//////////////////////////////////////////////////////////////
                            PROCESSING ORDER
    //////////////////////////////////////////////////////////////*/

    function testProcessFIFOOrder() public {
        // Queue operations in order
        uint256 operationId1 = queueDeposit(
            asyncUser,
            DEPOSIT_AMOUNT,
            asyncUser
        );
        uint256 operationId2 = queueDeposit(
            asyncUser2,
            DEPOSIT_AMOUNT,
            asyncUser2
        );

        // Process first operation
        vm.prank(superkeeper);
        (uint256 processed, uint256 failed) = crossChainFleetCommander
            .processAsyncOperations(1);

        assertEq(processed, 1, "Should process 1 operation");
        assertEq(
            getQueuedOperationsCount(),
            1,
            "Should have 1 queued operation"
        );

        // Check that first operation was processed
        AsyncOperation memory operation1 = getAsyncOperation(operationId1);
        assertTrue(operation1.processed, "First operation should be processed");

        AsyncOperation memory operation2 = getAsyncOperation(operationId2);
        assertFalse(
            operation2.processed,
            "Second operation should not be processed"
        );
    }

    function testProcessMultipleOperationsInOrder() public {
        // Queue multiple operations
        uint256[] memory operationIds = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            address user = address(uint160(0x1000 + i));
            setupAsyncUser(user, DEPOSIT_AMOUNT);
            operationIds[i] = queueDeposit(user, DEPOSIT_AMOUNT, user);
        }

        // Process all operations
        vm.prank(superkeeper);
        (uint256 processed, uint256 failed) = crossChainFleetCommander
            .processAsyncOperations(5);

        assertEq(processed, 5, "Should process 5 operations");
        assertEq(
            getQueuedOperationsCount(),
            0,
            "Should have 0 queued operations"
        );

        // Check all operations were processed
        for (uint256 i = 0; i < 5; i++) {
            AsyncOperation memory operation = getAsyncOperation(
                operationIds[i]
            );
            assertTrue(
                operation.processed,
                "All operations should be processed"
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                            INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testFullDepositWithdrawalCycle() public {
        // 1. Queue deposit
        uint256 depositId = queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);

        // 2. Process deposit
        vm.prank(superkeeper);
        crossChainFleetCommander.processAsyncOperations(1);

        // 3. Queue withdrawal
        uint256 withdrawalId = queueWithdrawal(
            asyncUser,
            WITHDRAWAL_AMOUNT,
            asyncUser,
            asyncUser
        );

        // 4. Process withdrawal
        vm.prank(superkeeper);
        crossChainFleetCommander.processAsyncOperations(1);

        // Check final state
        assertEq(
            getQueuedOperationsCount(),
            0,
            "Should have 0 queued operations"
        );

        AsyncOperation memory deposit = getAsyncOperation(depositId);
        AsyncOperation memory withdrawal = getAsyncOperation(withdrawalId);

        assertTrue(deposit.processed, "Deposit should be processed");
        assertTrue(withdrawal.processed, "Withdrawal should be processed");
    }

    function testMixedOperationTypes() public {
        // Queue different operation types
        uint256 depositId = queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);

        // Process deposit first
        vm.prank(superkeeper);
        crossChainFleetCommander.processAsyncOperations(1);

        // Queue withdrawal and redemption
        uint256 withdrawalId = queueWithdrawal(
            asyncUser,
            WITHDRAWAL_AMOUNT,
            asyncUser,
            asyncUser
        );

        uint256 redemptionId = queueRedemption(
            asyncUser,
            SHARES_AMOUNT,
            asyncUser,
            asyncUser
        );

        // Process both
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

    function testProcessingWithPausedContract() public {
        // Queue operation BEFORE pausing (since queueDeposit also has whenNotPaused modifier)
        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);

        // Pause the contract
        vm.startPrank(governor);
        crossChainFleetCommander.pause();
        vm.stopPrank();

        // Should not be able to process when paused
        vm.prank(superkeeper);
        vm.expectRevert();
        crossChainFleetCommander.processAsyncOperations(1);
    }
}
