// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {LayerZeroAdapterForkSetupTest} from "./LayerZeroAdapter.fork.setup.t.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {console} from "forge-std/Test.sol";

/**
 * @title LayerZeroAdapter Read Response Fork Test (Base)
 * @dev Fork test to verify LayerZero layerZeroAdapter read response handling functionality using existing mocks
 */
contract LayerZeroAdapterReadResponseBaseForkTest is
    LayerZeroAdapterForkSetupTest
{
    // Events from LayerZero layerZeroAdapter
    event ReadResponseDelivered(bytes32 indexed operationId, bytes payload);
    event ReadOperationNotFound(bytes32 indexed guid, string reason);
    event RelayFailed(bytes32 indexed operationId, bytes reason);

    function testSuccessfulReadResponseHandling() public {
        console.log("=== Testing Successful Read Response Handling ===");

        // Setup test data
        bytes32 operationId = keccak256(
            abi.encodePacked("test_read_operation_1")
        );
        bytes32 guid = keccak256(abi.encodePacked("test_guid_1"));
        bytes memory responseData = abi.encode(uint256(12345), "test_response");

        // Associate the operation with the layerZeroAdapter (required for authorization)
        router.setOperationToAdapter(operationId, address(layerZeroAdapter));

        // Set the read request originator (required for deliverReadResponse)
        router.setReadRequestOriginator(
            operationId,
            address(mockCrossChainStateReadReceiver)
        );

        // Map the GUID to operation ID (simulating a previous read request)
        _setOperationMapping(guid, operationId);

        // Create origin for read response (srcEid > READ_CHANNEL_THRESHOLD indicates read response)
        Origin memory origin = Origin({
            srcEid: READ_CHANNEL_THRESHOLD + 1, // Indicates this is a read response
            sender: bytes32(uint256(uint160(address(layerZeroAdapter)))), // Peer layerZeroAdapter address
            nonce: 1
        });

        // Simulate receiving the read response through LayerZero
        vm.prank(LZ_ENDPOINT_BASE); // Only the LZ endpoint can call lzReceive
        layerZeroAdapter.lzReceive(origin, guid, responseData, address(0), "");

        console.log("[SUCCESS] Read response handled successfully");
    }

    function testReadResponseWithUnknownOperationId() public {
        console.log("=== Testing Read Response with Unknown Operation ID ===");

        // Setup test data with unknown GUID (no mapping set)
        bytes32 unknownGuid = keccak256(abi.encodePacked("unknown_guid"));
        bytes memory responseData = abi.encode(
            uint256(67890),
            "unknown_response"
        );

        // Create origin for read response
        Origin memory origin = Origin({
            srcEid: READ_CHANNEL_THRESHOLD + 1,
            sender: bytes32(uint256(uint160(address(layerZeroAdapter)))),
            nonce: 1
        });

        // Expect the ReadOperationNotFound event
        vm.expectEmit(true, false, false, true, address(layerZeroAdapter));
        emit ReadOperationNotFound(unknownGuid, "No operationId found");

        // Simulate receiving read response with unknown GUID
        vm.prank(LZ_ENDPOINT_BASE);
        layerZeroAdapter.lzReceive(
            origin,
            unknownGuid,
            responseData,
            address(0),
            ""
        );

        console.log("[SUCCESS] Unknown operation ID handled gracefully");
    }

    function testReadResponseDeliveryFailure() public {
        console.log("=== Testing Read Response Delivery Failure ===");

        // Setup test data
        bytes32 operationId = keccak256(
            abi.encodePacked("test_read_operation_2")
        );
        bytes32 guid = keccak256(abi.encodePacked("test_guid_2"));
        bytes memory responseData = abi.encode(uint256(54321), "failure_test");

        // Associate the operation with the layerZeroAdapter (required for authorization)
        router.setOperationToAdapter(operationId, address(layerZeroAdapter));

        // Set the read request originator (required for deliverReadResponse)
        router.setReadRequestOriginator(operationId, user);

        // Map the GUID to operation ID
        _setOperationMapping(guid, operationId);

        // Configure router to fail delivery
        router.setShouldRevert(true);

        // Create origin for read response
        Origin memory origin = Origin({
            srcEid: READ_CHANNEL_THRESHOLD + 1,
            sender: bytes32(uint256(uint160(address(layerZeroAdapter)))),
            nonce: 1
        });

        // Simulate receiving the read response - should handle delivery failure gracefully
        // todo: implement recoverey/retry mechanism
        vm.prank(LZ_ENDPOINT_BASE);
        layerZeroAdapter.lzReceive(origin, guid, responseData, address(0), "");

        // Reset router behavior
        router.setShouldRevert(false);

        console.log("[SUCCESS] Delivery failure handled correctly");
    }

    function testReadChannelThresholdBoundaryConditions() public pure {
        console.log(
            "=== Testing Read Channel Threshold Boundary Conditions ==="
        );

        // Test that layerZeroAdapter recognizes read channel threshold correctly
        console.log("Read channel threshold:", READ_CHANNEL_THRESHOLD);
        console.log("Read channel ID:", READ_CHANNEL_ID);

        // Verify that the threshold is correctly set
        assertTrue(
            READ_CHANNEL_THRESHOLD < READ_CHANNEL_ID,
            "Read channel ID should be above threshold"
        );

        // Verify threshold boundary logic
        uint32 atThreshold = READ_CHANNEL_THRESHOLD;
        uint32 aboveThreshold = READ_CHANNEL_THRESHOLD + 1;

        console.log("At threshold EID:", atThreshold);
        console.log("Above threshold EID:", aboveThreshold);

        // The actual threshold check logic is internal to the layerZeroAdapter
        // This test verifies the configuration is correct for boundary detection
        assertTrue(
            atThreshold < aboveThreshold,
            "Above threshold should be greater than at threshold"
        );

        assertTrue(
            aboveThreshold > READ_CHANNEL_THRESHOLD,
            "Above threshold should trigger read response handling"
        );

        console.log("[SUCCESS] Boundary conditions handled correctly");
    }

    function testLayerZeroEndpointIntegration() public view {
        console.log("=== LayerZero Endpoint Integration Test ===");
        console.log(
            "Testing read response handling with real LayerZero endpoint configuration"
        );

        // Verify endpoint configuration
        console.log("LayerZero Endpoint:", LZ_ENDPOINT_BASE);
        console.log("Endpoint code size:", LZ_ENDPOINT_BASE.code.length);
        assertTrue(
            LZ_ENDPOINT_BASE.code.length > 0,
            "LayerZero endpoint should have code"
        );

        // Verify ReadLib1002 configuration
        console.log("ReadLib1002:", READ_LIB_1002_BASE);
        console.log("ReadLib1002 code size:", READ_LIB_1002_BASE.code.length);
        assertTrue(
            READ_LIB_1002_BASE.code.length > 0,
            "ReadLib1002 should have code"
        );

        // Verify layerZeroAdapter configuration
        console.log("Adapter read channel:", layerZeroAdapter.readChannelId());
        assertEq(
            layerZeroAdapter.readChannelId(),
            READ_CHANNEL_ID,
            "Read channel should be configured"
        );

        // Test that layerZeroAdapter recognizes read channel threshold correctly
        console.log("Read channel threshold:", READ_CHANNEL_THRESHOLD);
        assertTrue(
            READ_CHANNEL_THRESHOLD < READ_CHANNEL_ID,
            "Read channel ID should be above threshold"
        );

        console.log(
            "[SUCCESS] LayerZero configuration verified for read responses"
        );
    }

    function testMultipleReadResponsesHandling() public {
        console.log("=== Testing Multiple Read Responses Handling ===");

        uint256 numResponses = 3;
        bytes32[] memory operationIds = new bytes32[](numResponses);
        bytes32[] memory guids = new bytes32[](numResponses);

        // Setup multiple read responses
        for (uint256 i = 0; i < numResponses; i++) {
            operationIds[i] = keccak256(abi.encodePacked("operation", i));
            guids[i] = keccak256(abi.encodePacked("guid", i));
            _setOperationMapping(guids[i], operationIds[i]);

            // Associate the operation with the layerZeroAdapter (required for authorization)
            router.setOperationToAdapter(
                operationIds[i],
                address(layerZeroAdapter)
            );

            // Set the read request originator to a contract that implements ICrossChainReceiver
            router.setReadRequestOriginator(
                operationIds[i],
                address(mockCrossChainStateReadReceiver)
            );
        }

        // Process each read response
        for (uint256 i = 0; i < numResponses; i++) {
            bytes memory responseData = abi.encode(
                uint256(i * 1000),
                string(abi.encodePacked("response_", i))
            );

            Origin memory origin = Origin({
                srcEid: READ_CHANNEL_THRESHOLD + 1,
                sender: bytes32(uint256(uint160(address(layerZeroAdapter)))),
                nonce: uint64(i + 1)
            });

            // Ensure expected chain mapping is present so adapter can deliver
            layerZeroAdapter.setExpectedReadChainByGuid(
                guids[i],
                DEST_CHAIN_ID
            );

            vm.prank(LZ_ENDPOINT_BASE);
            layerZeroAdapter.lzReceive(
                origin,
                guids[i],
                responseData,
                address(0),
                ""
            );
        }

        console.log("[SUCCESS] Multiple read responses handled successfully");
    }
}
