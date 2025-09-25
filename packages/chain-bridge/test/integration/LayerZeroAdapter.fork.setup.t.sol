// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CrossChainRegistry} from "../../src/contracts/CrossChainRegistry.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {BridgeRouterTestHelper} from "../helpers/BridgeRouterTestHelper.sol";
import {LayerZeroAdapterTestHelper} from "../helpers/LayerZeroAdapterTestHelper.sol";
import {MockCrossChainReceiver} from "../mocks/MockCrossChainReceiver.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {Test} from "forge-std/Test.sol";

/**
 * @title LayerZeroAdapter Fork Test Setup
 * @notice Base setup for LayerZero layerZeroAdapter fork tests with proper CrossChainRegistry integration
 * @dev Provides common setup functionality for all LayerZero fork tests
 */
abstract contract LayerZeroAdapterForkSetupTest is Test {
    // Contracts
    LayerZeroAdapterTestHelper public layerZeroAdapter;
    BridgeRouterTestHelper public router;
    CrossChainRegistry public registry;
    ProtocolAccessManager public accessManager;
    MockCrossChainReceiver public mockCrossChainStateReadReceiver;

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
    uint256 public constant FORK_BLOCK = 31600000;

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

        // Deploy registry
        registry = new CrossChainRegistry(
            address(accessManager),
            SOURCE_CHAIN_ID
        );

        // Configure roles
        vm.startPrank(governor);
        accessManager.grantGuardianRole(guardian);
        vm.stopPrank();

        // Create router TEST HELPER, passing the deployed BridgeQueue address
        router = new BridgeRouterTestHelper(
            address(accessManager),
            address(registry)
        );

        vm.startPrank(governor);

        // Initialize bridge configuration
        registry.initializeBridgeConfiguration(
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

        // Deploy LayerZero layerZeroAdapter TEST HELPER with CrossChainConfigManager
        layerZeroAdapter = new LayerZeroAdapterTestHelper(
            LZ_ENDPOINT_BASE,
            address(registry), // Use registry for cross-chain configuration
            address(accessManager),
            supportedChains,
            lzEids,
            governor,
            READ_CHANNEL_THRESHOLD
        );

        // Register layerZeroAdapter with bridge router
        vm.startPrank(governor);
        router.registerAdapter(address(layerZeroAdapter));

        // Register layerZeroAdapter as an executor
        registry.registerExecutor(keeper);

        mockCrossChainStateReadReceiver = new MockCrossChainReceiver();

        vm.stopPrank();
    }

    function _configureAdapter() internal {
        vm.startPrank(governor);

        // Configuration values from layerzero.json for Base (chain ID 8453)
        uint32 readChannelId = READ_CHANNEL_ID;
        address readLib1002 = READ_LIB_1002_BASE;
        address executor = EXECUTOR_BASE;
        address readDvn = READ_DVN_BASE;
        uint64 confirmations = 15;

        // Step 1: Activate read channel
        layerZeroAdapter.activateReadChannel(readChannelId);

        // Step 3: Configure read libraries (ReadLib1002)
        layerZeroAdapter.configureReadLibraries(readLib1002);

        // Step 4: Configure DVNs AND executor together (must be sorted alphabetically)
        /// forge-lint: disable-start(mixed-case-variable)
        address[] memory readDVNs = new address[](1);
        readDVNs[0] = readDvn;
        layerZeroAdapter.configureReadDVNs(
            readLib1002,
            readDVNs,
            confirmations,
            executor
        );
        /// forge-lint: disable-end(mixed-case-variable)

        // Step 5: Set up peer for cross-chain communication to Arbitrum
        bytes32 peerAddressBytes32 = bytes32(
            uint256(uint160(address(layerZeroAdapter)))
        );
        layerZeroAdapter.setPeer(ARB_LZ_EID, peerAddressBytes32);

        // Step 6: Set up peer for read response channel (needed for lzReceive to work)
        layerZeroAdapter.setPeer(
            READ_CHANNEL_THRESHOLD + 1,
            peerAddressBytes32
        );

        // Step 7: Set up peer for threshold boundary test (exactly at threshold)
        layerZeroAdapter.setPeer(READ_CHANNEL_THRESHOLD, peerAddressBytes32);

        // Register the layerZeroAdapter peer relationship in the registry
        registry.registerAdapterPeer(
            address(layerZeroAdapter), // source layerZeroAdapter
            address(layerZeroAdapter), // target layerZeroAdapter (same address since it's a mirror setup)
            SOURCE_CHAIN_ID, // Base chain ID (8453)
            DEST_CHAIN_ID // Arbitrum chain ID (42161)
        );

        // Also register the reverse mapping for inbound validation (Arbitrum -> Base)
        registry.registerAdapterPeer(
            address(layerZeroAdapter), // source adapter on Arbitrum
            address(layerZeroAdapter), // target adapter on Base
            DEST_CHAIN_ID, // Arbitrum chain ID (42161)
            SOURCE_CHAIN_ID // Base chain ID (8453)
        );

        vm.stopPrank();
    }

    function _fundAccounts() internal {
        // Fund test accounts
        vm.deal(user, 5 ether);
        vm.deal(keeper, 5 ether);
        vm.deal(governor, 5 ether);
        vm.deal(address(router), 5 ether);
    }

    // Helper function to check layerZeroAdapter configuration
    function _verifyAdapterConfiguration() internal view {
        // Test that layerZeroAdapter is properly configured
        assertTrue(
            layerZeroAdapter.CROSS_CHAIN_REGISTRY().getAdapterPeer(
                address(layerZeroAdapter),
                DEST_CHAIN_ID
            ) != address(0),
            "Destination chain not supported"
        );
        assertTrue(
            layerZeroAdapter.supportsOperation(
                BridgeTypes.OperationType.READ_STATE
            ),
            "Read state operation not supported"
        );
        assertTrue(
            router.isValidAdapter(address(layerZeroAdapter)),
            "Adapter not registered with router"
        );

        // Test LayerZero EID mapping
        assertEq(
            layerZeroAdapter.chainToExternalId(DEST_CHAIN_ID),
            ARB_LZ_EID,
            "Chain to LZ EID mapping incorrect"
        );
        assertEq(
            layerZeroAdapter.externalIdToChainId(ARB_LZ_EID),
            DEST_CHAIN_ID,
            "LZ EID to chain mapping incorrect"
        );

        // Test read channel configuration
        assertEq(
            layerZeroAdapter.readChannelId(),
            READ_CHANNEL_ID,
            "Read channel ID not configured"
        );

        // Test CrossChainRegistry integration
        assertEq(
            layerZeroAdapter.bridgeRouter(),
            address(router),
            "Bridge router not accessible through registry"
        );
    }

    // Helper function to deploy a fresh unconfigured layerZeroAdapter for negative tests
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
                address(accessManager),
                supportedChains,
                lzEids,
                governor,
                READ_CHANNEL_THRESHOLD
            );

        vm.startPrank(governor);
        router.registerAdapter(address(unconfiguredAdapter));

        // Add peer relationship registration so the adapter can pass initial peer checks
        // but don't configure the read channel (which is what the test expects to fail)
        registry.registerAdapterPeer(
            address(unconfiguredAdapter), // source adapter
            address(unconfiguredAdapter), // target adapter (same address since it's a mirror setup)
            SOURCE_CHAIN_ID, // Base chain ID (8453)
            DEST_CHAIN_ID // Arbitrum chain ID (42161)
        );

        vm.stopPrank();

        return unconfiguredAdapter;
    }

    // Helper function to set operation mapping for testing (now uses test helper)
    function _setOperationMapping(bytes32 guid, bytes32 operationId) internal {
        // Use the test helper's direct setter instead of storage manipulation
        layerZeroAdapter.setLzMessageToOperationId(guid, operationId);

        // Verify it was set correctly
        assertEq(
            layerZeroAdapter.lzMessageToOperationId(guid),
            operationId,
            "Operation mapping should be set correctly"
        );
    }

    function testSkipper() public {}
}
