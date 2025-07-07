// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {console} from "forge-std/Test.sol";
import {LayerZeroAdapterForkSetupTest} from "./LayerZeroAdapter.fork.setup.t.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";

/**
 * @title LayerZero Message Send Fork Test
 * @dev Core tests for LayerZero adapter message sending functionality
 */
contract LayerZeroAdapterMessageSendForkTest is LayerZeroAdapterForkSetupTest {
    function setUp() public override {
        super.setUp();
    }

    function testAdapterConfiguration() public view {
        _verifyAdapterConfiguration();
    }

    function testSendMessageViaQueue() public {
        console.log("=== Testing Core Message Send Via Queue ===");

        // Define standard options
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapter),
            adapterParams: adapterParams
        });

        // Get quote for fees
        (uint256 nativeFee, , ) = router.quote(
            DEST_CHAIN_ID,
            address(0),
            0,
            options,
            BridgeTypes.OperationType.MESSAGE
        );

        bytes memory message = abi.encode("Hello Cross-Chain!");

        // 1. Queue the operation
        vm.startPrank(user);
        bytes32 queueId = bridgeQueue.queueSendMessage(
            DEST_CHAIN_ID,
            keeper,
            message
        );
        vm.stopPrank();

        // Verify queued status
        assertEq(
            uint256(bridgeQueue.queueIdToStatus(queueId)),
            uint256(BridgeTypes.OperationStatus.QUEUED)
        );

        // 2. Execute the operation
        vm.startPrank(keeper);

        // Mock router behavior
        vm.mockCall(
            address(router),
            abi.encodeWithSelector(
                IBridgeRouter.quote.selector,
                DEST_CHAIN_ID,
                address(0),
                0,
                options,
                BridgeTypes.OperationType.MESSAGE
            ),
            abi.encode(nativeFee, uint256(0), address(adapter))
        );

        bytes32 expectedOperationId = keccak256(
            abi.encodePacked("mockSendMsgOpId", queueId)
        );
        vm.mockCall(
            address(router),
            nativeFee,
            abi.encodeWithSelector(IBridgeRouter.executeSendMessage.selector),
            abi.encode(expectedOperationId)
        );

        bytes32 operationId = bridgeQueue.executeQueuedOperation{
            value: nativeFee
        }(queueId, options);
        vm.stopPrank();

        // Verify final state
        assertEq(
            uint256(bridgeQueue.queueIdToStatus(queueId)),
            uint256(BridgeTypes.OperationStatus.SENT)
        );
        assertEq(bridgeQueue.operationIdToQueueId(operationId), queueId);

        console.log("[SUCCESS] Message sent via queue successfully");
    }

    function testSendMessageDirectViaAdapter() public {
        console.log("=== Testing Direct Adapter Call ===");

        bytes32 operationId = keccak256("test_direct_message");
        bytes memory message = abi.encode("Direct message test");

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                msgValue: 0,
                calldataSize: 0,
                options: ""
            });

        (uint256 nativeFee, ) = adapter.estimateFee(
            DEST_CHAIN_ID,
            address(0),
            0,
            adapterParams,
            BridgeTypes.OperationType.MESSAGE
        );

        // Set up operation mapping
        router.setOperationToAdapter(operationId, address(adapter));

        // Call adapter through router context (authorized)
        vm.startPrank(address(router));
        adapter.sendMessage{value: nativeFee}(
            operationId,
            DEST_CHAIN_ID,
            keeper, // recipient
            message,
            keeper, // refund keeper
            adapterParams
        );
        vm.stopPrank();

        console.log("[SUCCESS] Direct adapter call completed");
    }

    function testUnauthorizedAdapterCall() public {
        console.log("=== Testing Unauthorized Call Protection ===");

        bytes32 operationId = keccak256("unauthorized_test");
        bytes memory message = abi.encode("Unauthorized test");

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                msgValue: 0,
                calldataSize: 0,
                options: ""
            });

        // Direct call should fail (not from router)
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        adapter.sendMessage{value: 1 ether}(
            operationId,
            DEST_CHAIN_ID,
            keeper,
            message,
            keeper,
            adapterParams
        );
        vm.stopPrank();

        console.log("[SUCCESS] Authorization properly enforced");
    }

    function testEstimateMessageFee() public view {
        console.log("=== Testing Fee Estimation ===");

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                msgValue: 0,
                calldataSize: 0,
                options: ""
            });

        (uint256 nativeFee, uint256 tokenFee) = adapter.estimateFee(
            DEST_CHAIN_ID,
            address(0),
            0,
            adapterParams,
            BridgeTypes.OperationType.MESSAGE
        );

        assertGt(nativeFee, 0, "Native fee should be greater than 0");
        assertEq(tokenFee, 0, "Token fee should be 0 for LayerZero");

        console.log("Estimated fee:", nativeFee);
        console.log("[SUCCESS] Fee estimation working correctly");
    }
}
