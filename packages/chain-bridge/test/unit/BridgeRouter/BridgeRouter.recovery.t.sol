// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeRouter} from "../../../src/router/BridgeRouter.sol";
import {IBridgeRouter} from "../../../src/interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "../../../src/libraries/BridgeTypes.sol";
import {BridgeRouterSetup} from "./BridgeRouter.setup.t.sol";
import {IAccessControlErrors} from "@summerfi/access-contracts/interfaces/IAccessControlErrors.sol";
import {RejectETH} from "../../mocks/RejectETH.sol";
import {MockCrossChainReceiver} from "../../mocks/MockCrossChainReceiver.sol";
import {Errors} from "@openzeppelin/contracts/utils/Errors.sol";

// Reentrancy attack contract
contract ReentrancyAttacker {
    BridgeRouter public router;
    uint256 public callCount;

    constructor(BridgeRouter _router) {
        router = _router;
    }

    receive() external payable {
        callCount++;
        if (callCount == 1) {
            // Try to reenter
            router.sweep(address(0), address(this), 1 ether);
        }
    }

    function testSkip() public {}
}

contract BridgeRouterRecoveryTest is BridgeRouterSetup {
    /* ------------------------------------------------------------ */
    /*                    Failure recording & retry                 */
    /* ------------------------------------------------------------ */

    function setUp() public override {
        super.setUp();

        // Setup peer relationship for retry tests
        address fleetProxy = address(0x1002);

        vm.startPrank(governor);
        // Register bijective peer relationship
        registry.registerAdapterPeerPair(
            fleetProxy,
            address(mockReceiver),
            SOURCE_CHAIN_ID,
            CURRENT_CHAIN_ID
        );
        vm.stopPrank();
    }

    function _makeFailedTransfer(
        bytes32 opId,
        uint256 amount
    ) internal returns (bytes32) {
        // Configure receiver to fail
        mockReceiver.setReceiveSuccess(false);

        // Use fleetProxy as originator for peer relationship
        address fleetProxy = address(0x1002);

        // Build transfer payload
        BridgeTypes.RelayedTransferParams memory p = BridgeTypes
            .RelayedTransferParams({
                operationId: opId,
                originator: fleetProxy,
                sourceChainId: SOURCE_CHAIN_ID,
                recipient: address(mockReceiver),
                asset: address(token),
                amount: amount,
                message: ""
            });

        bytes memory payload = abi.encode(p);

        // Deliver from registered adapter
        vm.startPrank(address(mockAdapter));
        router.deliver(BridgeTypes.OperationType.TRANSFER_ASSET, payload);
        vm.stopPrank();

        // Verify the failure was recorded
        assertTrue(router.hasFailedDelivery(opId));

        return opId;
    }

    function testRecordFailureAndRetry_Succeeds() public {
        bytes32 opId = keccak256("op1");
        uint256 amount = 10 ether;

        _makeFailedTransfer(opId, amount);

        // Now allow receiver to succeed
        mockReceiver.setReceiveSuccess(true);

        // Retry without overrides
        vm.prank(keeper);
        router.retryFailedDelivery(opId, address(0));

        // Failure cleared
        (bytes32[] memory ids2, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids2.length, 0);

        // Assets delivered
        assertEq(token.balanceOf(address(mockReceiver)), amount);
    }

    // NOTE: Amount override tests removed as only recipient overrides are supported
    // function testRetryWithOverridePayload_ChangesAmount() - REMOVED

    function testGetFailedDelivery_NonExistentOperationId_RevertsWithFailureRecordNotFound()
        public
    {
        bytes32 nonExistentOpId = keccak256("non-existent-operation");

        vm.expectRevert(IBridgeRouter.FailureRecordNotFound.selector);
        router.getFailedDelivery(nonExistentOpId);
    }

    function testGetFailedDelivery_ExistingOperationId_ReturnsRecord() public {
        // Create a failed operation
        bytes32 opId = _makeFailedTransfer(keccak256("test-op"), 1 ether);

        // Get the failure record
        BridgeRouter.FailedDeliveryRecord memory record = router
            .getFailedDelivery(opId);

        // Verify the record contains expected data
        assertEq(
            uint8(record.operationType),
            uint8(BridgeTypes.OperationType.TRANSFER_ASSET)
        );
        assertEq(record.adapter, address(mockAdapter));
        assertEq(record.sourceChainId, SOURCE_CHAIN_ID);
        assertEq(record.failedAt, block.timestamp);
    }

    /* ------------------------------------------------------------ */
    /*                    New Query Functions Tests                  */
    /* ------------------------------------------------------------ */

    function testGetFailedDeliveryCount_NoFailures_ReturnsZero() public {
        uint256 count = router.getFailedDeliveryCount();
        assertEq(count, 0);
    }

    function testGetFailedDeliveryCount_WithFailures_ReturnsCorrectCount()
        public
    {
        // Clear any existing failures first
        (bytes32[] memory existingIds, ) = router.getFailedDeliveryIds(0, 100);
        for (uint256 i = 0; i < existingIds.length; i++) {
            mockReceiver.setReceiveSuccess(true);
            vm.prank(keeper);
            router.retryFailedDelivery(existingIds[i], address(0));
        }

        // Create multiple failures
        bytes32 opId1 = _makeFailedTransfer(keccak256("op1"), 1 ether);
        bytes32 opId2 = _makeFailedTransfer(keccak256("op2"), 1 ether);
        bytes32 opId3 = _makeFailedTransfer(keccak256("op3"), 1 ether);

        uint256 count = router.getFailedDeliveryCount();
        assertEq(count, 3);

        // Verify the IDs are tracked
        (bytes32[] memory ids, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids.length, 3);
        assertEq(ids[0], opId1);
        assertEq(ids[1], opId2);
        assertEq(ids[2], opId3);
    }

    function testHasFailedDelivery_NonExistentOperation_ReturnsFalse() public {
        bytes32 nonExistentOpId = keccak256("non-existent");
        bool hasFailed = router.hasFailedDelivery(nonExistentOpId);
        assertFalse(hasFailed);
    }

    function testHasFailedDelivery_ExistingOperation_ReturnsTrue() public {
        bytes32 opId = _makeFailedTransfer(keccak256("existing-op"), 1 ether);
        bool hasFailed = router.hasFailedDelivery(opId);
        assertTrue(hasFailed);
    }

    function testHasFailedDelivery_AfterClearing_ReturnsFalse() public {
        bytes32 opId = _makeFailedTransfer(keccak256("clear-test"), 1 ether);

        // Verify it exists
        assertTrue(router.hasFailedDelivery(opId));

        // Allow receiver to succeed for retry
        mockReceiver.setReceiveSuccess(true);

        // Clear the failure
        vm.prank(keeper);
        router.retryFailedDelivery(opId, address(0));

        // Should no longer exist
        assertFalse(router.hasFailedDelivery(opId));
    }

    /* ------------------------------------------------------------ */
    /*                    Gas Optimization Tests                    */
    /* ------------------------------------------------------------ */

    function testRecordFailedDelivery_RetryFailure_PreservesOriginalMetadata()
        public
    {
        bytes32 opId = _makeFailedTransfer(keccak256("retry-test"), 1 ether);

        // Get original record
        BridgeRouter.FailedDeliveryRecord memory originalRecord = router
            .getFailedDelivery(opId);
        uint256 originalFailedAt = originalRecord.failedAt;

        // Wait a bit to ensure timestamp difference
        vm.warp(block.timestamp + 100);

        // Simulate retry failure by creating another failure with same ID
        // This should only update the timestamp, not other fields
        mockReceiver.setReceiveSuccess(false);

        BridgeTypes.RelayedTransferParams memory p = BridgeTypes
            .RelayedTransferParams({
                operationId: opId,
                originator: address(0x1002),
                sourceChainId: SOURCE_CHAIN_ID,
                recipient: address(mockReceiver),
                asset: address(token),
                amount: 2 ether, // Different amount
                message: ""
            });

        bytes memory payload = abi.encode(p);

        vm.startPrank(address(mockAdapter));
        router.deliver(BridgeTypes.OperationType.TRANSFER_ASSET, payload);
        vm.stopPrank();

        // Get updated record
        BridgeRouter.FailedDeliveryRecord memory updatedRecord = router
            .getFailedDelivery(opId);

        // Verify original metadata is preserved
        assertEq(
            uint8(updatedRecord.operationType),
            uint8(originalRecord.operationType)
        );
        assertEq(updatedRecord.adapter, originalRecord.adapter);
        assertEq(updatedRecord.sourceChainId, originalRecord.sourceChainId);
        assertEq(
            updatedRecord.operationPayload,
            originalRecord.operationPayload
        );

        // Verify timestamp was updated
        assertGt(updatedRecord.failedAt, originalFailedAt);
        assertEq(updatedRecord.failedAt, block.timestamp);
    }

    /* ------------------------------------------------------------ */
    /*                    Pagination Tests                          */
    /* ------------------------------------------------------------ */

    function testGetFailedDeliveryIds_Pagination_WorksCorrectly() public {
        // Clear any existing failures first
        (bytes32[] memory existingIds, ) = router.getFailedDeliveryIds(0, 100);
        for (uint256 i = 0; i < existingIds.length; i++) {
            mockReceiver.setReceiveSuccess(true);
            vm.prank(keeper);
            router.retryFailedDelivery(existingIds[i], address(0));
        }

        // Create 5 failures
        bytes32[] memory opIds = new bytes32[](5);
        for (uint256 i = 0; i < 5; i++) {
            opIds[i] = _makeFailedTransfer(
                keccak256(abi.encodePacked("op", i)),
                1 ether
            );
        }

        // Test first page
        (bytes32[] memory page1, uint256 nextCursor1) = router
            .getFailedDeliveryIds(0, 3);
        assertEq(page1.length, 3);
        assertEq(nextCursor1, 3);

        // Test second page
        (bytes32[] memory page2, uint256 nextCursor2) = router
            .getFailedDeliveryIds(3, 3);
        assertEq(page2.length, 2);
        assertEq(nextCursor2, 5);

        // Test beyond available
        (bytes32[] memory page3, uint256 nextCursor3) = router
            .getFailedDeliveryIds(5, 3);
        assertEq(page3.length, 0);
        assertEq(nextCursor3, 5);
    }

    function testGetFailedDeliveryIds_EmptySet_ReturnsEmptyArray() public {
        (bytes32[] memory ids, uint256 nextCursor) = router
            .getFailedDeliveryIds(0, 10);
        assertEq(ids.length, 0);
        assertEq(nextCursor, 0);
    }

    /* ------------------------------------------------------------ */
    /*                    Payload Validation Tests                   */
    /* ------------------------------------------------------------ */

    function testRetryWithValidArkFleetRelationship_Succeeds() public {
        // Setup peer relationship with unique addresses
        address fleetProxy = address(0x1002);

        vm.startPrank(governor);
        // Only register if not already registered
        try
            registry.registerRelationship(
                address(mockReceiver),
                fleetProxy,
                CURRENT_CHAIN_ID,
                SOURCE_CHAIN_ID,
                registry.PEER_RELATIONSHIP()
            )
        {} catch {}

        // Register reverse relationship for validation
        try
            registry.registerRelationship(
                fleetProxy,
                address(mockReceiver),
                SOURCE_CHAIN_ID,
                CURRENT_CHAIN_ID,
                registry.PEER_RELATIONSHIP()
            )
        {} catch {}
        vm.stopPrank();

        bytes32 opId = keccak256("valid-ark-fleet");
        uint256 amount = 10 ether;

        // Create failed transfer with valid peer relationship
        _makeFailedTransferWithArkFleet(
            opId,
            amount,
            address(mockReceiver),
            fleetProxy
        );

        // Allow receiver to succeed
        mockReceiver.setReceiveSuccess(true);

        // Retry should succeed
        vm.prank(keeper);
        router.retryFailedDelivery(opId, address(0));

        // Verify success
        (bytes32[] memory ids, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids.length, 0);
        assertEq(token.balanceOf(address(mockReceiver)), amount);
    }

    function testRetryWithInvalidArkFleetRelationship_Reverts() public {
        // Setup peer relationship with unique addresses
        address fleetProxy = address(0x1002);
        address wrongFleet = address(0x9999);

        vm.startPrank(governor);
        // Only register if not already registered
        try
            registry.registerRelationship(
                address(mockReceiver),
                fleetProxy,
                CURRENT_CHAIN_ID,
                SOURCE_CHAIN_ID,
                registry.PEER_RELATIONSHIP()
            )
        {} catch {}

        // Register reverse relationship for validation
        try
            registry.registerRelationship(
                fleetProxy,
                address(mockReceiver),
                SOURCE_CHAIN_ID,
                CURRENT_CHAIN_ID,
                registry.PEER_RELATIONSHIP()
            )
        {} catch {}
        vm.stopPrank();

        bytes32 opId = keccak256("invalid-ark-fleet");
        uint256 amount = 10 ether;

        // Create failed transfer with invalid peer relationship
        _makeFailedTransferWithArkFleet(
            opId,
            amount,
            address(mockReceiver),
            wrongFleet
        );

        // Allow receiver to succeed
        mockReceiver.setReceiveSuccess(true);

        // Retry should revert with InvalidRecipient
        vm.prank(keeper);
        vm.expectRevert(IBridgeRouter.InvalidRecipient.selector);
        router.retryFailedDelivery(opId, address(0));
    }

    function testRetryWithNonArkRecipient_Reverts() public {
        bytes32 opId = keccak256("non-ark-recipient");
        uint256 amount = 10 ether;

        // Create failed transfer with non-peer recipient (should now be rejected)
        // Use a recipient that is NOT registered in the peer relationship
        address nonArkRecipient = address(0x9999);
        _makeFailedTransferWithArkFleet(
            opId,
            amount,
            nonArkRecipient, // This recipient is not registered in ark-fleet relationship
            address(0x1002) // fleetProxy as originator
        );

        // Allow receiver to succeed (though it won't matter since validation will fail first)
        mockReceiver.setReceiveSuccess(true);

        // Retry should revert with InvalidRecipient (non-ark recipients are no longer allowed)
        vm.prank(keeper);
        vm.expectRevert(IBridgeRouter.InvalidRecipient.selector);
        router.retryFailedDelivery(opId, address(0));

        // Verify failure record still exists
        assertTrue(router.hasFailedDelivery(opId));
    }

    function testRetryWithMessagePayload_ValidArkFleet_Succeeds() public {
        // Setup peer relationship with unique addresses
        address fleetProxy = address(0x1002);

        vm.startPrank(governor);
        // Register mockReceiver as ark proxy - only if not already registered
        try
            registry.registerRelationship(
                address(mockReceiver),
                fleetProxy,
                CURRENT_CHAIN_ID,
                SOURCE_CHAIN_ID,
                registry.PEER_RELATIONSHIP()
            )
        {} catch {}

        try
            registry.registerRelationship(
                fleetProxy,
                address(mockReceiver),
                SOURCE_CHAIN_ID,
                CURRENT_CHAIN_ID,
                registry.PEER_RELATIONSHIP()
            )
        {} catch {}
        vm.stopPrank();

        bytes32 opId = keccak256("valid-message-ark-fleet");

        // Create failed message with valid peer relationship
        _makeFailedMessageWithArkFleet(opId, address(mockReceiver), fleetProxy);

        // Allow receiver to succeed
        mockReceiver.setReceiveSuccess(true);

        // Retry should succeed
        vm.prank(keeper);
        router.retryFailedDelivery(opId, address(0));

        // Verify success
        (bytes32[] memory ids, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids.length, 0);
    }

    function testRetryWithMessagePayload_InvalidArkFleet_Reverts() public {
        // Setup peer relationship with unique addresses
        address fleetProxy = address(0x1002);
        address wrongFleet = address(0x9999);

        vm.startPrank(governor);
        // Register mockReceiver as ark proxy - only if not already registered
        try
            registry.registerRelationship(
                address(mockReceiver),
                fleetProxy,
                CURRENT_CHAIN_ID,
                SOURCE_CHAIN_ID,
                registry.PEER_RELATIONSHIP()
            )
        {} catch {}

        try
            registry.registerRelationship(
                fleetProxy,
                address(mockReceiver),
                SOURCE_CHAIN_ID,
                CURRENT_CHAIN_ID,
                registry.PEER_RELATIONSHIP()
            )
        {} catch {}
        vm.stopPrank();

        bytes32 opId = keccak256("invalid-message-ark-fleet");

        // Create failed message with invalid peer relationship
        _makeFailedMessageWithArkFleet(opId, address(mockReceiver), wrongFleet);

        // Allow receiver to succeed
        mockReceiver.setReceiveSuccess(true);

        // Retry should revert with InvalidRecipient
        vm.prank(keeper);
        vm.expectRevert(IBridgeRouter.InvalidRecipient.selector);
        router.retryFailedDelivery(opId, address(0));
    }

    // NOTE: Originator override tests removed as originator overrides are no longer supported
    // function testRetryWithOverridePayload_InvalidArkFleet_Reverts() - REMOVED

    function testRetryWithOverridePayload_ValidArkFleet_Succeeds() public {
        // Setup peer relationship with unique addresses
        address fleetProxy = address(0x1002);

        vm.startPrank(governor);
        // Register mockReceiver as ark proxy - only if not already registered
        try
            registry.registerRelationship(
                address(mockReceiver),
                fleetProxy,
                CURRENT_CHAIN_ID,
                SOURCE_CHAIN_ID,
                registry.PEER_RELATIONSHIP()
            )
        {} catch {}

        try
            registry.registerRelationship(
                fleetProxy,
                address(mockReceiver),
                SOURCE_CHAIN_ID,
                CURRENT_CHAIN_ID,
                registry.PEER_RELATIONSHIP()
            )
        {} catch {}
        vm.stopPrank();

        bytes32 opId = keccak256("override-valid-ark-fleet");
        uint256 amount = 10 ether;

        // Create failed transfer with valid relationship
        _makeFailedTransferWithArkFleet(
            opId,
            amount,
            address(mockReceiver),
            fleetProxy
        );

        // No overrides needed - just retry with original parameters
        // Allow receiver to succeed
        mockReceiver.setReceiveSuccess(true);

        // Retry should succeed
        vm.prank(keeper);
        router.retryFailedDelivery(opId, address(0));

        // Verify success with original amount
        (bytes32[] memory ids, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids.length, 0);
        assertEq(token.balanceOf(address(mockReceiver)), amount);
    }

    function testRetryWithNoOverrides_Succeeds() public {
        bytes32 opId = keccak256("no-overrides-test");
        uint256 amount = 5 ether;

        // Create failed transfer with original asset
        _makeFailedTransfer(opId, amount);

        // Allow receiver to succeed
        mockReceiver.setReceiveSuccess(true);

        // Retry with no overrides
        vm.prank(keeper);
        router.retryFailedDelivery(opId, address(0));

        // Verify success with original asset
        (bytes32[] memory ids, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids.length, 0);
        assertEq(token.balanceOf(address(mockReceiver)), amount);
    }

    function testRetryWithRecipientOverride_Succeeds() public {
        bytes32 opId = keccak256("recipient-override-test");
        uint256 amount = 3 ether;

        // Create failed transfer
        _makeFailedTransfer(opId, amount);

        // Deploy new receiver
        MockCrossChainReceiver newReceiver = new MockCrossChainReceiver();
        newReceiver.setReceiveSuccess(true);

        // Unregister the existing relationship for mockReceiver first
        address fleetProxy = address(0x1002);
        vm.startPrank(governor);
        registry.unregisterAdapterPeerPair(
            address(mockReceiver),
            fleetProxy,
            CURRENT_CHAIN_ID,
            SOURCE_CHAIN_ID
        );

        // Register the new receiver in the peer relationship
        registry.registerAdapterPeerPair(
            fleetProxy,
            address(newReceiver),
            SOURCE_CHAIN_ID,
            CURRENT_CHAIN_ID
        );
        vm.stopPrank();

        // Retry with recipient override only
        vm.prank(keeper);
        router.retryFailedDelivery(opId, address(newReceiver));

        // Verify success with original asset and new receiver
        (bytes32[] memory ids, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids.length, 0);
        assertEq(token.balanceOf(address(newReceiver)), amount);
        // Original receiver should not have received anything
        assertEq(token.balanceOf(address(mockReceiver)), 0);
    }

    /* ------------------------------------------------------------ */
    /*                     Recover assets (moved)                    */
    /* ------------------------------------------------------------ */

    function testRecoverFunds_Success() public {
        uint256 fundAmount = 5 ether;
        vm.deal(address(router), fundAmount);

        uint256 initialRouterBalance = address(router).balance;
        uint256 initialGovernorBalance = governor.balance;
        uint256 recoverAmount = 2 ether;

        vm.startPrank(governor);
        vm.expectEmit(true, false, false, true);
        emit IBridgeRouter.RouterAssetsRecovered(
            address(0),
            governor,
            recoverAmount
        );
        router.sweep(address(0), governor, recoverAmount);
        vm.stopPrank();

        assertEq(address(router).balance, initialRouterBalance - recoverAmount);
        assertEq(governor.balance, initialGovernorBalance + recoverAmount);
    }

    function testRecoverFunds_AccessControl() public {
        uint256 fundAmount = 5 ether;
        vm.deal(address(router), fundAmount);

        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                user
            )
        );
        router.sweep(address(0), user, 1 ether);
        vm.stopPrank();

        vm.startPrank(guardian);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                guardian
            )
        );
        router.sweep(address(0), guardian, 1 ether);
        vm.stopPrank();
    }

    function testRecoverFunds_InvalidRecipient() public {
        uint256 fundAmount = 5 ether;
        vm.deal(address(router), fundAmount);

        vm.startPrank(governor);
        vm.expectRevert(IBridgeRouter.InvalidParams.selector);
        router.sweep(address(0), address(0), 1 ether);
        vm.stopPrank();
    }

    function testRecoverFunds_InsufficientBalance() public {
        uint256 fundAmount = 1 ether;
        vm.deal(address(router), fundAmount);

        vm.startPrank(governor);
        vm.expectRevert(IBridgeRouter.InsufficientBalance.selector);
        router.sweep(address(0), governor, 2 ether);
        vm.stopPrank();
    }

    function testRecoverFunds_TransferFailed() public {
        uint256 fundAmount = 5 ether;
        vm.deal(address(router), fundAmount);

        RejectETH rejectContract = new RejectETH();

        vm.startPrank(governor);
        vm.expectRevert(Errors.FailedCall.selector);
        router.sweep(address(0), address(rejectContract), 1 ether);
        vm.stopPrank();
    }

    function testRecoverFunds_ZeroAmount() public {
        uint256 fundAmount = 5 ether;
        vm.deal(address(router), fundAmount);

        uint256 initialRouterBalance = address(router).balance;
        uint256 initialGovernorBalance = governor.balance;

        vm.startPrank(governor);
        vm.expectEmit(true, false, false, true);
        emit IBridgeRouter.RouterAssetsRecovered(address(0), governor, 0);
        router.sweep(address(0), governor, 0);
        vm.stopPrank();

        assertEq(address(router).balance, initialRouterBalance);
        assertEq(governor.balance, initialGovernorBalance);
    }

    function testRecoverFunds_ExactBalance() public {
        uint256 fundAmount = 3 ether;
        vm.deal(address(router), fundAmount);

        uint256 initialGovernorBalance = governor.balance;

        vm.startPrank(governor);
        vm.expectEmit(true, false, false, true);
        emit IBridgeRouter.RouterAssetsRecovered(
            address(0),
            governor,
            fundAmount
        );
        router.sweep(address(0), governor, fundAmount);
        vm.stopPrank();

        assertEq(address(router).balance, 0);
        assertEq(governor.balance, initialGovernorBalance + fundAmount);
    }

    function testRecoverFunds_ReentrancyProtection() public {
        uint256 fundAmount = 5 ether;
        vm.deal(address(router), fundAmount);

        ReentrancyAttacker attacker = new ReentrancyAttacker(router);

        vm.startPrank(governor);
        vm.expectRevert(Errors.FailedCall.selector);
        router.sweep(address(0), address(attacker), 1 ether);
        vm.stopPrank();

        assertEq(attacker.callCount(), 0);
        assertEq(address(router).balance, fundAmount);
    }

    function testRecoverFunds_MultipleRecoveries() public {
        uint256 fundAmount = 10 ether;
        vm.deal(address(router), fundAmount);

        uint256 initialGovernorBalance = governor.balance;

        vm.startPrank(governor);

        uint256 firstAmount = 3 ether;
        vm.expectEmit(true, false, false, true);
        emit IBridgeRouter.RouterAssetsRecovered(
            address(0),
            governor,
            firstAmount
        );
        router.sweep(address(0), governor, firstAmount);

        uint256 secondAmount = 2 ether;
        vm.expectEmit(true, false, false, true);
        emit IBridgeRouter.RouterAssetsRecovered(
            address(0),
            governor,
            secondAmount
        );
        router.sweep(address(0), governor, secondAmount);

        vm.stopPrank();

        assertEq(
            address(router).balance,
            fundAmount - firstAmount - secondAmount
        );
        assertEq(
            governor.balance,
            initialGovernorBalance + firstAmount + secondAmount
        );
    }

    function testRecoverFunds_ToExternalAccount() public {
        uint256 fundAmount = 5 ether;
        vm.deal(address(router), fundAmount);

        address externalAccount = address(0x12345);
        uint256 initialExternalBalance = externalAccount.balance;
        uint256 recoverAmount = 2 ether;

        vm.startPrank(governor);
        vm.expectEmit(true, false, false, true);
        emit IBridgeRouter.RouterAssetsRecovered(
            address(0),
            externalAccount,
            recoverAmount
        );
        router.sweep(address(0), externalAccount, recoverAmount);
        vm.stopPrank();

        assertEq(address(router).balance, fundAmount - recoverAmount);
        assertEq(
            externalAccount.balance,
            initialExternalBalance + recoverAmount
        );
    }

    function testRecoverAssets_Native_Success() public {
        uint256 fundAmount = 5 ether;
        vm.deal(address(router), fundAmount);

        uint256 initialRouterBalance = address(router).balance;
        uint256 initialGovernorBalance = governor.balance;
        uint256 recoverAmount = 2 ether;

        vm.startPrank(governor);
        vm.expectEmit(true, true, false, true);
        emit IBridgeRouter.RouterAssetsRecovered(
            address(0),
            governor,
            recoverAmount
        );
        router.sweep(address(0), governor, recoverAmount);
        vm.stopPrank();

        assertEq(address(router).balance, initialRouterBalance - recoverAmount);
        assertEq(governor.balance, initialGovernorBalance + recoverAmount);
    }

    function testRecoverAssets_ERC20_Success() public {
        uint256 initialRouterToken = token.balanceOf(address(router));
        uint256 initialGovernorToken = token.balanceOf(governor);
        uint256 recoverAmount = 100 ether;

        vm.startPrank(governor);
        vm.expectEmit(true, true, false, true);
        emit IBridgeRouter.RouterAssetsRecovered(
            address(token),
            governor,
            recoverAmount
        );
        router.sweep(address(token), governor, recoverAmount);
        vm.stopPrank();

        assertEq(
            token.balanceOf(address(router)),
            initialRouterToken - recoverAmount
        );
        assertEq(
            token.balanceOf(governor),
            initialGovernorToken + recoverAmount
        );
    }

    function testRecoverAssets_InvalidRecipient() public {
        vm.startPrank(governor);
        vm.expectRevert(IBridgeRouter.InvalidParams.selector);
        router.sweep(address(0), address(0), 1 ether);
        vm.stopPrank();
    }

    function testRecoverAssets_AccessControl() public {
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                user
            )
        );
        router.sweep(address(0), user, 1 ether);
        vm.stopPrank();

        vm.startPrank(guardian);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                guardian
            )
        );
        router.sweep(address(token), guardian, 1 ether);
        vm.stopPrank();
    }

    function testRecoverAssets_InsufficientNativeBalance() public {
        vm.deal(address(router), 0.5 ether);
        vm.startPrank(governor);
        vm.expectRevert(IBridgeRouter.InsufficientBalance.selector);
        router.sweep(address(0), governor, 1 ether);
        vm.stopPrank();
    }

    function testRecoverAssets_ZeroAmount_NativeAndERC20() public {
        uint256 initialRouterEth = address(router).balance;
        uint256 initialGovernorEth = governor.balance;
        uint256 initialRouterToken = token.balanceOf(address(router));
        uint256 initialGovernorToken = token.balanceOf(governor);

        vm.startPrank(governor);
        vm.expectEmit(true, true, false, true);
        emit IBridgeRouter.RouterAssetsRecovered(address(0), governor, 0);
        router.sweep(address(0), governor, 0);

        vm.expectEmit(true, true, false, true);
        emit IBridgeRouter.RouterAssetsRecovered(address(token), governor, 0);
        router.sweep(address(token), governor, 0);
        vm.stopPrank();

        assertEq(address(router).balance, initialRouterEth);
        assertEq(governor.balance, initialGovernorEth);
        assertEq(token.balanceOf(address(router)), initialRouterToken);
        assertEq(token.balanceOf(governor), initialGovernorToken);
    }

    function testRecoverAssets_Native_TransferFailed() public {
        vm.deal(address(router), 1 ether);
        RejectETH rejectContract = new RejectETH();

        vm.startPrank(governor);
        vm.expectRevert(Errors.FailedCall.selector);
        router.sweep(address(0), address(rejectContract), 1 ether);
        vm.stopPrank();
    }

    /* ------------------------------------------------------------ */
    /*                    Helper Functions for Validation Tests      */
    /* ------------------------------------------------------------ */

    function _makeFailedTransferWithArkFleet(
        bytes32 opId,
        uint256 amount,
        address recipient,
        address originator
    ) internal returns (bytes32) {
        // Configure receiver to fail
        mockReceiver.setReceiveSuccess(false);

        // Build transfer payload with ark-fleet relationship
        BridgeTypes.RelayedTransferParams memory p = BridgeTypes
            .RelayedTransferParams({
                operationId: opId,
                originator: originator,
                sourceChainId: SOURCE_CHAIN_ID,
                recipient: recipient,
                asset: address(token),
                amount: amount,
                message: ""
            });

        bytes memory payload = abi.encode(p);

        // Deliver from registered adapter
        vm.startPrank(address(mockAdapter));
        router.deliver(BridgeTypes.OperationType.TRANSFER_ASSET, payload);
        vm.stopPrank();

        // Verify the failure was recorded
        assertTrue(router.hasFailedDelivery(opId));

        return opId;
    }

    function _makeFailedMessageWithArkFleet(
        bytes32 opId,
        address recipient,
        address originator
    ) internal returns (bytes32) {
        // Configure receiver to fail
        mockReceiver.setReceiveSuccess(false);

        // Build message payload with ark-fleet relationship
        BridgeTypes.RelayedMessageParams memory p = BridgeTypes
            .RelayedMessageParams({
                operationId: opId,
                originator: originator,
                sourceChainId: SOURCE_CHAIN_ID,
                recipient: recipient,
                message: hex"deadbeef"
            });

        bytes memory payload = abi.encode(p);

        // Deliver from registered adapter
        vm.startPrank(address(mockAdapter));
        router.deliver(BridgeTypes.OperationType.MESSAGE, payload);
        vm.stopPrank();

        // Verify the failure was recorded
        assertTrue(router.hasFailedDelivery(opId));

        return opId;
    }
}
