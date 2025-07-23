// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CrossChainRegistry} from "../../src/contracts/CrossChainRegistry.sol";
import {ICrossChainRegistry} from "../../src/interfaces/ICrossChainRegistry.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {Test} from "forge-std/Test.sol";

contract CrossChainRegistryTest is Test {
    CrossChainRegistry public registry;
    ProtocolAccessManager public accessManager;

    address public governor = makeAddr("governor");
    address public guardian = makeAddr("guardian");
    address public keeper = makeAddr("keeper");
    address public user = makeAddr("user");

    address public ark1 = makeAddr("ark1");
    address public ark2 = makeAddr("ark2");
    address public ark3 = makeAddr("ark3");
    address public proxy1 = makeAddr("proxy1");
    address public proxy2 = makeAddr("proxy2");
    address public proxy3 = makeAddr("proxy3");

    uint16 public constant CURRENT_CHAIN_ID = 1;
    uint16 public constant TARGET_CHAIN_ID = 42161;

    bytes32 public constant ARK_FLEET_RELATIONSHIP =
        keccak256("ARK_FLEET_RELATIONSHIP");
    bytes32 public constant EXECUTOR_RELATIONSHIP =
        keccak256("EXECUTOR_RELATIONSHIP");

    address public executor = makeAddr("executor");

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

    // Add new variables for bridge config testing
    address public mockBridgeQueue = makeAddr("bridgeQueue");
    address public mockBridgeRouter = makeAddr("bridgeRouter");
    address public newMockBridgeQueue = makeAddr("newBridgeQueue");
    address public newMockBridgeRouter = makeAddr("newBridgeRouter");
    uint256 public constant DEFAULT_GAS_LIMIT = 200000;
    uint256 public constant NEW_GAS_LIMIT = 300000;

    // Add new events
    event BridgeQueueUpdated(
        address indexed oldBridgeQueue,
        address indexed newBridgeQueue
    );
    event BridgeRouterUpdated(
        address indexed oldBridgeRouter,
        address indexed newBridgeRouter
    );
    event DefaultGasLimitUpdated(
        uint256 oldDefaultGasLimit,
        uint256 newDefaultGasLimit
    );

    function setUp() public {
        // Deploy access manager
        accessManager = new ProtocolAccessManager(governor);

        // Deploy registry
        vm.prank(governor);
        registry = new CrossChainRegistry(
            address(accessManager),
            CURRENT_CHAIN_ID
        );
    }

    /*//////////////////////////////////////////////////////////////
                           BASIC FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_deployment() public view {
        assertEq(registry.currentChainId(), CURRENT_CHAIN_ID);
        assertEq(registry.getRelationshipCount(ARK_FLEET_RELATIONSHIP), 0);
    }

    function test_registerCrossChainRelationship() public {
        vm.expectEmit(true, true, true, true);
        emit CrossChainRelationshipRegistered(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );

        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );

        // Check relationship was created
        (address targetContract, uint16 chainId) = registry.getTargetForSource(
            ark1,
            ARK_FLEET_RELATIONSHIP
        );
        assertEq(targetContract, proxy1);
        assertEq(chainId, TARGET_CHAIN_ID);

        // Check reverse mapping
        address sourceContract = registry.getSourceForTarget(
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1,
            ARK_FLEET_RELATIONSHIP
        );
        assertEq(sourceContract, ark1);

        // Check validation
        assertTrue(
            registry.isValidCrossChainPair(
                ark1,
                proxy1,
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                ARK_FLEET_RELATIONSHIP
            )
        );
        assertTrue(
            registry.isSourceContractRegistered(ark1, ARK_FLEET_RELATIONSHIP)
        );

        // Check count
        assertEq(registry.getRelationshipCount(ARK_FLEET_RELATIONSHIP), 1);
    }

    function test_registerCrossChainRelationship_revertInvalidSourceContract()
        public
    {
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.InvalidSourceContract.selector,
                address(0)
            )
        );
        registry.registerRelationship(
            address(0),
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );
    }

    function test_registerCrossChainRelationship_revertInvalidTargetContract()
        public
    {
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.InvalidTargetContract.selector,
                address(0)
            )
        );
        registry.registerRelationship(
            ark1,
            address(0),
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );
    }

    function test_registerCrossChainRelationship_revertInvalidChainId() public {
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.InvalidChainId.selector,
                0
            )
        );
        registry.registerRelationship(
            ark1,
            proxy1,
            0,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );
    }

    function test_registerCrossChainRelationship_sameChainRelationship()
        public
    {
        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            CURRENT_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );
    }

    function test_registerCrossChainRelationship_revertInvalidChainRelationship()
        public
    {
        uint16 otherChain1 = 137; // Polygon
        uint16 otherChain2 = 56; // BSC

        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.InvalidChainRelationship.selector,
                otherChain1,
                otherChain2,
                CURRENT_CHAIN_ID
            )
        );
        registry.registerRelationship(
            ark1,
            proxy1,
            otherChain1,
            otherChain2,
            ARK_FLEET_RELATIONSHIP
        );
    }

    function test_registerCrossChainRelationship_validWithDeploymentChainAsTarget()
        public
    {
        uint16 otherChain = 137; // Polygon

        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy1,
            otherChain,
            CURRENT_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );

        // Verify relationship was created
        (address targetContract, uint16 chainId) = registry.getTargetForSource(
            ark1,
            ARK_FLEET_RELATIONSHIP
        );
        assertEq(targetContract, proxy1);
        assertEq(chainId, CURRENT_CHAIN_ID);
    }

    function test_registerCrossChainRelationship_revertAlreadyExists() public {
        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );

        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipAlreadyExists.selector,
                ark1,
                ARK_FLEET_RELATIONSHIP,
                TARGET_CHAIN_ID
            )
        );
        registry.registerRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );
    }

    function test_registerCrossChainRelationship_revertTargetAlreadyRegistered()
        public
    {
        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );

        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.TargetContractAlreadyRegistered.selector,
                proxy1,
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                ARK_FLEET_RELATIONSHIP,
                ark1
            )
        );
        registry.registerRelationship(
            ark2,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );
    }

    function test_registerCrossChainRelationship_onlyGovernor() public {
        vm.prank(user);
        vm.expectRevert();
        registry.registerRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );
    }

    function test_unregisterCrossChainRelationship() public {
        // First register
        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );

        vm.expectEmit(true, true, true, true);
        emit CrossChainRelationshipUnregistered(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );

        vm.prank(governor);
        registry.unregisterRelationship(
            ark1,
            ARK_FLEET_RELATIONSHIP,
            TARGET_CHAIN_ID
        );

        // Check relationship was removed
        assertFalse(
            registry.isSourceContractRegistered(ark1, ARK_FLEET_RELATIONSHIP)
        );
        assertEq(registry.getRelationshipCount(ARK_FLEET_RELATIONSHIP), 0);

        // Should revert when trying to access
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                ark1,
                ARK_FLEET_RELATIONSHIP,
                0
            )
        );
        registry.getTargetForSource(ark1, ARK_FLEET_RELATIONSHIP);
    }

    function test_unregisterCrossChainRelationship_revertNotExists() public {
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                ark1,
                ARK_FLEET_RELATIONSHIP,
                TARGET_CHAIN_ID
            )
        );
        registry.unregisterRelationship(
            ark1,
            ARK_FLEET_RELATIONSHIP,
            TARGET_CHAIN_ID
        );
    }

    function test_unregisterCrossChainRelationship_onlyGovernor() public {
        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );

        vm.prank(user);
        vm.expectRevert();
        registry.unregisterRelationship(
            ark1,
            ARK_FLEET_RELATIONSHIP,
            TARGET_CHAIN_ID
        );
    }

    function test_getTargetForSource() public {
        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );

        (address targetContract, uint16 chainId) = registry.getTargetForSource(
            ark1,
            ARK_FLEET_RELATIONSHIP
        );
        assertEq(targetContract, proxy1);
        assertEq(chainId, TARGET_CHAIN_ID);
    }

    function test_getTargetForSource_revertNotExists() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                ark1,
                ARK_FLEET_RELATIONSHIP,
                0
            )
        );
        registry.getTargetForSource(ark1, ARK_FLEET_RELATIONSHIP);
    }

    function test_getSourceForTarget() public {
        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );

        address sourceContract = registry.getSourceForTarget(
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1,
            ARK_FLEET_RELATIONSHIP
        );
        assertEq(sourceContract, ark1);
    }

    function test_getSourceForTarget_revertNotExists() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                address(0),
                ARK_FLEET_RELATIONSHIP,
                TARGET_CHAIN_ID
            )
        );
        registry.getSourceForTarget(
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1,
            ARK_FLEET_RELATIONSHIP
        );
    }

    function test_isValidCrossChainPair() public {
        // Should be false before registration
        assertFalse(
            registry.isValidCrossChainPair(
                ark1,
                proxy1,
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                ARK_FLEET_RELATIONSHIP
            )
        );

        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );

        // Should be true after registration
        assertTrue(
            registry.isValidCrossChainPair(
                ark1,
                proxy1,
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                ARK_FLEET_RELATIONSHIP
            )
        );

        // Should be false for wrong proxy
        assertFalse(
            registry.isValidCrossChainPair(
                ark1,
                proxy2,
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                ARK_FLEET_RELATIONSHIP
            )
        );

        // Should be false for wrong source chain
        assertFalse(
            registry.isValidCrossChainPair(
                ark1,
                proxy1,
                TARGET_CHAIN_ID,
                TARGET_CHAIN_ID,
                ARK_FLEET_RELATIONSHIP
            )
        );

        // Should be false for wrong target chain
        assertFalse(
            registry.isValidCrossChainPair(
                ark1,
                proxy1,
                CURRENT_CHAIN_ID,
                CURRENT_CHAIN_ID,
                ARK_FLEET_RELATIONSHIP
            )
        );

        // Should be false for wrong ark
        assertFalse(
            registry.isValidCrossChainPair(
                ark2,
                proxy1,
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                ARK_FLEET_RELATIONSHIP
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                           MULTIPLE REGISTRATIONS
    //////////////////////////////////////////////////////////////*/

    function test_multipleRegistrations() public {
        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );

        vm.prank(governor);
        registry.registerRelationship(
            ark2,
            proxy2,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );

        vm.prank(governor);
        registry.registerRelationship(
            ark3,
            proxy3,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );

        assertEq(registry.getRelationshipCount(ARK_FLEET_RELATIONSHIP), 3);

        // Check first relationship
        (address targetContract, uint16 chainId) = registry.getTargetForSource(
            ark1,
            ARK_FLEET_RELATIONSHIP
        );
        assertEq(targetContract, proxy1);
        assertEq(chainId, TARGET_CHAIN_ID);

        // Check second relationship
        (targetContract, chainId) = registry.getTargetForSource(
            ark2,
            ARK_FLEET_RELATIONSHIP
        );
        assertEq(targetContract, proxy2);
        assertEq(chainId, TARGET_CHAIN_ID);

        // Check third relationship
        (targetContract, chainId) = registry.getTargetForSource(
            ark3,
            ARK_FLEET_RELATIONSHIP
        );
        assertEq(targetContract, proxy3);
        assertEq(chainId, TARGET_CHAIN_ID);

        // Check reverse mappings
        assertEq(
            registry.getSourceForTarget(
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                proxy1,
                ARK_FLEET_RELATIONSHIP
            ),
            ark1
        );
        assertEq(
            registry.getSourceForTarget(
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                proxy2,
                ARK_FLEET_RELATIONSHIP
            ),
            ark2
        );
        assertEq(
            registry.getSourceForTarget(
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                proxy3,
                ARK_FLEET_RELATIONSHIP
            ),
            ark3
        );

        // Check validations
        assertTrue(
            registry.isValidCrossChainPair(
                ark1,
                proxy1,
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                ARK_FLEET_RELATIONSHIP
            )
        );
        assertTrue(
            registry.isValidCrossChainPair(
                ark2,
                proxy2,
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                ARK_FLEET_RELATIONSHIP
            )
        );
        assertTrue(
            registry.isValidCrossChainPair(
                ark3,
                proxy3,
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                ARK_FLEET_RELATIONSHIP
            )
        );
    }

    function test_unregisterOneOfMultiple() public {
        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );

        vm.prank(governor);
        registry.registerRelationship(
            ark2,
            proxy2,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );

        vm.prank(governor);
        registry.unregisterRelationship(
            ark1,
            ARK_FLEET_RELATIONSHIP,
            TARGET_CHAIN_ID
        );

        assertEq(registry.getRelationshipCount(ARK_FLEET_RELATIONSHIP), 1);
        assertFalse(
            registry.isSourceContractRegistered(ark1, ARK_FLEET_RELATIONSHIP)
        );
        assertTrue(
            registry.isSourceContractRegistered(ark2, ARK_FLEET_RELATIONSHIP)
        );
    }

    function test_reregisterAfterUnregister() public {
        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );

        vm.prank(governor);
        registry.unregisterRelationship(
            ark1,
            ARK_FLEET_RELATIONSHIP,
            TARGET_CHAIN_ID
        );

        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy2,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );

        (address targetContract, uint16 chainId) = registry.getTargetForSource(
            ark1,
            ARK_FLEET_RELATIONSHIP
        );
        assertEq(targetContract, proxy2);
        assertEq(chainId, TARGET_CHAIN_ID);
    }

    function test_multipleRelationshipTypes() public {
        bytes32 arkFleetType = keccak256("ARK_FLEET_RELATIONSHIP");
        bytes32 bridgeType = keccak256("PEER_RELATIONSHIP");

        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            arkFleetType
        );

        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy2,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            bridgeType
        );

        // Check both relationships exist
        (address targetContract1, uint16 chainId1) = registry
            .getTargetForSource(ark1, arkFleetType);
        assertEq(targetContract1, proxy1);
        assertEq(chainId1, TARGET_CHAIN_ID);

        (address targetContract2, uint16 chainId2) = registry
            .getTargetForSource(ark1, bridgeType);
        assertEq(targetContract2, proxy2);
        assertEq(chainId2, TARGET_CHAIN_ID);

        // Check counts
        assertEq(registry.getRelationshipCount(arkFleetType), 1);
        assertEq(registry.getRelationshipCount(bridgeType), 1);

        // Check supported types
        bytes32[] memory supportedTypes = registry
            .getSupportedRelationshipTypes();
        assertEq(supportedTypes.length, 3);
        // Note: The order might vary, so we check both types are present
        assertTrue(
            (supportedTypes[0] == arkFleetType &&
                supportedTypes[1] == bridgeType) ||
                (supportedTypes[0] == bridgeType &&
                    supportedTypes[1] == arkFleetType)
        );
    }

    /*//////////////////////////////////////////////////////////////
                        BRIDGE CONFIG TESTS
    //////////////////////////////////////////////////////////////*/

    function test_bridgeConfigInitialState() public view {
        assertEq(registry.bridgeRouter(), address(0));
        assertEq(registry.defaultGasLimit(), 0);
    }

    function test_initializeBridgeConfiguration() public {
        vm.startPrank(governor);

        vm.expectEmit(true, true, false, true);
        emit BridgeRouterUpdated(address(0), mockBridgeRouter);

        vm.expectEmit(false, false, false, true);
        emit DefaultGasLimitUpdated(0, DEFAULT_GAS_LIMIT);

        registry.initializeBridgeConfiguration(
            mockBridgeRouter,
            DEFAULT_GAS_LIMIT
        );

        // Verify state
        assertEq(registry.bridgeRouter(), mockBridgeRouter);
        assertEq(registry.defaultGasLimit(), DEFAULT_GAS_LIMIT);

        vm.stopPrank();
    }

    function test_initializeBridgeConfiguration_revertAlreadyInitialized()
        public
    {
        vm.startPrank(governor);

        registry.initializeBridgeConfiguration(
            mockBridgeRouter,
            DEFAULT_GAS_LIMIT
        );

        vm.expectRevert(
            ICrossChainRegistry.BridgeConfigAlreadyInitialized.selector
        );
        registry.initializeBridgeConfiguration(
            mockBridgeRouter,
            DEFAULT_GAS_LIMIT
        );

        vm.stopPrank();
    }

    function test_initializeBridgeConfiguration_revertUnauthorized() public {
        vm.prank(user);
        vm.expectRevert();
        registry.initializeBridgeConfiguration(
            mockBridgeRouter,
            DEFAULT_GAS_LIMIT
        );
    }

    function test_initializeBridgeConfiguration_revertZeroBridgeRouter()
        public
    {
        vm.prank(governor);
        vm.expectRevert(ICrossChainRegistry.AddressZero.selector);
        registry.initializeBridgeConfiguration(address(0), DEFAULT_GAS_LIMIT);
    }

    function test_initializeBridgeConfiguration_revertZeroGasLimit() public {
        vm.prank(governor);
        vm.expectRevert(ICrossChainRegistry.InvalidGasLimit.selector);
        registry.initializeBridgeConfiguration(mockBridgeRouter, 0);
    }

    function test_setBridgeRouter() public {
        _initializeBridgeConfig();

        vm.startPrank(governor);

        vm.expectEmit(true, true, false, true);
        emit BridgeRouterUpdated(mockBridgeRouter, newMockBridgeRouter);

        registry.setBridgeRouter(newMockBridgeRouter);
        assertEq(registry.bridgeRouter(), newMockBridgeRouter);

        vm.stopPrank();
    }

    function test_setBridgeRouter_revertUnauthorized() public {
        _initializeBridgeConfig();

        vm.prank(user);
        vm.expectRevert();
        registry.setBridgeRouter(newMockBridgeRouter);
    }

    function test_setBridgeRouter_revertZeroAddress() public {
        _initializeBridgeConfig();

        vm.prank(governor);
        vm.expectRevert(ICrossChainRegistry.AddressZero.selector);
        registry.setBridgeRouter(address(0));
    }

    function test_setDefaultGasLimit() public {
        _initializeBridgeConfig();

        vm.startPrank(governor);

        vm.expectEmit(false, false, false, true);
        emit DefaultGasLimitUpdated(DEFAULT_GAS_LIMIT, NEW_GAS_LIMIT);

        registry.setDefaultGasLimit(NEW_GAS_LIMIT);
        assertEq(registry.defaultGasLimit(), NEW_GAS_LIMIT);

        vm.stopPrank();
    }

    function test_setDefaultGasLimit_revertUnauthorized() public {
        _initializeBridgeConfig();

        vm.prank(user);
        vm.expectRevert();
        registry.setDefaultGasLimit(NEW_GAS_LIMIT);
    }

    function test_setDefaultGasLimit_revertZero() public {
        _initializeBridgeConfig();

        vm.prank(governor);
        vm.expectRevert(ICrossChainRegistry.InvalidGasLimit.selector);
        registry.setDefaultGasLimit(0);
    }

    function test_guardianCannotCallBridgeConfigSetters() public {
        _initializeBridgeConfig();

        vm.startPrank(guardian);

        vm.expectRevert();
        registry.setBridgeRouter(newMockBridgeRouter);

        vm.expectRevert();
        registry.setDefaultGasLimit(NEW_GAS_LIMIT);

        vm.stopPrank();
    }

    function test_setSameValueBridgeRouter() public {
        _initializeBridgeConfig();

        vm.startPrank(governor);

        // Setting the same value should still emit event
        vm.expectEmit(true, true, false, true);
        emit BridgeRouterUpdated(mockBridgeRouter, mockBridgeRouter);

        registry.setBridgeRouter(mockBridgeRouter);
        assertEq(registry.bridgeRouter(), mockBridgeRouter);

        vm.stopPrank();
    }

    function test_setSameValueDefaultGasLimit() public {
        _initializeBridgeConfig();

        vm.startPrank(governor);

        // Setting the same value should still emit event
        vm.expectEmit(false, false, false, true);
        emit DefaultGasLimitUpdated(DEFAULT_GAS_LIMIT, DEFAULT_GAS_LIMIT);

        registry.setDefaultGasLimit(DEFAULT_GAS_LIMIT);
        assertEq(registry.defaultGasLimit(), DEFAULT_GAS_LIMIT);

        vm.stopPrank();
    }

    function test_multipleUpdatesBridgeRouter() public {
        _initializeBridgeConfig();

        vm.startPrank(governor);

        // First update
        registry.setBridgeRouter(newMockBridgeRouter);
        assertEq(registry.bridgeRouter(), newMockBridgeRouter);

        // Second update back to original
        registry.setBridgeRouter(mockBridgeRouter);
        assertEq(registry.bridgeRouter(), mockBridgeRouter);

        vm.stopPrank();
    }

    function test_multipleUpdatesDefaultGasLimit() public {
        _initializeBridgeConfig();

        vm.startPrank(governor);

        // First update
        registry.setDefaultGasLimit(NEW_GAS_LIMIT);
        assertEq(registry.defaultGasLimit(), NEW_GAS_LIMIT);

        // Second update back to original
        registry.setDefaultGasLimit(DEFAULT_GAS_LIMIT);
        assertEq(registry.defaultGasLimit(), DEFAULT_GAS_LIMIT);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _initializeBridgeConfig() internal {
        vm.prank(governor);
        registry.initializeBridgeConfiguration(
            mockBridgeRouter,
            DEFAULT_GAS_LIMIT
        );
    }

    function test_constructor() public view {
        // Test initial state after constructor
        assertEq(registry.bridgeRouter(), address(0));
        assertEq(registry.defaultGasLimit(), 0);

        // Test that both PEER_RELATIONSHIP and ARK_FLEET_RELATIONSHIP relationship types are supported by default
        bytes32[] memory supportedTypes = registry
            .getSupportedRelationshipTypes();
        assertEq(supportedTypes.length, 3);

        // Check that both relationship types are present (order may vary)
        bool hasAdapterPeer = false;
        bool hasArkFleet = false;

        for (uint256 i = 0; i < supportedTypes.length; i++) {
            if (supportedTypes[i] == keccak256("PEER_RELATIONSHIP")) {
                hasAdapterPeer = true;
            } else if (supportedTypes[i] == ARK_FLEET_RELATIONSHIP) {
                hasArkFleet = true;
            }
        }

        assertTrue(
            hasAdapterPeer,
            "BRIDGE_ADAPTER relationship type not found"
        );
        assertTrue(
            hasArkFleet,
            "ARK_FLEET_RELATIONSHIP relationship type not found"
        );

        // Test that current chain ID is set correctly
        assertEq(registry.currentChainId(), CURRENT_CHAIN_ID);
    }

    function test_constructor_revertZeroChainId() public {
        vm.startPrank(governor);
        vm.expectRevert(ICrossChainRegistry.InvalidCurrentChainId.selector);
        new CrossChainRegistry(address(accessManager), 0);
        vm.stopPrank();
    }

    /*─────────────────────────────────────────────────────────────────
        SOURCE-CHAIN RELATIONSHIP TESTS
    ─────────────────────────────────────────────────────────────────*/
    function test_registerSourceChainRelationship() public {
        bytes32 localRelationship = keccak256("LOCAL_REL");
        address src = makeAddr("localSrc");
        address dst = makeAddr("localDst");

        vm.expectEmit(true, true, true, true);
        emit CrossChainRelationshipRegistered(
            src,
            dst,
            CURRENT_CHAIN_ID,
            CURRENT_CHAIN_ID,
            localRelationship
        );

        vm.prank(governor);
        registry.registerRelationship(
            src,
            dst,
            CURRENT_CHAIN_ID,
            CURRENT_CHAIN_ID,
            localRelationship
        );

        (address target, uint16 chainId) = registry.getTargetForSource(
            src,
            localRelationship
        );
        assertEq(target, dst);
        assertEq(chainId, CURRENT_CHAIN_ID);

        assertTrue(
            registry.isValidCrossChainPair(
                src,
                dst,
                CURRENT_CHAIN_ID,
                CURRENT_CHAIN_ID,
                localRelationship
            )
        );
    }

    function test_registerSourceChainRelationship_onlyGovernor() public {
        bytes32 localRelationship = keccak256("LOCAL_REL_2");
        vm.prank(user);
        vm.expectRevert();
        registry.registerRelationship(
            makeAddr("src2"),
            makeAddr("dst2"),
            CURRENT_CHAIN_ID,
            CURRENT_CHAIN_ID,
            localRelationship
        );
    }

    /*─────────────────────────────────────────────────────────────────
                            EXECUTOR_RELATIONSHIP TESTS
    ─────────────────────────────────────────────────────────────────*/
    function test_registerExecutor_andAuthorization() public {
        _initializeBridgeConfig(); // sets non-zero bridgeRouter

        vm.expectEmit(true, true, true, true);
        emit CrossChainRelationshipRegistered(
            keeper,
            mockBridgeRouter,
            CURRENT_CHAIN_ID,
            CURRENT_CHAIN_ID,
            EXECUTOR_RELATIONSHIP
        );

        vm.prank(governor);
        registry.registerExecutor(keeper);

        assertTrue(registry.isAuthorizedExecutor(keeper));
        assertTrue(
            registry.isValidCrossChainPair(
                keeper,
                mockBridgeRouter,
                CURRENT_CHAIN_ID,
                CURRENT_CHAIN_ID,
                EXECUTOR_RELATIONSHIP
            )
        );
    }

    function test_registerExecutor_onlyGovernor() public {
        _initializeBridgeConfig();
        vm.prank(user);
        vm.expectRevert();
        registry.registerExecutor(keeper);
    }

    function test_registerExecutor_revertWhenBridgeRouterUnset() public {
        // bridgeRouter is address(0) before initialise
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.InvalidTargetContract.selector,
                address(0)
            )
        );
        registry.registerExecutor(keeper);
    }

    function test_removeExecutor() public {
        _initializeBridgeConfig();
        vm.prank(governor);
        registry.registerExecutor(keeper);

        vm.prank(governor);
        registry.removeExecutor(keeper);

        assertFalse(registry.isAuthorizedExecutor(keeper));
    }
}
