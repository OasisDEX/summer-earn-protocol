// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {BridgeRouterSetup} from "./BridgeRouter.setup.t.sol";
import {BridgeOptionsTestHelper} from "../helpers/BridgeOptionsTestHelper.sol";

contract BridgeRouterMessageTest is BridgeRouterSetup {
    using BridgeOptionsTestHelper for address;

    address public unauthorizedCaller = address(0x999);

    function testExecuteSendMessage_Success() public {
        // Setup: authorized executor sends message as originator
        bytes memory testMessage = abi.encode("Hello Cross-Chain!");

        vm.startPrank(keeper);

        // Use helper to create options - much cleaner!
        BridgeTypes.BridgeOptions memory options = address(mockAdapter)
            .defaultOptions();

        // Create message params where keeper is both executor and originator
        BridgeTypes.ExecuteSendMessageParams memory params = BridgeTypes
            .ExecuteSendMessageParams({
                destinationChainId: DEST_CHAIN_ID,
                target: user,
                message: testMessage,
                originator: keeper, // keeper is the originator
                refundAddress: keeper
            });

        // Execute the message send with sufficient fee
        bytes32 operationId = router.executeSendMessage{value: 0.101 ether}(
            params,
            options
        );

        // Verify operation was created
        assertTrue(operationId != bytes32(0));

        vm.stopPrank();
    }

    function testExecuteSendMessage_InvalidOriginator() public {
        // Setup: keeper tries to send message claiming user is the originator
        bytes memory testMessage = abi.encode("Fake message");

        vm.startPrank(keeper);

        // Use helper - much more readable
        BridgeTypes.BridgeOptions memory options = address(mockAdapter)
            .defaultOptions();

        // Create message params where keeper is executor but claims user is originator
        BridgeTypes.ExecuteSendMessageParams memory params = BridgeTypes
            .ExecuteSendMessageParams({
                destinationChainId: DEST_CHAIN_ID,
                target: user,
                message: testMessage,
                originator: user, // ❌ user is NOT msg.sender (keeper is)
                refundAddress: keeper
            });

        // This should revert with InvalidOriginator error
        vm.expectRevert(IBridgeRouter.InvalidOriginator.selector);
        router.executeSendMessage{value: 0.101 ether}(params, options);

        vm.stopPrank();
    }

    function testExecuteSendMessage_UnauthorizedExecutor() public {
        // Setup: unauthorized caller tries to execute message
        bytes memory testMessage = abi.encode("Unauthorized message");

        vm.startPrank(unauthorizedCaller);

        BridgeTypes.BridgeOptions memory options = address(mockAdapter)
            .defaultOptions();

        // Create message params
        BridgeTypes.ExecuteSendMessageParams memory params = BridgeTypes
            .ExecuteSendMessageParams({
                destinationChainId: DEST_CHAIN_ID,
                target: user,
                message: testMessage,
                originator: unauthorizedCaller,
                refundAddress: unauthorizedCaller
            });

        // This should revert due to onlyAuthorizedExecutor modifier
        vm.expectRevert();
        router.executeSendMessage{value: 0.101 ether}(params, options);

        vm.stopPrank();
    }

    function testExecuteSendMessage_ValidOriginatorButDifferentRefund() public {
        // Edge case: originator matches msg.sender but refund address is different
        bytes memory testMessage = abi.encode("Valid originator message");

        vm.startPrank(keeper);

        BridgeTypes.BridgeOptions memory options = address(mockAdapter)
            .defaultOptions();

        // Create message params where originator matches caller but refund is different
        BridgeTypes.ExecuteSendMessageParams memory params = BridgeTypes
            .ExecuteSendMessageParams({
                destinationChainId: DEST_CHAIN_ID,
                target: user,
                message: testMessage,
                originator: keeper, // ✅ matches msg.sender
                refundAddress: user // different refund address is allowed
            });

        // This should succeed - only originator needs to match msg.sender
        bytes32 operationId = router.executeSendMessage{value: 0.101 ether}(
            params,
            options
        );

        assertTrue(operationId != bytes32(0));

        vm.stopPrank();
    }

    function testExecuteSendMessage_InvalidParams() public {
        vm.startPrank(keeper);

        BridgeTypes.BridgeOptions memory options = address(mockAdapter)
            .defaultOptions();

        // Test with zero address target
        BridgeTypes.ExecuteSendMessageParams
            memory paramsZeroTarget = BridgeTypes.ExecuteSendMessageParams({
                destinationChainId: DEST_CHAIN_ID,
                target: address(0), // ❌ invalid
                message: "test",
                originator: keeper,
                refundAddress: keeper
            });

        vm.expectRevert(IBridgeRouter.InvalidParams.selector);
        router.executeSendMessage{value: 0.101 ether}(
            paramsZeroTarget,
            options
        );

        // Test with zero address originator
        BridgeTypes.ExecuteSendMessageParams
            memory paramsZeroOriginator = BridgeTypes.ExecuteSendMessageParams({
                destinationChainId: DEST_CHAIN_ID,
                target: user,
                message: "test",
                originator: address(0), // ❌ invalid
                refundAddress: keeper
            });

        vm.expectRevert(IBridgeRouter.InvalidParams.selector);
        router.executeSendMessage{value: 0.101 ether}(
            paramsZeroOriginator,
            options
        );

        // Test with empty message
        BridgeTypes.ExecuteSendMessageParams
            memory paramsEmptyMessage = BridgeTypes.ExecuteSendMessageParams({
                destinationChainId: DEST_CHAIN_ID,
                target: user,
                message: "", // ❌ invalid
                originator: keeper,
                refundAddress: keeper
            });

        vm.expectRevert(IBridgeRouter.InvalidParams.selector);
        router.executeSendMessage{value: 0.101 ether}(
            paramsEmptyMessage,
            options
        );

        vm.stopPrank();
    }

    function testExecuteSendMessage_WhenPaused() public {
        // First pause the router
        vm.prank(governor);
        router.pause();

        bytes memory testMessage = abi.encode("Paused test message");

        vm.startPrank(keeper);

        BridgeTypes.BridgeOptions memory options = address(mockAdapter)
            .defaultOptions();

        BridgeTypes.ExecuteSendMessageParams memory params = BridgeTypes
            .ExecuteSendMessageParams({
                destinationChainId: DEST_CHAIN_ID,
                target: user,
                message: testMessage,
                originator: keeper,
                refundAddress: keeper
            });

        // Should revert when paused
        vm.expectRevert(IBridgeRouter.Paused.selector);
        router.executeSendMessage{value: 0.101 ether}(params, options);

        vm.stopPrank();
    }

    function testExecuteSendMessage_NoAdapter() public {
        bytes memory testMessage = abi.encode("No adapter message");

        vm.startPrank(keeper);

        // Use helper for testing no adapter scenario
        BridgeTypes.BridgeOptions memory options = BridgeOptionsTestHelper
            .noAdapter();

        BridgeTypes.ExecuteSendMessageParams memory params = BridgeTypes
            .ExecuteSendMessageParams({
                destinationChainId: DEST_CHAIN_ID,
                target: user,
                message: testMessage,
                originator: keeper,
                refundAddress: keeper
            });

        vm.expectRevert(IBridgeRouter.UnknownAdapter.selector);
        router.executeSendMessage{value: 0.101 ether}(params, options);

        vm.stopPrank();
    }

    function testExecuteSendMessage_CustomGasLimit() public {
        bytes memory testMessage = abi.encode("Custom gas limit message");

        vm.startPrank(keeper);

        // Use helper for custom gas limit
        BridgeTypes.BridgeOptions memory options = address(mockAdapter)
            .withGasLimit(1000000);

        BridgeTypes.ExecuteSendMessageParams memory params = BridgeTypes
            .ExecuteSendMessageParams({
                destinationChainId: DEST_CHAIN_ID,
                target: user,
                message: testMessage,
                originator: keeper,
                refundAddress: keeper
            });

        bytes32 operationId = router.executeSendMessage{value: 0.101 ether}(
            params,
            options
        );

        assertTrue(operationId != bytes32(0));

        vm.stopPrank();
    }

    // Test demonstrating the security improvement from hardening item #1
    function testExecuteSendMessage_OriginatorValidationPreventsSpoof() public {
        // This test specifically validates the fix for hardening todo item #1
        // "Router: enforce originator validation on messages"

        bytes memory maliciousMessage = abi.encode("Spoofed originator attack");

        vm.startPrank(executor); // executor is authorized

        BridgeTypes.BridgeOptions memory options = address(mockAdapter)
            .defaultOptions();

        // Malicious attempt: executor tries to spoof that user is the originator
        BridgeTypes.ExecuteSendMessageParams
            memory maliciousParams = BridgeTypes.ExecuteSendMessageParams({
                destinationChainId: DEST_CHAIN_ID,
                target: address(mockReceiver),
                message: maliciousMessage,
                originator: user, // ❌ ATTACK: falsely claiming user as originator
                refundAddress: executor
            });

        // The new validation should prevent this attack
        vm.expectRevert(IBridgeRouter.InvalidOriginator.selector);
        router.executeSendMessage{value: 0.101 ether}(maliciousParams, options);

        // Legitimate usage: executor correctly claims to be the originator
        BridgeTypes.ExecuteSendMessageParams
            memory legitimateParams = BridgeTypes.ExecuteSendMessageParams({
                destinationChainId: DEST_CHAIN_ID,
                target: address(mockReceiver),
                message: maliciousMessage,
                originator: executor, // ✅ CORRECT: executor is actually msg.sender
                refundAddress: executor
            });

        // This should succeed
        bytes32 operationId = router.executeSendMessage{value: 0.101 ether}(
            legitimateParams,
            options
        );
        assertTrue(operationId != bytes32(0));

        vm.stopPrank();
    }
}
