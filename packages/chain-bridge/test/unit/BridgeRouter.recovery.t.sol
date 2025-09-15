// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeRouter} from "../../src/router/BridgeRouter.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {BridgeRouterSetup} from "./BridgeRouter.setup.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAccessControlErrors} from "@summerfi/access-contracts/interfaces/IAccessControlErrors.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockCrossChainReceiver} from "../mocks/MockCrossChainReceiver.sol";

// Contract that rejects ETH transfers
contract RejectETH {
    receive() external payable {
        revert("Transfer rejected");
    }

    function testSkip() public {}
}

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

    function _makeFailedTransfer(
        bytes32 opId,
        uint256 amount
    ) internal returns (bytes32) {
        // Configure receiver to fail
        mockReceiver.setReceiveSuccess(false);

        // Build transfer payload
        BridgeTypes.RelayedTransferParams memory p = BridgeTypes
            .RelayedTransferParams({
                operationId: opId,
                originator: user,
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

        // Recorded as failed
        (bytes32[] memory ids, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids.length, 1);
        assertEq(ids[0], opId);

        return opId;
    }

    function testRecordFailureAndRetry_Succeeds() public {
        bytes32 opId = keccak256("op1");
        uint256 amount = 10 ether;

        _makeFailedTransfer(opId, amount);

        // Now allow receiver to succeed
        mockReceiver.setReceiveSuccess(true);

        // Retry without overrides
        vm.prank(governor);
        router.retryFailedDelivery(opId, "");

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
    /*                    Payload Validation Tests                   */
    /* ------------------------------------------------------------ */

    function testRetryWithValidArkFleetRelationship_Succeeds() public {
        // Setup ark-fleet relationship with unique addresses
        address arkProxy = address(0x1001);
        address fleetProxy = address(0x1002);

        vm.startPrank(governor);
        // Only register if not already registered
        try
            registry.registerRelationship(
                address(mockReceiver),
                fleetProxy,
                CURRENT_CHAIN_ID,
                SOURCE_CHAIN_ID,
                registry.ARK_FLEET_RELATIONSHIP()
            )
        {} catch {}

        // Register reverse relationship for validation
        try
            registry.registerRelationship(
                fleetProxy,
                address(mockReceiver),
                SOURCE_CHAIN_ID,
                CURRENT_CHAIN_ID,
                registry.ARK_FLEET_RELATIONSHIP()
            )
        {} catch {}
        vm.stopPrank();

        bytes32 opId = keccak256("valid-ark-fleet");
        uint256 amount = 10 ether;

        // Create failed transfer with valid ark-fleet relationship
        _makeFailedTransferWithArkFleet(
            opId,
            amount,
            address(mockReceiver),
            fleetProxy
        );

        // Allow receiver to succeed
        mockReceiver.setReceiveSuccess(true);

        // Retry should succeed
        vm.prank(governor);
        router.retryFailedDelivery(opId, "");

        // Verify success
        (bytes32[] memory ids, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids.length, 0);
        assertEq(token.balanceOf(address(mockReceiver)), amount);
    }

    function testRetryWithInvalidArkFleetRelationship_Reverts() public {
        // Setup ark-fleet relationship with unique addresses
        address arkProxy = address(0x1001);
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
                registry.ARK_FLEET_RELATIONSHIP()
            )
        {} catch {}

        // Register reverse relationship for validation
        try
            registry.registerRelationship(
                fleetProxy,
                address(mockReceiver),
                SOURCE_CHAIN_ID,
                CURRENT_CHAIN_ID,
                registry.ARK_FLEET_RELATIONSHIP()
            )
        {} catch {}
        vm.stopPrank();

        bytes32 opId = keccak256("invalid-ark-fleet");
        uint256 amount = 10 ether;

        // Create failed transfer with invalid ark-fleet relationship
        _makeFailedTransferWithArkFleet(
            opId,
            amount,
            address(mockReceiver),
            wrongFleet
        );

        // Allow receiver to succeed
        mockReceiver.setReceiveSuccess(true);

        // Retry should revert with InvalidRecipient
        vm.prank(governor);
        vm.expectRevert(IBridgeRouter.InvalidRecipient.selector);
        router.retryFailedDelivery(opId, "");
    }

    function testRetryWithNonArkRecipient_Succeeds() public {
        bytes32 opId = keccak256("non-ark-recipient");
        uint256 amount = 10 ether;

        // Create failed transfer with non-ark recipient (should be allowed)
        _makeFailedTransfer(opId, amount);

        // Allow receiver to succeed
        mockReceiver.setReceiveSuccess(true);

        // Retry should succeed (non-ark recipients are allowed)
        vm.prank(governor);
        router.retryFailedDelivery(opId, "");

        // Verify success
        (bytes32[] memory ids, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids.length, 0);
        assertEq(token.balanceOf(address(mockReceiver)), amount);
    }

    function testRetryWithMessagePayload_ValidArkFleet_Succeeds() public {
        // Setup ark-fleet relationship with unique addresses
        address arkProxy = address(0x1001);
        address fleetProxy = address(0x1002);

        vm.startPrank(governor);
        // Register mockReceiver as ark proxy - only if not already registered
        try
            registry.registerRelationship(
                address(mockReceiver),
                fleetProxy,
                CURRENT_CHAIN_ID,
                SOURCE_CHAIN_ID,
                registry.ARK_FLEET_RELATIONSHIP()
            )
        {} catch {}

        try
            registry.registerRelationship(
                fleetProxy,
                address(mockReceiver),
                SOURCE_CHAIN_ID,
                CURRENT_CHAIN_ID,
                registry.ARK_FLEET_RELATIONSHIP()
            )
        {} catch {}
        vm.stopPrank();

        bytes32 opId = keccak256("valid-message-ark-fleet");

        // Create failed message with valid ark-fleet relationship
        _makeFailedMessageWithArkFleet(opId, address(mockReceiver), fleetProxy);

        // Allow receiver to succeed
        mockReceiver.setReceiveSuccess(true);

        // Retry should succeed
        vm.prank(governor);
        router.retryFailedDelivery(opId, "");

        // Verify success
        (bytes32[] memory ids, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids.length, 0);
    }

    function testRetryWithMessagePayload_InvalidArkFleet_Reverts() public {
        // Setup ark-fleet relationship with unique addresses
        address arkProxy = address(0x1001);
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
                registry.ARK_FLEET_RELATIONSHIP()
            )
        {} catch {}

        try
            registry.registerRelationship(
                fleetProxy,
                address(mockReceiver),
                SOURCE_CHAIN_ID,
                CURRENT_CHAIN_ID,
                registry.ARK_FLEET_RELATIONSHIP()
            )
        {} catch {}
        vm.stopPrank();

        bytes32 opId = keccak256("invalid-message-ark-fleet");

        // Create failed message with invalid ark-fleet relationship
        _makeFailedMessageWithArkFleet(opId, address(mockReceiver), wrongFleet);

        // Allow receiver to succeed
        mockReceiver.setReceiveSuccess(true);

        // Retry should revert with InvalidRecipient
        vm.prank(governor);
        vm.expectRevert(IBridgeRouter.InvalidRecipient.selector);
        router.retryFailedDelivery(opId, "");
    }

    // NOTE: Originator override tests removed as originator overrides are no longer supported
    // function testRetryWithOverridePayload_InvalidArkFleet_Reverts() - REMOVED

    function testRetryWithOverridePayload_ValidArkFleet_Succeeds() public {
        // Setup ark-fleet relationship with unique addresses
        address arkProxy = address(0x1001);
        address fleetProxy = address(0x1002);

        vm.startPrank(governor);
        // Register mockReceiver as ark proxy - only if not already registered
        try
            registry.registerRelationship(
                address(mockReceiver),
                fleetProxy,
                CURRENT_CHAIN_ID,
                SOURCE_CHAIN_ID,
                registry.ARK_FLEET_RELATIONSHIP()
            )
        {} catch {}

        try
            registry.registerRelationship(
                fleetProxy,
                address(mockReceiver),
                SOURCE_CHAIN_ID,
                CURRENT_CHAIN_ID,
                registry.ARK_FLEET_RELATIONSHIP()
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
        bytes memory overrideData = abi.encode(
            BridgeRouter.RetryOverrideParams({
                recipient: address(0), // keep original recipient
                asset: address(0) // keep original asset
            })
        );

        // Allow receiver to succeed
        mockReceiver.setReceiveSuccess(true);

        // Retry should succeed
        vm.prank(governor);
        router.retryFailedDelivery(opId, overrideData);

        // Verify success with original amount
        (bytes32[] memory ids, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids.length, 0);
        assertEq(token.balanceOf(address(mockReceiver)), amount);
    }

    function testRetryWithAssetOverride_Succeeds() public {
        bytes32 opId = keccak256("asset-override-test");
        uint256 amount = 5 ether;

        // Create failed transfer with original asset
        _makeFailedTransfer(opId, amount);

        // Deploy a different token to simulate cross-chain asset mapping
        ERC20Mock newToken = new ERC20Mock();
        newToken.mint(address(router), amount);

        // Allow receiver to succeed
        mockReceiver.setReceiveSuccess(true);

        // Retry with asset override
        bytes memory overrideData = abi.encode(
            BridgeRouter.RetryOverrideParams({
                recipient: address(0), // keep original recipient
                asset: address(newToken) // override with new asset
            })
        );

        vm.prank(governor);
        router.retryFailedDelivery(opId, overrideData);

        // Verify success with new asset
        (bytes32[] memory ids, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids.length, 0);
        assertEq(newToken.balanceOf(address(mockReceiver)), amount);
        // Original token should not have been transferred
        assertEq(token.balanceOf(address(mockReceiver)), 0);
    }

    function testRetryWithAssetOverride_InsufficientBalance_Reverts() public {
        bytes32 opId = keccak256("asset-override-insufficient");
        uint256 amount = 5 ether;

        // Create failed transfer
        _makeFailedTransfer(opId, amount);

        // Deploy a different token but don't mint any to router
        ERC20Mock newToken = new ERC20Mock();
        // No minting - router has 0 balance

        // Allow receiver to succeed
        mockReceiver.setReceiveSuccess(true);

        // Retry with asset override
        bytes memory overrideData = abi.encode(
            BridgeRouter.RetryOverrideParams({
                recipient: address(0), // keep original recipient
                asset: address(newToken) // override with new asset
            })
        );

        vm.prank(governor);
        vm.expectRevert(IBridgeRouter.InsufficientBalance.selector);
        router.retryFailedDelivery(opId, overrideData);
    }

    function testRetryWithBothOverrides_Succeeds() public {
        bytes32 opId = keccak256("both-overrides-test");
        uint256 amount = 3 ether;

        // Create failed transfer
        _makeFailedTransfer(opId, amount);

        // Deploy new token and new receiver
        ERC20Mock newToken = new ERC20Mock();
        newToken.mint(address(router), amount);
        MockCrossChainReceiver newReceiver = new MockCrossChainReceiver();
        newReceiver.setReceiveSuccess(true);

        // Retry with both overrides
        bytes memory overrideData = abi.encode(
            BridgeRouter.RetryOverrideParams({
                recipient: address(newReceiver), // override recipient
                asset: address(newToken) // override asset
            })
        );

        vm.prank(governor);
        router.retryFailedDelivery(opId, overrideData);

        // Verify success with new asset and new receiver
        (bytes32[] memory ids, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids.length, 0);
        assertEq(newToken.balanceOf(address(newReceiver)), amount);
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
        vm.expectRevert(IBridgeRouter.TransferFailed.selector);
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
        vm.expectRevert(IBridgeRouter.TransferFailed.selector);
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
        vm.expectRevert(IBridgeRouter.TransferFailed.selector);
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

        // Recorded as failed
        (bytes32[] memory ids, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids.length, 1);
        assertEq(ids[0], opId);

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

        // Recorded as failed
        (bytes32[] memory ids, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids.length, 1);
        assertEq(ids[0], opId);

        return opId;
    }
}
