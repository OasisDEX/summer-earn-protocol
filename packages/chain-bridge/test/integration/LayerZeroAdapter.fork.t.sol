// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {LayerZeroAdapterForkSetupTest} from "./LayerZeroAdapter.fork.setup.t.sol";
import {console} from "forge-std/Test.sol";

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

        // Test complete workflow: execute → verify
        // This demonstrates the integration between Router, and Adapter

        _executeBridgeMessage("Integration workflow test");
        _executeBridgeStateRead();

        console.log("[SUCCESS] Full workflow completed successfully");
    }

    function testCrossChainConfigManagerIntegration() public view {
        console.log("=== Testing CrossChainConfigManager Integration ===");

        // Verify layerZeroAdapter integrates properly with config manager
        assertEq(
            layerZeroAdapter.bridgeRouter(),
            address(router),
            "Bridge router should be accessible through config manager"
        );

        assertTrue(
            layerZeroAdapter.CROSS_CHAIN_REGISTRY().getAdapterPeer(
                address(layerZeroAdapter),
                DEST_CHAIN_ID
            ) != address(0),
            "Should support destination chain through config"
        );

        console.log("[SUCCESS] Config manager integration working");
    }

    function testAuthorizationAndPermissions() public {
        console.log("=== Testing Authorization ===");

        // Verify layerZeroAdapter registration
        assertTrue(
            router.isValidAdapter(address(layerZeroAdapter)),
            "Adapter should be registered with router"
        );

        // Test unauthorized direct layerZeroAdapter call fails
        bytes32 testOperationId = keccak256("unauthorized_test");
        bytes memory message = abi.encode("Unauthorized test");

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(layerZeroAdapter),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSignature("OnlyBridgeRouter()"));
        layerZeroAdapter.sendMessage{value: 1 ether}(
            testOperationId,
            BridgeTypes.ExecuteSendMessageParams({
                destinationChainId: DEST_CHAIN_ID,
                target: keeper,
                message: message,
                originator: keeper,
                refundAddress: address(keeper)
            }),
            options
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
            layerZeroAdapter.readChannelId(),
            READ_CHANNEL_ID,
            "Read channel should be configured"
        );

        // Verify chain mapping
        assertEq(
            layerZeroAdapter.chainToExternalId(DEST_CHAIN_ID),
            ARB_LZ_EID,
            "Chain to LZ EID mapping should be correct"
        );

        // Verify operation support
        assertTrue(
            layerZeroAdapter.supportsOperation(
                BridgeTypes.OperationType.MESSAGE
            ),
            "Should support MESSAGE operations"
        );
        assertTrue(
            layerZeroAdapter.supportsOperation(
                BridgeTypes.OperationType.READ_STATE
            ),
            "Should support READ_STATE operations"
        );

        console.log("[SUCCESS] LayerZero configuration verified");
    }

    // Helper function to execute a bridge message operation
    function _executeBridgeMessage(string memory messageContent) internal {
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(layerZeroAdapter),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: ""
        });

        bytes memory message = abi.encode(messageContent);
        (uint256 nativeFee, , ) = router.quote(
            DEST_CHAIN_ID,
            address(0),
            0,
            options,
            BridgeTypes.OperationType.MESSAGE
        );
        // Execute the operation (can be anyone, e.g., keeper or user) (PAYS FEE)
        vm.startPrank(keeper); // Or user
        bytes32 operationId = router.executeSendMessage{value: nativeFee}(
            BridgeTypes.ExecuteSendMessageParams({
                destinationChainId: DEST_CHAIN_ID,
                target: user,
                message: message,
                originator: keeper,
                refundAddress: keeper
            }),
            options
        );
        vm.stopPrank();
    }

    // Helper function to execute a bridge state read operation
    function _executeBridgeStateRead() internal {
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(layerZeroAdapter),
            gasLimit: 300000,
            calldataSize: 100,
            msgValue: 0,
            options: ""
        });

        bytes4 selector = bytes4(keccak256("balanceOf(address)"));
        bytes memory callData = abi.encode(user); // Reading user balance

        // Now get quote for fees FOR EXECUTION
        (uint256 nativeFee, , address specifiedAdapter) = router.quote( // Capture specified layerZeroAdapter
                DEST_CHAIN_ID,
                address(0),
                0,
                options, // Use defined options
                BridgeTypes.OperationType.READ_STATE
            );
        // Verify the specified layerZeroAdapter matches what we provided
        assertEq(specifiedAdapter, address(layerZeroAdapter));

        // Execute the operation (can be anyone) (PAYS FEE)
        vm.startPrank(keeper);
        bytes32 operationId = router.executeReadState{value: nativeFee}(
            BridgeTypes.ExecuteReadStateParams({
                destinationChainId: DEST_CHAIN_ID,
                target: address(1),
                selector: selector,
                readParams: callData,
                originator: keeper,
                refundAddress: address(keeper)
            }),
            options
        );

        // todo: expect calls to lz endpoint to be made
    }
}
