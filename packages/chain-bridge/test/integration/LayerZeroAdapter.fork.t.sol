// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {IMessageLibManager, SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {ReadLibConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/readlib/ReadLibBase.sol";
import {LayerZeroAdapterForkSetupTest} from "./LayerZeroAdapter.fork.setup.t.sol";
import {LayerZeroAdapterTestHelper} from "../helpers/LayerZeroAdapterTestHelper.sol";
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
        vm.startPrank(governor);
        layerZeroAdapter.setChainReadSupport(DEST_CHAIN_ID, true);
        vm.stopPrank();
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

    function testExpectEndpointCallsOnConfigureReadLibrariesAndDVNs() public {
        // Deploy a fresh, unconfigured adapter for this test
        LayerZeroAdapterTestHelper freshAdapter = _deployUnconfiguredAdapter();

        vm.startPrank(governor);

        // First activate the read channel for the fresh adapter
        freshAdapter.activateReadChannel(READ_CHANNEL_ID);

        // Expect setSendLibrary and setReceiveLibrary during configureReadLibraries
        vm.expectCall(
            LZ_ENDPOINT_BASE,
            abi.encodeWithSelector(
                IMessageLibManager.setSendLibrary.selector,
                address(freshAdapter),
                READ_CHANNEL_ID,
                READ_LIB_1002_BASE
            )
        );

        vm.expectCall(
            LZ_ENDPOINT_BASE,
            abi.encodeWithSelector(
                IMessageLibManager.setReceiveLibrary.selector,
                address(freshAdapter),
                READ_CHANNEL_ID,
                READ_LIB_1002_BASE,
                0
            )
        );

        freshAdapter.configureReadLibraries(READ_LIB_1002_BASE);

        // Prepare DVN config to match adapter encoding
        address[] memory readDVNs = new address[](1);
        readDVNs[0] = READ_DVN_BASE;
        ReadLibConfig memory cfg = ReadLibConfig({
            executor: EXECUTOR_BASE,
            requiredDVNCount: uint8(readDVNs.length),
            optionalDVNCount: 0,
            optionalDVNThreshold: 0,
            requiredDVNs: readDVNs,
            optionalDVNs: new address[](0)
        });
        bytes memory encodedConfig = abi.encode(cfg);
        SetConfigParam[] memory params = new SetConfigParam[](1);
        params[0] = SetConfigParam({
            eid: READ_CHANNEL_ID,
            configType: 1,
            config: encodedConfig
        });

        // Expect setConfig during configureReadDVNs
        vm.expectCall(
            LZ_ENDPOINT_BASE,
            abi.encodeWithSelector(
                IMessageLibManager.setConfig.selector,
                address(freshAdapter),
                READ_LIB_1002_BASE,
                params
            )
        );

        freshAdapter.configureReadDVNs(
            READ_LIB_1002_BASE,
            readDVNs,
            EXECUTOR_BASE,
            1
        );

        vm.stopPrank();
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
        (uint256 nativeFee, , address specifiedAdapter) = router.quoteReadState(
            BridgeTypes.ExecuteReadStateParams({
                destinationChainId: DEST_CHAIN_ID,
                target: address(0x1234), // Target contract
                selector: selector,
                readParams: callData,
                originator: keeper,
                refundAddress: keeper
            }),
            options
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
    }
}
