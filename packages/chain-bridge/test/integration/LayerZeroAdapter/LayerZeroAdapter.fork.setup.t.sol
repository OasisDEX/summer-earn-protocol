// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CrossChainRegistryOld} from "../../../src/contracts/CrossChainRegistryOld.sol";
import {BridgeTypes} from "../../../src/libraries/BridgeTypes.sol";
import {BridgeRouterTestHelper} from "../../helpers/BridgeRouterTestHelper.sol";
import {LayerZeroAdapterTestHelper} from "../../helpers/LayerZeroAdapterTestHelper.sol";
import {MockCrossChainReceiver} from "../../mocks/MockCrossChainReceiver.sol";
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
    CrossChainRegistryOld public registry;
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
    // READ_STATE constants removed
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
        registry = new CrossChainRegistryOld(address(accessManager));

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
        registry.setBridgeRouter(address(router));
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
            governor
        );

        // Register layerZeroAdapter with bridge router
        vm.startPrank(governor);
        router.registerAdapter(address(layerZeroAdapter));

        // Register layerZeroAdapter as an executor
        registry.registerExecutor(keeper);

        vm.stopPrank();
    }

    function _configureAdapter() internal {
        vm.startPrank(governor);
        // Step: Set up peer for cross-chain communication to Arbitrum
        bytes32 peerAddressBytes32 = bytes32(
            uint256(uint160(address(layerZeroAdapter)))
        );
        layerZeroAdapter.setPeer(ARB_LZ_EID, peerAddressBytes32);

        // Register the layerZeroAdapter peer relationship in the registry
        // This registers both directions: (Base -> Arbitrum) and (Arbitrum -> Base)
        registry.registerAdapterPeerPair(
            address(layerZeroAdapter),
            address(layerZeroAdapter),
            SOURCE_CHAIN_ID,
            DEST_CHAIN_ID
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
        // READ_STATE support checks removed
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

        // READ_STATE channel configuration removed

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
                governor
            );

        vm.startPrank(governor);
        router.registerAdapter(address(unconfiguredAdapter));

        // Add peer relationship registration so the adapter can pass initial peer checks
        // but don't configure the read channel (which is what the test expects to fail)
        registry.registerAdapterPeerPair(
            address(unconfiguredAdapter), // adapter A
            address(unconfiguredAdapter), // adapter B (same address since it's a mirror setup)
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
}
