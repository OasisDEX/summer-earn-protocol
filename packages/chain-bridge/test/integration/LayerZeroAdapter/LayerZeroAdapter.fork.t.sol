// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../../../src/libraries/BridgeTypes.sol";
import {LayerZeroAdapterForkSetupTest} from "./LayerZeroAdapter.fork.setup.t.sol";
import {LayerZeroAdapterTestHelper} from "../../helpers/LayerZeroAdapterTestHelper.sol";
import {console} from "forge-std/Test.sol";

/**
 * @title LayerZero Integration Fork Test
 * @dev Core integration tests focusing on cross-functional workflows and component integration
 */
contract LayerZeroIntegrationForkTest is LayerZeroAdapterForkSetupTest {
    function setUp() public override {
        super.setUp();
    }

    function testFullBridgeWorkflow() public {
        console.log("=== Testing Full Bridge Workflow ===");

        // Test complete workflow: execute → verify
        // This demonstrates the integration between Router, and Adapter
        _executeBridgeMessage("Integration workflow test");

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
            options: "",
            payInProtocolToken: false,
                feeTokenAmount: 0
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

        console.log("[SUCCESS] LayerZero configuration verified");
    }

    // Helper function to execute a bridge message operation
    function _executeBridgeMessage(string memory messageContent) internal {
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(layerZeroAdapter),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: "",
            payInProtocolToken: false,
                feeTokenAmount: 0
        });

        bytes memory message = abi.encode(messageContent);
        (uint256 nativeFee, , ) = router.quoteSendMessage(
            BridgeTypes.ExecuteSendMessageParams({
                destinationChainId: DEST_CHAIN_ID,
                target: address(0x1234), // Target contract
                message: message,
                originator: keeper,
                refundAddress: keeper
            }),
            options
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
}
