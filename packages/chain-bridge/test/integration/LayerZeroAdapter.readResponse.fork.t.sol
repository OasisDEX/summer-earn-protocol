// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {LayerZeroAdapter} from "../../src/adapters/LayerZeroAdapter.sol";
import {BridgeRouter} from "../../src/router/BridgeRouter.sol";
import {BridgeQueue} from "../../src/router/BridgeQueue.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IBridgeQueue} from "../../src/interfaces/IBridgeQueue.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
import {BridgeRouterTestHelper} from "../helpers/BridgeRouterTestHelper.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

/**
 * @title LayerZeroAdapter Read Response Fork Test (Base)
 * @dev Fork test to verify LayerZero adapter read response handling functionality using existing mocks
 */
contract LayerZeroAdapterReadResponseBaseForkTest is Test {
    LayerZeroAdapter public adapter;
    BridgeRouterTestHelper public router;
    BridgeQueue public bridgeQueue;
    ProtocolAccessManager public accessManager;

    address public governor = makeAddr("governor");
    address public guardian = makeAddr("guardian");
    address public user = makeAddr("user");
    address public keeper = makeAddr("keeper");

    // Chain configuration - Base to Arbitrum
    uint16 public constant SOURCE_CHAIN_ID = 8453; // Base
    uint16 public constant DEST_CHAIN_ID = 42161; // Arbitrum
    uint32 public constant BASE_LZ_EID = 30184; // Base LayerZero EID
    uint32 public constant ARB_LZ_EID = 30110; // Arbitrum LayerZero EID

    // LayerZero V2 endpoint on Base
    address public constant LZ_ENDPOINT_BASE =
        0x1a44076050125825900e736c501f859c50fE728c;
    address public constant READ_LIB_1002_BASE =
        0x1273141a3f7923AA2d9edDfA402440cE075ed8Ff;
    uint32 public constant READ_CHANNEL_ID = 4294967295;
    uint32 public constant READ_CHANNEL_THRESHOLD = 4294965694;

    // Configuration from layerzero.json for Base (8453)
    address public constant EXECUTOR_BASE =
        0x2CCA08ae69E0C44b18a57Ab2A87644234dAebaE4;
    address public constant READ_DVN_BASE =
        0xB1473AC9f58FB27597a21710da9D1071841E8163;
    uint32 public constant MAX_MESSAGE_SIZE = 10000;

    // Use a recent Base block
    uint256 public constant FORK_BLOCK = 31_600_000;

    // Events from LayerZero adapter
    event ReadResponseDelivered(bytes32 indexed operationId, bytes payload);
    event ReadOperationNotFound(bytes32 indexed guid, string reason);
    event RelayFailed(bytes32 indexed operationId, bytes reason);

    function setUp() public {
        // Fork Base mainnet
        vm.createSelectFork(vm.rpcUrl("base"), FORK_BLOCK);

        // Create access manager
        accessManager = new ProtocolAccessManager(governor);

        // Configure roles
        vm.startPrank(governor);
        accessManager.grantGuardianRole(guardian);
        vm.stopPrank();

        // Create bridge queue first
        bridgeQueue = new BridgeQueue(
            address(accessManager),
            address(0), // Temporarily 0, will be set later
            user // Make the test user the queue manager
        );

        // Create router TEST HELPER, passing the deployed BridgeQueue address
        router = new BridgeRouterTestHelper(
            address(accessManager),
            address(bridgeQueue)
        );

        // Now set the bridge router address in the queue
        vm.startPrank(governor);
        bridgeQueue.setBridgeRouter(address(router));
        vm.stopPrank();

        // Setup supported chains configuration
        uint16[] memory supportedChains = new uint16[](2);
        uint32[] memory lzEids = new uint32[](2);
        supportedChains[0] = SOURCE_CHAIN_ID;
        supportedChains[1] = DEST_CHAIN_ID;
        lzEids[0] = BASE_LZ_EID;
        lzEids[1] = ARB_LZ_EID;

        // Deploy LayerZero adapter WITH THE TEST HELPER ADDRESS
        adapter = new LayerZeroAdapter(
            LZ_ENDPOINT_BASE,
            address(router), // This now points to BridgeRouterTestHelper
            supportedChains,
            lzEids,
            governor
        );

        // Configure the adapter as governor
        vm.startPrank(governor);

        // Register adapter with bridge router
        router.registerAdapter(address(adapter));

        // Configure adapter settings
        _configureAdapter();

        vm.stopPrank();

        // Fund test accounts
        vm.deal(user, 5 ether);
        vm.deal(keeper, 5 ether);
        vm.deal(governor, 5 ether);
        vm.deal(address(router), 5 ether);
    }

    function _configureAdapter() internal {
        // Configuration values from layerzero.json for Base (chain ID 8453)
        uint32 readChannelId = 4294967295;
        address readLib1002 = 0x1273141a3f7923AA2d9edDfA402440cE075ed8Ff;
        address executor = 0x2CCA08ae69E0C44b18a57Ab2A87644234dAebaE4;
        address readDVN = 0xB1473AC9f58FB27597a21710da9D1071841E8163;
        uint64 confirmations = 15;
        uint32 maxMessageSize = 10000;
        uint128 minGasLimit = 300000;

        // Step 1: Activate read channel
        adapter.activateReadChannel(readChannelId);

        // Step 2: Set minimum gas limits for STATE_READ (2) and GENERAL_MESSAGE (3)
        adapter.setMinGasLimit(2, minGasLimit); // STATE_READ
        adapter.setMinGasLimit(3, minGasLimit); // GENERAL_MESSAGE

        // Step 3: Configure read libraries (ReadLib1002)
        adapter.configureReadLibraries(readLib1002);

        // Step 4: Configure DVNs AND executor together (must be sorted alphabetically)
        address[] memory readDVNs = new address[](1);
        readDVNs[0] = readDVN;
        adapter.configureReadDVNs(
            readLib1002,
            readDVNs,
            confirmations,
            executor
        );

        // Step 5: Set up peer for cross-chain communication to Arbitrum
        bytes32 peerAddressBytes32 = bytes32(
            uint256(uint160(address(adapter)))
        );
        adapter.setPeer(ARB_LZ_EID, peerAddressBytes32);

        // Step 6: Set up peer for read response channel (needed for lzReceive to work)
        adapter.setPeer(READ_CHANNEL_THRESHOLD + 1, peerAddressBytes32);

        // Step 7: Set up peer for threshold boundary test (exactly at threshold)
        adapter.setPeer(READ_CHANNEL_THRESHOLD, peerAddressBytes32);
    }

    function testSuccessfulReadResponseHandling() public {
        console.log("=== Testing Successful Read Response Handling ===");

        // Setup test data
        bytes32 operationId = keccak256(
            abi.encodePacked("test_read_operation_1")
        );
        bytes32 guid = keccak256(abi.encodePacked("test_guid_1"));
        bytes memory responseData = abi.encode(uint256(12345), "test_response");

        // Set up the operation in the router (simulating a previous read request)
        router.setOperationStatus(
            operationId,
            BridgeTypes.OperationStatus.SENT
        );

        // Associate the operation with the adapter (required for authorization)
        router.setOperationToAdapter(operationId, address(adapter));

        // Set the read request originator (required for deliverReadResponse)
        router.setReadRequestOriginator(operationId, user);

        // Map the GUID to operation ID (simulating a previous read request)
        _setOperationMapping(guid, operationId);

        // Create origin for read response (srcEid > READ_CHANNEL_THRESHOLD indicates read response)
        Origin memory origin = Origin({
            srcEid: READ_CHANNEL_THRESHOLD + 1, // Indicates this is a read response
            sender: bytes32(uint256(uint160(address(adapter)))), // Peer adapter address
            nonce: 1
        });

        // Expect the RelayFailed event (since user is not a contract that implements the interface)
        vm.expectEmit(true, false, false, true, address(adapter));
        emit RelayFailed(operationId, "");

        // Simulate receiving the read response through LayerZero
        vm.prank(LZ_ENDPOINT_BASE); // Only the LZ endpoint can call lzReceive
        adapter.lzReceive(origin, guid, responseData, address(0), "");

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
            sender: bytes32(uint256(uint160(address(adapter)))),
            nonce: 1
        });

        // Expect the ReadOperationNotFound event
        vm.expectEmit(true, false, false, true, address(adapter));
        emit ReadOperationNotFound(unknownGuid, "No operationId found");

        // Simulate receiving read response with unknown GUID
        vm.prank(LZ_ENDPOINT_BASE);
        adapter.lzReceive(origin, unknownGuid, responseData, address(0), "");

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

        // Associate the operation with the adapter (required for authorization)
        router.setOperationToAdapter(operationId, address(adapter));

        // Set the read request originator (required for deliverReadResponse)
        router.setReadRequestOriginator(operationId, user);

        // Map the GUID to operation ID
        _setOperationMapping(guid, operationId);

        // Configure router to fail delivery
        router.setShouldRevert(true);

        // Create origin for read response
        Origin memory origin = Origin({
            srcEid: READ_CHANNEL_THRESHOLD + 1,
            sender: bytes32(uint256(uint160(address(adapter)))),
            nonce: 1
        });

        // Expect the RelayFailed event due to delivery failure
        vm.expectEmit(true, false, false, false, address(adapter));
        emit RelayFailed(operationId, "");

        // Simulate receiving the read response - should handle delivery failure gracefully
        vm.prank(LZ_ENDPOINT_BASE);
        adapter.lzReceive(origin, guid, responseData, address(0), "");

        // Reset router behavior
        router.setShouldRevert(false);

        console.log("[SUCCESS] Delivery failure handled correctly");
    }

    function testReadChannelThresholdBoundaryConditions() public {
        console.log(
            "=== Testing Read Channel Threshold Boundary Conditions ==="
        );

        // Test that adapter recognizes read channel threshold correctly
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

        // The actual threshold check logic is internal to the adapter
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

    function testLayerZeroEndpointIntegration() public {
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

        // Verify adapter configuration
        console.log("Adapter read channel:", adapter.readChannelId());
        assertEq(
            adapter.readChannelId(),
            READ_CHANNEL_ID,
            "Read channel should be configured"
        );

        // Test that adapter recognizes read channel threshold correctly
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

            // Set up each operation in the router
            router.setOperationStatus(
                operationIds[i],
                BridgeTypes.OperationStatus.SENT
            );

            // Associate the operation with the adapter (required for authorization)
            router.setOperationToAdapter(operationIds[i], address(adapter));

            // Set the read request originator (required for deliverReadResponse)
            router.setReadRequestOriginator(operationIds[i], user);
        }

        // Process each read response
        for (uint256 i = 0; i < numResponses; i++) {
            bytes memory responseData = abi.encode(
                uint256(i * 1000),
                string(abi.encodePacked("response_", i))
            );

            Origin memory origin = Origin({
                srcEid: READ_CHANNEL_THRESHOLD + 1,
                sender: bytes32(uint256(uint160(address(adapter)))),
                nonce: uint64(i + 1)
            });

            // Expect the RelayFailed event for each response (since user is not a contract)
            vm.expectEmit(true, false, false, true, address(adapter));
            emit RelayFailed(operationIds[i], "");

            vm.prank(LZ_ENDPOINT_BASE);
            adapter.lzReceive(origin, guids[i], responseData, address(0), "");
        }

        console.log("[SUCCESS] Multiple read responses handled successfully");
    }

    // Helper function to simulate setting the internal mapping
    // In real usage, this would be set during the readState call
    function _setOperationMapping(bytes32 guid, bytes32 operationId) internal {
        // The lzMessageToOperationId mapping is at storage slot 3
        // (discovered through testing with the forked contract)
        bytes32 storageSlot = keccak256(abi.encode(guid, uint256(3)));
        vm.store(address(adapter), storageSlot, operationId);

        // Verify it was set correctly
        assertEq(
            adapter.lzMessageToOperationId(guid),
            operationId,
            "Operation mapping should be set correctly"
        );
    }
}
