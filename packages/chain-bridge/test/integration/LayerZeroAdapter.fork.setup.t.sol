// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {LayerZeroAdapterTestHelper} from "../helpers/LayerZeroAdapterTestHelper.sol";
import {BridgeRouterTestHelper} from "../helpers/BridgeRouterTestHelper.sol";
import {BridgeQueue} from "../../src/router/BridgeQueue.sol";
import {CrossChainRegistry} from "../../src/contracts/CrossChainRegistry.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";

/**
 * @title LayerZeroAdapter Fork Test Setup
 * @notice Base setup for LayerZero adapter fork tests with proper CrossChainRegistry integration
 * @dev Provides common setup functionality for all LayerZero fork tests
 */
abstract contract LayerZeroAdapterForkSetupTest is Test {
    // Contracts
    LayerZeroAdapterTestHelper public adapter;
    BridgeRouterTestHelper public router;
    BridgeQueue public bridgeQueue;
    CrossChainRegistry public registry;
    ProtocolAccessManager public accessManager;

    // Test addresses
    address public governor = makeAddr("governor");
    address public guardian = makeAddr("guardian");
    address public user = makeAddr("user");
    address public keeper = makeAddr("keeper");

    // Chain configuration - Base to Arbitrum (default)
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
        0xB1473AC9f58FB27597a21710da9D1071841E8163;
    uint32 public constant READ_CHANNEL_ID = 4294967295;
    uint32 public constant READ_CHANNEL_THRESHOLD = 4294965694;
    uint32 public constant MAX_MESSAGE_SIZE = 10000;

    // Default gas limit for config manager
    uint256 public constant DEFAULT_GAS_LIMIT = 400000;

    // Use a recent Base block (slightly earlier than latest for RPC stability)
    uint256 public constant FORK_BLOCK = 31_600_000;

    function setUp() public virtual {
        // Fork Base mainnet
        vm.createSelectFork(vm.rpcUrl("base"), FORK_BLOCK);

        _setupContracts();
        _configureAdapter();
        _fundAccounts();
    }

    function _setupContracts() internal {
        // Create access manager
        accessManager = new ProtocolAccessManager(governor);

        // Configure roles
        vm.startPrank(governor);
        accessManager.grantGuardianRole(guardian);
        vm.stopPrank();

        // Create bridge queue first (without router initially)
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

        // Deploy registry
        vm.startPrank(governor);
        registry = new CrossChainRegistry(
            address(accessManager),
            SOURCE_CHAIN_ID
        );

        // Initialize bridge configuration
        registry.initializeBridgeConfiguration(
            address(bridgeQueue),
            address(router),
            DEFAULT_GAS_LIMIT
        );
        vm.stopPrank();

        // Setup supported chains configuration
        uint16[] memory supportedChains = new uint16[](2);
        uint32[] memory lzEids = new uint32[](2);
        supportedChains[0] = SOURCE_CHAIN_ID; // Base
        supportedChains[1] = DEST_CHAIN_ID; // Arbitrum
        lzEids[0] = BASE_LZ_EID; // Base LZ EID
        lzEids[1] = ARB_LZ_EID; // Arbitrum LZ EID

        // Deploy LayerZero adapter TEST HELPER with CrossChainConfigManager
        adapter = new LayerZeroAdapterTestHelper(
            LZ_ENDPOINT_BASE,
            address(registry), // Use registry for cross-chain configuration
            supportedChains,
            lzEids,
            governor
        );

        // Register adapter with bridge router
        vm.startPrank(governor);
        router.registerAdapter(address(adapter));
        vm.stopPrank();
    }

    function _configureAdapter() internal {
        vm.startPrank(governor);

        // Configuration values from layerzero.json for Base (chain ID 8453)
        uint32 readChannelId = READ_CHANNEL_ID;
        address readLib1002 = READ_LIB_1002_BASE;
        address executor = EXECUTOR_BASE;
        address readDVN = READ_DVN_BASE;
        uint64 confirmations = 15;
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

        vm.stopPrank();
    }

    function _fundAccounts() internal {
        // Fund test accounts
        vm.deal(user, 5 ether);
        vm.deal(keeper, 5 ether);
        vm.deal(governor, 5 ether);
        vm.deal(address(router), 5 ether);
    }

    // Helper function to check adapter configuration
    function _verifyAdapterConfiguration() internal view {
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

        // Test CrossChainRegistry integration
        assertEq(
            adapter.bridgeRouter(),
            address(router),
            "Bridge router not accessible through registry"
        );
        assertEq(
            adapter.bridgeQueue(),
            address(bridgeQueue),
            "Bridge queue not accessible through registry"
        );
    }

    // Helper function to deploy a fresh unconfigured adapter for negative tests
    function _deployUnconfiguredAdapter()
        internal
        returns (LayerZeroAdapterTestHelper)
    {
        uint16[] memory supportedChains = new uint16[](1);
        uint32[] memory lzEids = new uint32[](1);
        supportedChains[0] = DEST_CHAIN_ID;
        lzEids[0] = ARB_LZ_EID;

        LayerZeroAdapterTestHelper unconfiguredAdapter = new LayerZeroAdapterTestHelper(
                LZ_ENDPOINT_BASE,
                address(registry), // Still use registry for consistency
                supportedChains,
                lzEids,
                governor
            );

        vm.startPrank(governor);
        router.registerAdapter(address(unconfiguredAdapter));
        vm.stopPrank();

        return unconfiguredAdapter;
    }

    // Helper function to set operation mapping for testing (now uses test helper)
    function _setOperationMapping(bytes32 guid, bytes32 operationId) internal {
        // Use the test helper's direct setter instead of storage manipulation
        adapter.setLzMessageToOperationId(guid, operationId);

        // Verify it was set correctly
        assertEq(
            adapter.lzMessageToOperationId(guid),
            operationId,
            "Operation mapping should be set correctly"
        );
    }
}
