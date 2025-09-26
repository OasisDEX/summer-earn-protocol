// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CrossChainRegistry} from "../../src/contracts/CrossChainRegistry.sol";
import {ICrossChainRegistry} from "../../src/interfaces/ICrossChainRegistry.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {Test} from "forge-std/Test.sol";

/// @notice Base helper for CrossChainRegistry tests with shared setup, events, and helpers
contract BaseCrossChainRegistryTest is Test {
    // Core contracts
    CrossChainRegistry public registry;
    ProtocolAccessManager public accessManager;

    // Common actors
    address public governor = makeAddr("governor");
    address public guardian = makeAddr("guardian");
    address public keeper = makeAddr("keeper");
    address public user = makeAddr("user");

    // Sample contracts
    address public ark1 = makeAddr("ark1");
    address public ark2 = makeAddr("ark2");
    address public ark3 = makeAddr("ark3");
    address public proxy1 = makeAddr("proxy1");
    address public proxy2 = makeAddr("proxy2");
    address public proxy3 = makeAddr("proxy3");

    // Chain IDs
    uint16 public constant CURRENT_CHAIN_ID = 31337;
    uint16 public constant TARGET_CHAIN_ID = 42161;

    // Relationship types (both constants and live getters for convenience)
    bytes32 public constant PEER_RELATIONSHIP = keccak256("PEER_RELATIONSHIP");
    bytes32 public constant EXECUTOR_RELATIONSHIP =
        keccak256("EXECUTOR_RELATIONSHIP");
    bytes32 public peerType;
    bytes32 public executorType;

    // Bridge router addresses for tests
    address public mockBridgeRouter = makeAddr("bridgeRouter");
    address public newMockBridgeRouter = makeAddr("newBridgeRouter");

    // Events (mirror interface for expectEmit clarity)
    event BridgeRouterUpdated(
        address indexed oldBridgeRouter,
        address indexed newBridgeRouter
    );
    event CrossChainRelationshipRegistered(
        address indexed sourceContract,
        address indexed targetContract,
        uint16 indexed sourceChainId,
        uint16 targetChainId,
        bytes32 relationshipType
    );
    event CrossChainRelationshipUnregistered(
        address indexed sourceContract,
        address indexed targetContract,
        uint16 indexed sourceChainId,
        uint16 targetChainId,
        bytes32 relationshipType
    );

    function setUp() public virtual {
        // Deploy access manager and registry
        accessManager = new ProtocolAccessManager(governor);
        vm.prank(governor);
        registry = new CrossChainRegistry(address(accessManager));

        // Capture relationship types from the contract to avoid drift
        peerType = registry.PEER_RELATIONSHIP();
        executorType = registry.EXECUTOR_RELATIONSHIP();
    }

    function testSkipper() public {}

    function _initializeBridgeRouter() internal {
        _initializeBridgeRouter(mockBridgeRouter);
    }

    function _initializeBridgeRouter(address bridgeRouter) internal {
        vm.startPrank(governor);
        registry.setBridgeRouter(bridgeRouter);
        vm.stopPrank();
    }
}
