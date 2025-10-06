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
 * @title CrossChainFleetCommander Async Operations Tests
 * @notice Test suite for async operations functionality in CrossChainFleetCommander
 * @dev Tests queue operations, operation management, and async processing
 */
contract CrossChainFleetCommanderAsyncOperationsTest is
    CrossChainFleetCommanderTestBase
{
    uint256 constant INITIAL_TIP_RATE = 5; // 5%
    uint256 constant DEPOSIT_AMOUNT = 10000 * 10 ** 6; // 10,000 USDC
    uint256 constant WITHDRAWAL_AMOUNT = 5000 * 10 ** 6; // 5,000 USDC
    uint256 constant SHARES_AMOUNT = 1000 * 10 ** 6; // 1,000 shares (matching USDC decimals)

    function setUp() public {
        initializeCrossChainFleetCommander(INITIAL_TIP_RATE);
        setupAsyncUser(asyncUser, DEPOSIT_AMOUNT * 2);
        setupAsyncUser(asyncUser2, DEPOSIT_AMOUNT * 2);
    }

    /*//////////////////////////////////////////////////////////////
                            QUEUE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function testQueueDeposit() public {
        uint256 operationId = queueDeposit(
            asyncUser,
            DEPOSIT_AMOUNT,
            asyncUser
        );

        // Check operation was queued
        assertTrue(operationId > 0, "Operation ID should be greater than 0");
        assertEq(
            getQueuedOperationsCount(),
            1,
            "Should have 1 queued operation"
        );

        // Check operation details
        AsyncOperation memory operation = getAsyncOperation(operationId);
        assertEq(operation.user, asyncUser, "User should match");
        assertEq(operation.receiver, asyncUser, "Receiver should match");
        assertEq(operation.amount, DEPOSIT_AMOUNT, "Amount should match");
        assertEq(operation.shares, 0, "Shares should be 0 for deposit");
        assertEq(
            operation.operationType,
            0,
            "Operation type should be 0 (deposit)"
        );
        assertFalse(operation.processed, "Operation should not be processed");
    }

    function testQueueWithdrawal() public {
        // First deposit to get shares
        uint256 depositId = queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);

        // Process the deposit first
        vm.prank(superkeeper);
        crossChainFleetCommander.processAsyncOperations(1);

        // Now queue withdrawal
        uint256 operationId = queueWithdrawal(
            asyncUser,
            WITHDRAWAL_AMOUNT,
            asyncUser,
            asyncUser
        );

        // Check operation was queued
        assertTrue(operationId > 0, "Operation ID should be greater than 0");
        assertEq(
            getQueuedOperationsCount(),
            1,
            "Should have 1 queued operation"
        );

        // Check operation details
        AsyncOperation memory operation = getAsyncOperation(operationId);
        assertEq(operation.user, asyncUser, "User should match");
        assertEq(operation.receiver, asyncUser, "Receiver should match");
        assertEq(operation.amount, WITHDRAWAL_AMOUNT, "Amount should match");
        assertTrue(operation.shares > 0, "Shares should be calculated");
        assertEq(
            operation.operationType,
            1,
            "Operation type should be 1 (withdrawal)"
        );
        assertFalse(operation.processed, "Operation should not be processed");
    }

    function testQueueRedemption() public {
        // First deposit to get shares
        uint256 depositId = queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);

        // Process the deposit first
        vm.prank(superkeeper);
        crossChainFleetCommander.processAsyncOperations(1);

        // Now queue redemption
        uint256 operationId = queueRedemption(
            asyncUser,
            SHARES_AMOUNT,
            asyncUser,
            asyncUser
        );

        // Check operation was queued
        assertTrue(operationId > 0, "Operation ID should be greater than 0");
        assertEq(
            getQueuedOperationsCount(),
            1,
            "Should have 1 queued operation"
        );

        // Check operation details
        AsyncOperation memory operation = getAsyncOperation(operationId);
        assertEq(operation.user, asyncUser, "User should match");
        assertEq(operation.receiver, asyncUser, "Receiver should match");
        assertTrue(operation.amount > 0, "Amount should be calculated");
        assertEq(operation.shares, SHARES_AMOUNT, "Shares should match");
        assertEq(
            operation.operationType,
            2,
            "Operation type should be 2 (redemption)"
        );
        assertFalse(operation.processed, "Operation should not be processed");
    }

    function testQueueDepositWithDifferentReceiver() public {
        uint256 operationId = queueDeposit(
            asyncUser,
            DEPOSIT_AMOUNT,
            asyncUser2
        );

        AsyncOperation memory operation = getAsyncOperation(operationId);
        assertEq(operation.user, asyncUser, "User should be the caller");
        assertEq(
            operation.receiver,
            asyncUser2,
            "Receiver should be different"
        );
    }

    function testQueueWithdrawalWithDifferentReceiver() public {
        // First deposit to get shares
        uint256 depositId = queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);
        vm.prank(superkeeper);
        crossChainFleetCommander.processAsyncOperations(1);

        uint256 operationId = queueWithdrawal(
            asyncUser,
            WITHDRAWAL_AMOUNT,
            asyncUser2,
            asyncUser
        );

        AsyncOperation memory operation = getAsyncOperation(operationId);
        assertEq(operation.user, asyncUser, "User should be the caller");
        assertEq(
            operation.receiver,
            asyncUser2,
            "Receiver should be different"
        );
        assertEq(operation.amount, WITHDRAWAL_AMOUNT, "Amount should match");
    }

    /*//////////////////////////////////////////////////////////////
                            VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testQueueDepositBelowMinimum() public {
        uint256 belowMinimum = MIN_QUEUE_AMOUNT - 1;

        vm.prank(asyncUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainFleetCommanderErrors
                    .CrossChainFleetCommanderAmountBelowMinimum
                    .selector,
                belowMinimum,
                MIN_QUEUE_AMOUNT
            )
        );
        crossChainFleetCommander.queueDeposit(belowMinimum, asyncUser);
    }

    function testQueueWithdrawalBelowMinimum() public {
        uint256 belowMinimum = MIN_QUEUE_AMOUNT - 1;

        vm.prank(asyncUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainFleetCommanderErrors
                    .CrossChainFleetCommanderAmountBelowMinimum
                    .selector,
                belowMinimum,
                MIN_QUEUE_AMOUNT
            )
        );
        crossChainFleetCommander.queueWithdrawal(
            belowMinimum,
            asyncUser,
            asyncUser
        );
    }

    function testQueueDepositWithInsufficientBalance() public {
        uint256 excessiveAmount = DEPOSIT_AMOUNT * 10;

        vm.prank(asyncUser);
        vm.expectRevert();
        crossChainFleetCommander.queueDeposit(excessiveAmount, asyncUser);
    }

    function testQueueWithdrawalWithInsufficientShares() public {
        vm.prank(asyncUser);
        vm.expectRevert();
        crossChainFleetCommander.queueWithdrawal(
            WITHDRAWAL_AMOUNT,
            asyncUser,
            asyncUser
        );
    }

    function testQueueRedemptionWithInsufficientShares() public {
        vm.prank(asyncUser);
        vm.expectRevert();
        crossChainFleetCommander.queueRedemption(
            SHARES_AMOUNT,
            asyncUser,
            asyncUser
        );
    }

    /*//////////////////////////////////////////////////////////////
                            QUEUE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function testMultipleQueueOperations() public {
        // Queue multiple operations
        uint256 depositId1 = queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);
        uint256 depositId2 = queueDeposit(
            asyncUser2,
            DEPOSIT_AMOUNT,
            asyncUser2
        );

        assertEq(
            getQueuedOperationsCount(),
            2,
            "Should have 2 queued operations"
        );
        assertEq(
            crossChainFleetCommander.getNextOperationId(),
            depositId1,
            "Next operation should be first"
        );

        // Check operation IDs are sequential
        assertTrue(
            depositId2 > depositId1,
            "Operation IDs should be sequential"
        );
    }

    function testQueueFIFOOrder() public {
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

        // Check FIFO order
        assertEq(
            crossChainFleetCommander.getNextOperationId(),
            operationId1,
            "First operation should be next"
        );

        // Process first operation
        vm.prank(superkeeper);
        crossChainFleetCommander.processAsyncOperations(1);

        // Check second operation is now next
        assertEq(
            crossChainFleetCommander.getNextOperationId(),
            operationId2,
            "Second operation should be next"
        );
    }

    function testQueueSizeLimit() public {
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
        address overflowUser = address(0x9999);
        setupAsyncUser(overflowUser, DEPOSIT_AMOUNT);

        vm.prank(overflowUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainFleetCommanderErrors
                    .CrossChainFleetCommanderQueueFull
                    .selector,
                500, // current queue size
                500 // max queue size
            )
        );
        crossChainFleetCommander.queueDeposit(MIN_QUEUE_AMOUNT, overflowUser);
    }

    /*//////////////////////////////////////////////////////////////
                            OPERATION CANCELLATION
    //////////////////////////////////////////////////////////////*/

    function testCancelOperation() public {
        uint256 operationId = queueDeposit(
            asyncUser,
            DEPOSIT_AMOUNT,
            asyncUser
        );

        // Cancel the operation
        cancelOperation(operationId);

        // Check operation is marked as processed (cancelled)
        AsyncOperation memory operation = getAsyncOperation(operationId);
        assertTrue(
            operation.processed,
            "Operation should be marked as processed"
        );
        assertEq(
            getQueuedOperationsCount(),
            0,
            "Should have 0 queued operations"
        );
    }

    function testCancelNonExistentOperation() public {
        vm.prank(asyncUser);
        vm.expectRevert();
        crossChainFleetCommander.cancelOperation(999);
    }

    function testCancelOperationByNonOwner() public {
        uint256 operationId = queueDeposit(
            asyncUser,
            DEPOSIT_AMOUNT,
            asyncUser
        );

        vm.prank(asyncUser2);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainFleetCommanderErrors
                    .CrossChainFleetCommanderNotYourOperation
                    .selector,
                operationId,
                asyncUser2,
                asyncUser
            )
        );
        crossChainFleetCommander.cancelOperation(operationId);
    }

    function testCancelAlreadyProcessedOperation() public {
        uint256 operationId = queueDeposit(
            asyncUser,
            DEPOSIT_AMOUNT,
            asyncUser
        );

        // Process the operation first
        vm.prank(superkeeper);
        crossChainFleetCommander.processAsyncOperations(1);

        // Try to cancel processed operation
        vm.prank(asyncUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainFleetCommanderErrors
                    .CrossChainFleetCommanderOperationAlreadyProcessedForCancellation
                    .selector,
                operationId
            )
        );
        crossChainFleetCommander.cancelOperation(operationId);
    }

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    function testQueueDepositEmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit ICrossChainFleetCommander.AsyncOperationQueued(
            1, // operationId
            asyncUser,
            0, // operationType (deposit)
            DEPOSIT_AMOUNT,
            block.timestamp
        );

        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);
    }

    function testQueueWithdrawalEmitsEvent() public {
        // First deposit to get shares
        uint256 depositId = queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);
        vm.prank(superkeeper);
        crossChainFleetCommander.processAsyncOperations(1);

        vm.expectEmit(true, true, false, true);
        emit ICrossChainFleetCommander.AsyncOperationQueued(
            2, // operationId
            asyncUser,
            1, // operationType (withdrawal)
            WITHDRAWAL_AMOUNT,
            block.timestamp
        );

        queueWithdrawal(asyncUser, WITHDRAWAL_AMOUNT, asyncUser, asyncUser);
    }

    function testQueueRedemptionEmitsEvent() public {
        // First deposit to get shares
        uint256 depositId = queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);
        vm.prank(superkeeper);
        crossChainFleetCommander.processAsyncOperations(1);

        vm.expectEmit(true, true, false, true);
        emit ICrossChainFleetCommander.AsyncOperationQueued(
            2, // operationId
            asyncUser,
            2, // operationType (redemption)
            SHARES_AMOUNT,
            block.timestamp
        );

        queueRedemption(asyncUser, SHARES_AMOUNT, asyncUser, asyncUser);
    }

    function testCancelOperationEmitsEvent() public {
        uint256 operationId = queueDeposit(
            asyncUser,
            DEPOSIT_AMOUNT,
            asyncUser
        );

        vm.expectEmit(true, true, false, false);
        emit ICrossChainFleetCommander.AsyncOperationCancelled(
            operationId,
            asyncUser
        );

        cancelOperation(operationId);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function testGetAsyncOperation() public {
        uint256 operationId = queueDeposit(
            asyncUser,
            DEPOSIT_AMOUNT,
            asyncUser
        );

        AsyncOperation memory operation = getAsyncOperation(operationId);
        assertEq(operation.user, asyncUser, "User should match");
        assertEq(operation.amount, DEPOSIT_AMOUNT, "Amount should match");
        assertEq(operation.operationType, 0, "Operation type should be 0");
    }

    function testGetQueuedOperationsCount() public {
        assertEq(
            getQueuedOperationsCount(),
            0,
            "Should start with 0 operations"
        );

        queueDeposit(asyncUser, DEPOSIT_AMOUNT, asyncUser);
        assertEq(getQueuedOperationsCount(), 1, "Should have 1 operation");

        queueDeposit(asyncUser2, DEPOSIT_AMOUNT, asyncUser2);
        assertEq(getQueuedOperationsCount(), 2, "Should have 2 operations");
    }

    function testGetNextOperationId() public {
        assertEq(
            crossChainFleetCommander.getNextOperationId(),
            0,
            "Should start with 0"
        );

        uint256 operationId = queueDeposit(
            asyncUser,
            DEPOSIT_AMOUNT,
            asyncUser
        );
        assertEq(
            crossChainFleetCommander.getNextOperationId(),
            operationId,
            "Should return first operation"
        );
    }

    function testGetMinQueueAmount() public {
        assertEq(
            crossChainFleetCommander.getMinQueueAmount(),
            MIN_QUEUE_AMOUNT,
            "Min queue amount should match"
        );
    }

    function testGetMaxQueueSize() public {
        assertEq(
            crossChainFleetCommander.getMaxQueueSize(),
            500,
            "Max queue size should be 500"
        );
    }
}
