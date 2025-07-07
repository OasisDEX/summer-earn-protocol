// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {LayerZeroAdapterForkSetupTest} from "./LayerZeroAdapter.fork.setup.t.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";

/**
 * @title LayerZero Integration Fork Test
 * @dev Core integration tests focusing on cross-functional workflows and component integration
 */
contract LayerZeroIntegrationForkTest is LayerZeroAdapterForkSetupTest {
    function setUp() public override {
        super.setUp();
    }

    function testAdapterConfiguration() public view {
        console.log("=== Testing Adapter Configuration ===");
        _verifyAdapterConfiguration();
        console.log("[SUCCESS] Adapter properly configured");
    }

    function testFullBridgeWorkflow() public {
        console.log("=== Testing Full Bridge Workflow ===");

        // Test complete workflow: queue → execute → verify
        // This demonstrates the integration between BridgeQueue, Router, and Adapter

        _executeBridgeMessage("Integration workflow test");
        _executeBridgeStateRead();

        console.log("[SUCCESS] Full workflow completed successfully");
    }

    function testConcurrentOperationsQueuing() public {
        console.log("=== Testing Concurrent Operations ===");

        // Test multiple operations can be queued concurrently
        bytes32[] memory queueIds = new bytes32[](3);

        vm.startPrank(user);

        // Queue different types of operations
        queueIds[0] = bridgeQueue.queueSendMessage(
            DEST_CHAIN_ID,
            keeper,
            abi.encode("Message 1")
        );

        queueIds[1] = bridgeQueue.queueReadState(
            DEST_CHAIN_ID,
            keeper,
            bytes4(keccak256("balanceOf(address)")),
            abi.encode(user)
        );

        queueIds[2] = bridgeQueue.queueSendMessage(
            DEST_CHAIN_ID,
            keeper,
            abi.encode("Message 2")
        );

        vm.stopPrank();

        // Verify all are queued
        for (uint i = 0; i < queueIds.length; i++) {
            assertEq(
                uint256(bridgeQueue.queueIdToStatus(queueIds[i])),
                uint256(BridgeTypes.OperationStatus.QUEUED)
            );
        }

        assertEq(bridgeQueue.getPendingQueueCount(), 3);

        console.log("[SUCCESS] Multiple operations queued successfully");
    }

    function testCrossChainConfigManagerIntegration() public view {
        console.log("=== Testing CrossChainConfigManager Integration ===");

        // Verify adapter integrates properly with config manager
        assertEq(
            adapter.bridgeRouter(),
            address(router),
            "Bridge router should be accessible through config manager"
        );
        assertEq(
            adapter.bridgeQueue(),
            address(bridgeQueue),
            "Bridge queue should be accessible through config manager"
        );

        assertTrue(
            adapter.supportsChain(DEST_CHAIN_ID),
            "Should support destination chain through config"
        );

        console.log("[SUCCESS] Config manager integration working");
    }

    function testAuthorizationAndPermissions() public {
        console.log("=== Testing Authorization ===");

        // Verify adapter registration
        assertTrue(
            router.isValidAdapter(address(adapter)),
            "Adapter should be registered with router"
        );

        // Test unauthorized direct adapter call fails
        bytes32 testOperationId = keccak256("unauthorized_test");
        bytes memory message = abi.encode("Unauthorized test");

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                msgValue: 0,
                calldataSize: 0,
                options: ""
            });

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        adapter.sendMessage{value: 1 ether}(
            testOperationId,
            DEST_CHAIN_ID,
            keeper,
            message,
            keeper,
            adapterParams
        );
        vm.stopPrank();

        console.log("[SUCCESS] Authorization working correctly");
    }

    function testLayerZeroConfiguration() public view {
        console.log("=== Testing LayerZero Configuration ===");

        // Verify LayerZero endpoint is configured
        assertTrue(
            LZ_ENDPOINT_BASE.code.length > 0,
            "LayerZero endpoint should have code"
        );

        // Verify read channel configuration
        assertEq(
            adapter.readChannelId(),
            READ_CHANNEL_ID,
            "Read channel should be configured"
        );

        // Verify chain mapping
        assertEq(
            adapter.chainToLzEid(DEST_CHAIN_ID),
            ARB_LZ_EID,
            "Chain to LZ EID mapping should be correct"
        );

        // Verify operation support
        assertTrue(
            adapter.supportsOperation(BridgeTypes.OperationType.MESSAGE),
            "Should support MESSAGE operations"
        );
        assertTrue(
            adapter.supportsOperation(BridgeTypes.OperationType.READ_STATE),
            "Should support READ_STATE operations"
        );

        console.log("[SUCCESS] LayerZero configuration verified");
    }

    // Helper function to execute a bridge message operation
    function _executeBridgeMessage(string memory messageContent) internal {
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

        bytes memory message = abi.encode(messageContent);

        vm.startPrank(user);
        bytes32 queueId = bridgeQueue.queueSendMessage(
            DEST_CHAIN_ID,
            keeper,
            message
        );
        vm.stopPrank();

        (uint256 nativeFee, , ) = router.quote(
            DEST_CHAIN_ID,
            address(0),
            0,
            options,
            BridgeTypes.OperationType.MESSAGE
        );

        // Mock router calls
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

        vm.startPrank(keeper);
        bridgeQueue.executeQueuedOperation{value: nativeFee}(queueId, options);
        vm.stopPrank();
    }

    // Helper function to execute a bridge state read operation
    function _executeBridgeStateRead() internal {
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 300000,
                calldataSize: 100,
                msgValue: 0,
                options: ""
            });
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapter),
            adapterParams: adapterParams
        });

        vm.startPrank(user);
        bytes32 queueId = bridgeQueue.queueReadState(
            DEST_CHAIN_ID,
            keeper,
            bytes4(keccak256("balanceOf(address)")),
            abi.encode(user)
        );
        vm.stopPrank();

        (uint256 nativeFee, , ) = router.quote(
            DEST_CHAIN_ID,
            address(0),
            0,
            options,
            BridgeTypes.OperationType.READ_STATE
        );

        // Mock router calls
        vm.mockCall(
            address(router),
            abi.encodeWithSelector(
                IBridgeRouter.quote.selector,
                DEST_CHAIN_ID,
                address(0),
                0,
                options,
                BridgeTypes.OperationType.READ_STATE
            ),
            abi.encode(nativeFee, uint256(0), address(adapter))
        );

        bytes32 expectedOperationId = keccak256(
            abi.encodePacked("mockReadStateOpId", queueId)
        );
        vm.mockCall(
            address(router),
            nativeFee,
            abi.encodeWithSelector(IBridgeRouter.executeReadState.selector),
            abi.encode(expectedOperationId)
        );

        vm.startPrank(keeper);
        bridgeQueue.executeQueuedOperation{value: nativeFee}(queueId, options);
        vm.stopPrank();
    }
}
