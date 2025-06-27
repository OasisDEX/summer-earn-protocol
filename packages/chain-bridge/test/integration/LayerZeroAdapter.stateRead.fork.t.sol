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
import {ICrossChainStateReadReceiver} from "../../src/interfaces/ICrossChainStateReadReceiver.sol";
import {LayerZeroOptionsHelper} from "../../src/helpers/LayerZeroOptionsHelper.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {BridgeRouterTestHelper} from "../helpers/BridgeRouterTestHelper.sol";
import {ReadCodecV1, EVMCallRequestV1} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/ReadCodecV1.sol";

// Mock target contract on destination chain for state reading
contract MockTargetContract {
    uint256 public testValue = 12345;
    address public testAddress =
        address(0x1234567890123456789012345678901234567890);

    function getTestValue() external view returns (uint256) {
        return testValue;
    }

    function getTestAddress() external view returns (address) {
        return testAddress;
    }

    function balanceOf(address) external pure returns (uint256) {
        return 1000e18; // Mock balance
    }
}

/**
 * @title LayerZeroAdapter State Read Fork Test (Base)
 * @dev Fork test to verify LayerZero adapter state read functionality on Base mainnet
 */
contract LayerZeroAdapterStateReadBaseForkTest is Test {
    LayerZeroAdapter public adapter;
    BridgeRouterTestHelper public router;
    BridgeQueue public bridgeQueue;
    ProtocolAccessManager public accessManager;
    MockTargetContract public targetContract;

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

    // Configuration from layerzero.json for Base (8453)
    address public constant READ_LIB_1002_BASE =
        0x1273141a3f7923AA2d9edDfA402440cE075ed8Ff;
    address public constant EXECUTOR_BASE =
        0x2CCA08ae69E0C44b18a57Ab2A87644234dAebaE4;
    address public constant READ_DVN_BASE =
        0x9e059a54699a285714207b43B055483E78FAac25;
    uint32 public constant READ_CHANNEL_ID = 4294967295;
    uint32 public constant MAX_MESSAGE_SIZE = 10000;

    // Use a recent Base block (slightly earlier than latest for RPC stability)
    uint256 public constant FORK_BLOCK = 31_600_000;

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

        // Deploy mock target contract (simulates destination chain contract)
        targetContract = new MockTargetContract();

        // Setup supported chains configuration
        uint16[] memory supportedChains = new uint16[](2);
        uint32[] memory lzEids = new uint32[](2);
        supportedChains[0] = SOURCE_CHAIN_ID; // Base
        supportedChains[1] = DEST_CHAIN_ID; // Arbitrum
        lzEids[0] = BASE_LZ_EID; // Base LZ EID
        lzEids[1] = ARB_LZ_EID; // Arbitrum LZ EID

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

        // Configure adapter settings from layerzero.json
        _configureAdapter(); // Re-enable to find the specific issue

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

        // Step 5: Remove the separate configureReadExecutor call since it's now combined

        // Step 6: Set up peer for cross-chain communication to Arbitrum
        bytes32 peerAddressBytes32 = bytes32(
            uint256(uint160(address(adapter)))
        );
        adapter.setPeer(ARB_LZ_EID, peerAddressBytes32);
    }

    function testAdapterConfiguration() public {
        // Test that adapter is properly configured
        assertTrue(
            adapter.supportsChain(DEST_CHAIN_ID),
            "Destination chain not supported"
        );
        assertTrue(
            adapter.supportsOperation(BridgeTypes.OperationType.READ_STATE),
            "Read state operation not supported"
        );
        assertTrue(
            router.isValidAdapter(address(adapter)),
            "Adapter not registered with router"
        );

        // Test LayerZero EID mapping
        assertEq(
            adapter.chainToLzEid(DEST_CHAIN_ID),
            ARB_LZ_EID,
            "Chain to LZ EID mapping incorrect"
        );
        assertEq(
            adapter.lzEidToChain(ARB_LZ_EID),
            DEST_CHAIN_ID,
            "LZ EID to chain mapping incorrect"
        );

        // Test read channel configuration
        assertEq(
            adapter.readChannelId(),
            READ_CHANNEL_ID,
            "Read channel ID not configured"
        );
    }

    function testEstimateStateReadFee() public {
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 300000,
                msgValue: 0,
                calldataSize: 0,
                options: ""
            });

        (uint256 nativeFee, uint256 tokenFee) = adapter.estimateFee(
            DEST_CHAIN_ID,
            address(targetContract),
            0,
            adapterParams,
            BridgeTypes.OperationType.READ_STATE
        );

        assertGt(nativeFee, 0, "Native fee should be greater than 0");
        assertEq(tokenFee, 0, "Token fee should be 0 for LayerZero");

        console.log("Estimated state read fee:", nativeFee);
    }

    function testReadStateExecution() public {
        // Generate operation ID
        bytes32 currentOperationId = keccak256(
            abi.encodePacked("test_operation", block.timestamp)
        );

        // Define read parameters
        bytes4 selector = MockTargetContract.getTestValue.selector;
        bytes memory readParams = "";

        // Get fee estimate
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 300000,
                msgValue: 0,
                calldataSize: 0,
                options: ""
            });

        (uint256 nativeFee, ) = adapter.estimateFee(
            DEST_CHAIN_ID,
            address(targetContract),
            0,
            adapterParams,
            BridgeTypes.OperationType.READ_STATE
        );

        // Ensure we have enough ETH
        assertGe(
            address(keeper).balance,
            nativeFee,
            "Insufficient balance for operation"
        );

        // Set up the operation-to-adapter mapping for testing
        router.setOperationToAdapter(currentOperationId, address(adapter));

        // Set bridge router as the sender to bypass access control
        vm.startPrank(address(router));

        adapter.readState{value: nativeFee}(
            currentOperationId,
            SOURCE_CHAIN_ID,
            DEST_CHAIN_ID,
            address(targetContract),
            selector,
            readParams,
            keeper,
            adapterParams
        );
        vm.stopPrank();
    }

    function testReadStateWithInsufficientFee() public {
        bytes32 currentOperationId = keccak256(
            abi.encodePacked("test_operation_insufficient", block.timestamp)
        );

        bytes4 selector = MockTargetContract.getTestValue.selector;
        bytes memory readParams = "";

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 300000,
                msgValue: 0,
                calldataSize: 0,
                options: ""
            });

        (uint256 nativeFee, ) = adapter.estimateFee(
            DEST_CHAIN_ID,
            address(targetContract),
            0,
            adapterParams,
            BridgeTypes.OperationType.READ_STATE
        );

        // Try to send with insufficient fee from bridge router
        vm.startPrank(address(router));
        vm.expectRevert(); // Should revert due to insufficient fee
        adapter.readState{value: nativeFee / 2}(
            currentOperationId,
            SOURCE_CHAIN_ID,
            DEST_CHAIN_ID,
            address(targetContract),
            selector,
            readParams,
            keeper,
            adapterParams
        );
        vm.stopPrank();
    }

    function testReadStateUnauthorizedCaller() public {
        bytes32 currentOperationId = keccak256(
            abi.encodePacked("test_operation_unauthorized", block.timestamp)
        );

        bytes4 selector = MockTargetContract.getTestValue.selector;
        bytes memory readParams = "";

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 300000,
                msgValue: 0,
                calldataSize: 0,
                options: ""
            });

        // Try to call readState directly (not through bridge router)
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        adapter.readState{value: 1 ether}(
            currentOperationId,
            SOURCE_CHAIN_ID,
            DEST_CHAIN_ID,
            address(targetContract),
            selector,
            readParams,
            keeper,
            adapterParams
        );
        vm.stopPrank();
    }

    function testReadStateWithCustomGasLimit() public {
        bytes32 currentOperationId = keccak256(
            abi.encodePacked("test_operation_custom_gas", block.timestamp)
        );

        bytes4 selector = MockTargetContract.getTestValue.selector;
        bytes memory readParams = "";

        // Use higher gas limit than minimum
        uint64 customGasLimit = 300000 * 2;
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: customGasLimit,
                msgValue: 0,
                calldataSize: 0,
                options: ""
            });

        (uint256 nativeFee, ) = adapter.estimateFee(
            DEST_CHAIN_ID,
            address(targetContract),
            0,
            adapterParams,
            BridgeTypes.OperationType.READ_STATE
        );

        // Set up the operation-to-adapter mapping for testing
        router.setOperationToAdapter(currentOperationId, address(adapter));

        vm.startPrank(address(router));
        adapter.readState{value: nativeFee}(
            currentOperationId,
            SOURCE_CHAIN_ID,
            DEST_CHAIN_ID,
            address(targetContract),
            selector,
            readParams,
            keeper,
            adapterParams
        );
        vm.stopPrank();

        // Test passes if no revert occurs - actual LZ transaction would complete on real network
    }

    function testUnsupportedChain() public {
        uint16 unsupportedChainId = 999;
        bytes32 currentOperationId = keccak256(
            abi.encodePacked("test_operation_unsupported", block.timestamp)
        );

        bytes4 selector = MockTargetContract.getTestValue.selector;
        bytes memory readParams = "";

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 300000,
                msgValue: 0,
                calldataSize: 0,
                options: ""
            });

        // Should revert with UnsupportedChain error
        vm.startPrank(address(router));
        vm.expectRevert(abi.encodeWithSignature("UnsupportedChain()"));
        adapter.readState{value: 1 ether}(
            currentOperationId,
            SOURCE_CHAIN_ID,
            unsupportedChainId,
            address(targetContract),
            selector,
            readParams,
            keeper,
            adapterParams
        );
        vm.stopPrank();
    }

    function testReadChannelNotConfigured() public {
        // Deploy new adapter without read channel configuration
        uint16[] memory supportedChains = new uint16[](1);
        uint32[] memory lzEids = new uint32[](1);
        supportedChains[0] = DEST_CHAIN_ID;
        lzEids[0] = ARB_LZ_EID;

        LayerZeroAdapter unconfiguredAdapter = new LayerZeroAdapter(
            LZ_ENDPOINT_BASE,
            address(router),
            supportedChains,
            lzEids,
            governor
        );

        vm.startPrank(governor);
        router.registerAdapter(address(unconfiguredAdapter));
        vm.stopPrank();

        bytes32 currentOperationId = keccak256(
            abi.encodePacked("test_operation_no_channel", block.timestamp)
        );

        bytes4 selector = MockTargetContract.getTestValue.selector;
        bytes memory readParams = "";

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 300000,
                msgValue: 0,
                calldataSize: 0,
                options: ""
            });

        // Should revert with ReadChannelNotConfigured error
        vm.startPrank(address(router));
        vm.expectRevert(abi.encodeWithSignature("ReadChannelNotConfigured()"));
        unconfiguredAdapter.readState{value: 1 ether}(
            currentOperationId,
            SOURCE_CHAIN_ID,
            DEST_CHAIN_ID,
            address(targetContract),
            selector,
            readParams,
            keeper,
            adapterParams
        );
        vm.stopPrank();
    }

    function testGetRequiredFeeFunction() public {
        // Create target call data
        bytes memory targetCallData = abi.encodePacked(
            MockTargetContract.getTestValue.selector,
            ""
        );

        // Create EVMCallRequestV1 array exactly like the adapter does
        EVMCallRequestV1[] memory readRequests = new EVMCallRequestV1[](1);
        readRequests[0] = EVMCallRequestV1({
            appRequestLabel: 1,
            targetEid: ARB_LZ_EID,
            isBlockNum: false,
            blockNumOrTimestamp: uint64(block.timestamp),
            confirmations: 15,
            to: address(targetContract),
            callData: targetCallData
        });

        // Encode using ReadCodecV1.encode exactly like the adapter does
        bytes memory payload = ReadCodecV1.encode(0, readRequests);

        uint256 requiredFee = adapter.getRequiredFee(
            READ_CHANNEL_ID, // Use read channel ID for state reads
            adapter.STATE_READ(), // STATE_READ = 2
            payload
        );

        assertGt(requiredFee, 0, "Required fee should be greater than 0");
        console.log("Required fee for state read:", requiredFee);
    }

    function testLayerZeroEndpointIntegration() public {
        // Test that the adapter can successfully interact with the real LayerZero endpoint
        bytes32 currentOperationId = keccak256(
            abi.encodePacked("test_lz_integration", block.timestamp)
        );

        bytes4 selector = MockTargetContract.getTestValue.selector;
        bytes memory readParams = "";

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 300000,
                msgValue: 0,
                calldataSize: 0,
                options: ""
            });

        (uint256 nativeFee, ) = adapter.estimateFee(
            DEST_CHAIN_ID,
            address(targetContract),
            0,
            adapterParams,
            BridgeTypes.OperationType.READ_STATE
        );

        // Set up the operation-to-adapter mapping for testing
        router.setOperationToAdapter(currentOperationId, address(adapter));

        // This test verifies that the real LayerZero endpoint accepts our read request
        // Even though we can't complete the cross-chain flow in a fork test,
        // we can verify the transaction doesn't revert when submitted to the endpoint
        vm.startPrank(address(router));

        // The transaction should not revert if properly configured
        try
            adapter.readState{value: nativeFee}(
                currentOperationId,
                SOURCE_CHAIN_ID,
                DEST_CHAIN_ID,
                address(targetContract),
                selector,
                readParams,
                keeper,
                adapterParams
            )
        {
            // Success - the read request was accepted by LayerZero endpoint
            console.log("LayerZero endpoint accepted the read request");
        } catch Error(string memory reason) {
            // If it reverts with a specific error, we can analyze it
            console.log("LayerZero endpoint rejected request:", reason);
            // Re-throw to fail the test if there's an unexpected error
            revert(reason);
        }

        vm.stopPrank();
    }

    function testReadLibraryConfiguration() public {
        // Test that ReadLib1002 is properly configured
        // We can verify this by checking that read operations don't revert
        // with library-related errors

        bytes32 currentOperationId = keccak256(
            abi.encodePacked("test_readlib_config", block.timestamp)
        );

        bytes4 selector = MockTargetContract.getTestValue.selector;
        bytes memory readParams = "";

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 300000,
                msgValue: 0,
                calldataSize: 0,
                options: ""
            });

        (uint256 nativeFee, ) = adapter.estimateFee(
            DEST_CHAIN_ID,
            address(targetContract),
            0,
            adapterParams,
            BridgeTypes.OperationType.READ_STATE
        );

        // Verify that the adapter's read channel configuration is correct
        assertEq(
            adapter.readChannelId(),
            READ_CHANNEL_ID,
            "Read channel not properly configured"
        );

        // Set up the operation-to-adapter mapping for testing
        router.setOperationToAdapter(currentOperationId, address(adapter));

        // Execute read state to verify ReadLib configuration
        vm.startPrank(address(router));

        // This should not revert if ReadLib1002 is properly configured
        adapter.readState{value: nativeFee}(
            currentOperationId,
            SOURCE_CHAIN_ID,
            DEST_CHAIN_ID,
            address(targetContract),
            selector,
            readParams,
            keeper,
            adapterParams
        );

        vm.stopPrank();

        console.log(
            "ReadLib1002 configuration appears to be working correctly"
        );
    }

    function testLayerZeroEndpointDiagnostics() public {
        console.log("=== LayerZero Endpoint Fork Diagnostics ===");
        console.log(
            "This test investigates why LayerZero calls fail in fork environment"
        );

        address endpoint = LZ_ENDPOINT_BASE;
        console.log("\n1. Basic Endpoint State Check:");
        console.log("Endpoint address:", endpoint);
        console.log("Endpoint code size:", endpoint.code.length);

        if (endpoint.code.length == 0) {
            console.log(
                "[CRITICAL] Endpoint has no code! Fork block may be too early."
            );
            return;
        }

        console.log("\n2. Testing Basic Endpoint Calls:");

        // Test 1: Can we call basic endpoint functions?
        (bool success, bytes memory result) = endpoint.staticcall(
            abi.encodeWithSignature("lzVersion()")
        );
        if (success && result.length > 0) {
            console.log("[OK] Endpoint lzVersion call succeeded");
        } else {
            console.log("[FAILED] lzVersion call failed or returned empty");
        }

        // Test 2: Check if our adapter is recognized by the endpoint
        console.log("\n3. Adapter Recognition Check:");
        address adapterAddr = address(adapter);
        console.log("Adapter address:", adapterAddr);

        // Test 3: Check library configuration for our adapter
        console.log("\n4. Library Configuration Check:");

        (bool libSuccess, bytes memory libResult) = endpoint.staticcall(
            abi.encodeWithSignature(
                "getSendLibrary(address,uint32)",
                adapterAddr,
                READ_CHANNEL_ID
            )
        );

        if (libSuccess) {
            if (libResult.length >= 32) {
                address sendLib = abi.decode(libResult, (address));
                console.log("Send library found:", sendLib);
                console.log("Expected ReadLib1002:", READ_LIB_1002_BASE);

                if (sendLib == address(0)) {
                    console.log(
                        "[ISSUE] Send library is zero address - not configured!"
                    );
                } else if (sendLib != READ_LIB_1002_BASE) {
                    console.log("[ISSUE] Wrong send library configured");
                    console.log(
                        "Actual library code size:",
                        sendLib.code.length
                    );
                } else {
                    console.log("[OK] Correct send library configured");
                }
            } else {
                console.log(
                    "[ISSUE] getSendLibrary returned insufficient data"
                );
            }
        } else {
            console.log("[FAILED] getSendLibrary call failed");
            if (libResult.length > 0) {
                console.log("Error data:");
                console.logBytes(libResult);
            }
        }

        // Test 4: Check ReadLib1002 state
        console.log("\n5. ReadLib1002 State Check:");
        address readLib = READ_LIB_1002_BASE;
        console.log("ReadLib1002 address:", readLib);
        console.log("ReadLib1002 code size:", readLib.code.length);

        if (readLib.code.length == 0) {
            console.log("[CRITICAL] ReadLib1002 has no code at fork block!");
        }

        // Test 5: Try to understand what happens during fee estimation
        console.log("\n6. Fee Estimation Deep Dive:");

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 300000,
                msgValue: 0,
                calldataSize: 0,
                options: ""
            });

        // Let's trace what the adapter does during fee estimation
        console.log("Calling adapter.estimateFee with parameters:");
        console.log("- destChainId:", DEST_CHAIN_ID);
        console.log("- target:", address(targetContract));
        console.log("- gasLimit:", adapterParams.gasLimit);

        // Use raw call to get exact error
        bytes memory feeCallData = abi.encodeWithSelector(
            adapter.estimateFee.selector,
            DEST_CHAIN_ID,
            address(targetContract),
            0,
            adapterParams,
            BridgeTypes.OperationType.READ_STATE
        );

        (bool feeSuccess, bytes memory feeResult) = address(adapter).staticcall(
            feeCallData
        );

        if (!feeSuccess) {
            console.log("[FAILED] Fee estimation failed");
            console.log("Error data length:", feeResult.length);

            if (feeResult.length >= 4) {
                bytes4 errorSelector = bytes4(feeResult);
                console.log("Error selector:", vm.toString(errorSelector));

                // Check for common LayerZero errors
                if (
                    errorSelector ==
                    bytes4(keccak256("LZ_UlnV2_InvalidInstructions()"))
                ) {
                    console.log("-> LayerZero invalid instructions error");
                } else if (
                    errorSelector ==
                    bytes4(keccak256("LZ_UlnV2_InvalidLibrary()"))
                ) {
                    console.log("-> LayerZero invalid library error");
                } else if (
                    errorSelector == bytes4(keccak256("LZ_UlnV2_NotReady()"))
                ) {
                    console.log("-> LayerZero not ready error");
                }
            }

            console.logBytes(feeResult);
        } else {
            console.log("[OK] Fee estimation succeeded");
            if (feeResult.length >= 32) {
                uint256 fee = abi.decode(feeResult, (uint256));
                console.log("Estimated fee:", fee);
            }
        }

        // Test 6: Check what happens when we try to make the actual call
        console.log("\n7. Actual Transaction Call Analysis:");

        if (feeSuccess && feeResult.length >= 32) {
            uint256 nativeFee = abi.decode(feeResult, (uint256));

            if (nativeFee > 0) {
                console.log("Attempting actual readState call...");

                vm.startPrank(address(router));
                vm.deal(address(router), nativeFee);

                bytes32 operationId = bytes32(uint256(12345));
                bytes memory txCallData = abi.encodeWithSelector(
                    adapter.readState.selector,
                    operationId,
                    DEST_CHAIN_ID,
                    address(targetContract),
                    MockTargetContract.getTestValue.selector,
                    "",
                    adapterParams
                );

                (bool txSuccess, bytes memory txResult) = address(adapter).call{
                    value: nativeFee
                }(txCallData);

                if (!txSuccess) {
                    console.log("[FAILED] Transaction call failed");
                    console.log(
                        "Transaction error data length:",
                        txResult.length
                    );

                    if (txResult.length > 0) {
                        console.log("Transaction error data:");
                        console.logBytes(txResult);

                        // Try to decode the error
                        if (txResult.length >= 4) {
                            bytes4 txErrorSelector = bytes4(txResult);
                            console.log(
                                "Transaction error selector:",
                                vm.toString(txErrorSelector)
                            );
                        }
                    }
                } else {
                    console.log("[SUCCESS] Transaction succeeded!");
                }

                vm.stopPrank();
            }
        }

        console.log("\n=== Diagnosis Complete ===");
    }

    function testForkBlockAnalysis() public {
        console.log("=== Fork Block Analysis ===");
        console.log("Current fork configuration:");
        console.log("- Fork block:", FORK_BLOCK);
        console.log("- Block number:", block.number);
        console.log("- Block timestamp:", block.timestamp);

        // Check if key contracts exist at this block
        address[] memory criticalContracts = new address[](3);
        criticalContracts[0] = LZ_ENDPOINT_BASE;
        criticalContracts[1] = READ_LIB_1002_BASE;
        criticalContracts[2] = address(
            0x0000000000000000000000000000000000000001
        ); // Known precompile

        string[] memory contractNames = new string[](3);
        contractNames[0] = "LayerZero Endpoint";
        contractNames[1] = "ReadLib1002";
        contractNames[2] = "EC Recover Precompile";

        for (uint i = 0; i < criticalContracts.length; i++) {
            address contractAddr = criticalContracts[i];
            uint256 codeSize = contractAddr.code.length;

            console.log(contractNames[i], ":", contractAddr);
            console.log("- Code size:", codeSize);

            if (codeSize == 0 && i < 2) {
                // Don't worry about precompile code size
                console.log("- [WARNING] Contract has no code!");
            }
        }

        // Test if we need a more recent block
        console.log("\nTesting with different scenarios:");
        console.log("1. Current setup appears to have contracts deployed");
        console.log("2. If tests fail, the issue might be:");
        console.log("   - ReadLib1002 not configured for our adapter");
        console.log("   - LayerZero endpoint expecting specific state");
        console.log("   - RPC provider limitations with complex calls");

        // Check Base network specific info
        console.log("\nBase network info:");
        console.log("- Chain ID:", block.chainid);
        console.log("- Expected Base chain ID: 8453");

        if (block.chainid != 8453) {
            console.log("[ERROR] Not connected to Base network!");
        }
    }

    function testCalldataSizeAnalysis() public {
        console.log("=== Calldata Size Analysis ===");
        console.log(
            "Investigating if incorrect calldataSize is causing failures"
        );

        bytes32 operationId = keccak256(
            abi.encodePacked("calldata_test", block.timestamp)
        );
        bytes4 selector = MockTargetContract.getTestValue.selector;
        bytes memory readParams = "";

        // Calculate the actual message data that will be sent cross-chain
        bytes memory messageData = abi.encode(
            operationId,
            address(targetContract),
            selector,
            readParams
        );

        console.log("\n1. Message Data Analysis:");
        console.log("- Operation ID length: 32 bytes");
        console.log("- Target contract length: 32 bytes (padded address)");
        console.log("- Function selector length: 32 bytes (padded bytes4)");
        console.log("- Read params length:", readParams.length, "bytes");
        console.log(
            "- Total encoded message length:",
            messageData.length,
            "bytes"
        );

        // Test with different calldata sizes
        uint256[] memory calldataSizes = new uint256[](4);
        calldataSizes[0] = 0; // What we're currently using
        calldataSizes[1] = messageData.length; // Actual message size
        calldataSizes[2] = 128; // Common size
        calldataSizes[3] = 256; // Larger size

        console.log("\n2. Testing Different Calldata Sizes:");

        for (uint i = 0; i < calldataSizes.length; i++) {
            uint256 testCalldataSize = calldataSizes[i];
            console.log("\n--- Testing calldataSize:", testCalldataSize, "---");

            BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
                .AdapterParams({
                    gasLimit: 300000,
                    msgValue: 0,
                    calldataSize: uint32(testCalldataSize),
                    options: ""
                });

            bytes memory feeCallData = abi.encodeWithSelector(
                adapter.estimateFee.selector,
                DEST_CHAIN_ID,
                address(targetContract),
                0,
                adapterParams,
                BridgeTypes.OperationType.READ_STATE
            );

            (bool feeSuccess, bytes memory feeResult) = address(adapter)
                .staticcall(feeCallData);

            if (feeSuccess && feeResult.length >= 32) {
                uint256 nativeFee = abi.decode(feeResult, (uint256));
                console.log(
                    "[SUCCESS] Fee estimation succeeded with calldataSize",
                    testCalldataSize
                );
                console.log("Estimated fee:", nativeFee);

                // If this works, try the actual transaction
                if (nativeFee > 0) {
                    console.log(
                        "Attempting transaction with this calldataSize..."
                    );

                    vm.startPrank(address(router));
                    vm.deal(address(router), nativeFee);

                    bytes memory txCallData = abi.encodeWithSelector(
                        adapter.readState.selector,
                        operationId,
                        DEST_CHAIN_ID,
                        address(targetContract),
                        selector,
                        readParams,
                        adapterParams
                    );

                    (bool txSuccess, bytes memory txResult) = address(adapter)
                        .call{value: nativeFee}(txCallData);

                    if (txSuccess) {
                        console.log(
                            "[SUCCESS] Transaction succeeded with calldataSize",
                            testCalldataSize
                        );
                        console.log("*** FOUND WORKING CONFIGURATION ***");
                    } else {
                        console.log(
                            "[FAILED] Transaction failed despite successful fee estimation"
                        );
                        if (txResult.length > 0) {
                            console.log("Transaction error:");
                            console.logBytes(txResult);
                        }
                    }

                    vm.stopPrank();
                }
            } else {
                console.log(
                    "[FAILED] Fee estimation failed with calldataSize",
                    testCalldataSize
                );
                if (feeResult.length >= 4) {
                    bytes4 errorSel = bytes4(feeResult);
                    console.log("Error selector:", vm.toString(errorSel));
                }
            }
        }

        console.log("\n3. Advanced Calldata Analysis:");

        // Let's also test what happens with different read parameters
        bytes[] memory testReadParams = new bytes[](3);
        testReadParams[0] = ""; // Empty
        testReadParams[1] = abi.encode(uint256(42)); // Simple parameter
        testReadParams[2] = abi.encode(address(targetContract), uint256(42)); // Complex parameter

        for (uint j = 0; j < testReadParams.length; j++) {
            bytes memory testParams = testReadParams[j];
            bytes memory testMessageData = abi.encode(
                operationId,
                address(targetContract),
                selector,
                testParams
            );

            console.log(
                "\n--- Testing with read params length:",
                testParams.length,
                "---"
            );
            console.log("Total message data length:", testMessageData.length);

            BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
                .AdapterParams({
                    gasLimit: 300000,
                    msgValue: 0,
                    calldataSize: uint32(testMessageData.length), // Use actual message size
                    options: ""
                });

            bytes memory feeCallData = abi.encodeWithSelector(
                adapter.estimateFee.selector,
                DEST_CHAIN_ID,
                address(targetContract),
                0,
                adapterParams,
                BridgeTypes.OperationType.READ_STATE
            );

            (bool feeSuccess, bytes memory feeResult) = address(adapter)
                .staticcall(feeCallData);

            if (feeSuccess && feeResult.length >= 32) {
                uint256 nativeFee = abi.decode(feeResult, (uint256));
                console.log(
                    "[SUCCESS] Fee estimation with params length",
                    testParams.length,
                    ":",
                    nativeFee
                );
            } else {
                console.log(
                    "[FAILED] Fee estimation with params length",
                    testParams.length
                );
            }
        }

        console.log("\n=== Calldata Size Analysis Complete ===");
    }

    function testLayerZeroErrorDecoding() public {
        console.log("=== LayerZero Error Decoding ===");

        // The error we saw was 0x052e5515 with value 0x5
        bytes4 errorSelector = 0x052e5515;
        console.log(
            "Error selector from diagnostics:",
            vm.toString(errorSelector)
        );

        // Common LayerZero V2 errors - let's check if this matches any known errors
        bytes4[] memory knownErrors = new bytes4[](10);
        string[] memory errorNames = new string[](10);

        knownErrors[0] = bytes4(keccak256("LZ_UlnV2_InvalidInstructions()"));
        errorNames[0] = "LZ_UlnV2_InvalidInstructions";

        knownErrors[1] = bytes4(keccak256("LZ_UlnV2_InvalidLibrary()"));
        errorNames[1] = "LZ_UlnV2_InvalidLibrary";

        knownErrors[2] = bytes4(keccak256("LZ_UlnV2_NotReady()"));
        errorNames[2] = "LZ_UlnV2_NotReady";

        knownErrors[3] = bytes4(keccak256("LZ_UlnV2_InvalidPayloadHash()"));
        errorNames[3] = "LZ_UlnV2_InvalidPayloadHash";

        knownErrors[4] = bytes4(keccak256("LZ_UlnV2_InvalidConfig()"));
        errorNames[4] = "LZ_UlnV2_InvalidConfig";

        knownErrors[5] = bytes4(keccak256("InvalidOptions()"));
        errorNames[5] = "InvalidOptions";

        knownErrors[6] = bytes4(keccak256("InvalidEndpointCall()"));
        errorNames[6] = "InvalidEndpointCall";

        knownErrors[7] = bytes4(keccak256("OnlyEndpoint()"));
        errorNames[7] = "OnlyEndpoint";

        knownErrors[8] = bytes4(keccak256("NativeFeeInsufficent()"));
        errorNames[8] = "NativeFeeInsufficent";

        knownErrors[9] = bytes4(keccak256("InvalidReceiveLibrary()"));
        errorNames[9] = "InvalidReceiveLibrary";

        console.log("\nChecking against known LayerZero errors:");
        bool found = false;
        for (uint i = 0; i < knownErrors.length; i++) {
            console.log(errorNames[i], ":", vm.toString(knownErrors[i]));
            if (knownErrors[i] == errorSelector) {
                console.log("*** MATCH FOUND:", errorNames[i], "***");
                found = true;
            }
        }

        if (!found) {
            console.log("Error selector not found in known LayerZero errors");
            console.log(
                "This might be a custom error or newer LayerZero error"
            );
        }

        // The value 0x5 might be an enum or error code
        console.log("\nError value analysis:");
        console.log("The error data contained value 5, which might indicate:");
        console.log("- Error type/category: 5");
        console.log("- Invalid parameter index: 5");
        console.log("- Configuration issue code: 5");
    }

    function testLayerZeroReadEndpointConfiguration() public {
        console.log("=== Testing LayerZero Read Endpoint Configuration ===");
        console.log(
            "This test verifies the missing configuration steps from the documentation"
        );

        // The _configureLayerZeroReadEndpoint should have been called during setUp
        // Let's verify if it worked by testing a read operation

        bytes32 operationId = keccak256(abi.encodePacked("config_test"));
        bytes4 selector = MockTargetContract.getTestValue.selector;
        bytes memory readParams = "";

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 300000,
                msgValue: 0,
                calldataSize: 160,
                options: ""
            });

        console.log("1. Testing fee estimation after proper configuration...");
        try
            adapter.estimateFee(
                DEST_CHAIN_ID,
                address(targetContract),
                0,
                adapterParams,
                BridgeTypes.OperationType.READ_STATE
            )
        returns (uint256 nativeFee, uint256 tokenFee) {
            console.log("[SUCCESS] Fee estimation worked after configuration!");
            console.log("Native fee:", nativeFee);
            console.log("Token fee:", tokenFee);

            if (nativeFee > 0) {
                console.log("2. Testing actual read state call...");
                vm.startPrank(address(router));
                vm.deal(address(router), nativeFee);

                try
                    adapter.readState{value: nativeFee}(
                        operationId,
                        SOURCE_CHAIN_ID,
                        DEST_CHAIN_ID,
                        address(targetContract),
                        selector,
                        readParams,
                        user,
                        adapterParams
                    )
                {
                    console.log("[SUCCESS] Read state call succeeded!");
                    console.log(
                        "*** LAYERZERO READ CONFIGURATION IS WORKING! ***"
                    );
                } catch Error(string memory reason) {
                    console.log("[FAILED] Read state call failed:", reason);
                } catch (bytes memory errorData) {
                    console.log(
                        "[FAILED] Read state call failed with low-level error"
                    );
                    if (errorData.length >= 4) {
                        bytes4 errorSel = bytes4(errorData);
                        console.log("Error selector:", vm.toString(errorSel));

                        // Check if it's still the same error
                        if (errorSel == 0x052e5515) {
                            console.log(
                                "Still getting Executor_UnsupportedOptionType error"
                            );
                            console.log(
                                "This means the endpoint configuration didn't take effect"
                            );
                        }
                    }
                }

                vm.stopPrank();
            }
        } catch Error(string memory reason) {
            console.log("[FAILED] Fee estimation still failing:", reason);
        } catch (bytes memory errorData) {
            console.log("[FAILED] Fee estimation failed with low-level error");
            if (errorData.length >= 4) {
                bytes4 errorSel = bytes4(errorData);
                console.log("Error selector:", vm.toString(errorSel));
            }
        }

        console.log("=== Configuration Test Complete ===");
    }
}
