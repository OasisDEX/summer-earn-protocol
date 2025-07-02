// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/contracts/CrossChainRegistry.sol";
import "../src/interfaces/ICrossChainRegistry.sol";
import "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";

/**
 * @title CrossChainRegistryIntegrationTest
 * @notice Integration test demonstrating the complete registry-based workflow
 */
contract CrossChainRegistryIntegrationTest is Test {
    CrossChainRegistry public registry;
    ProtocolAccessManager public accessManager;

    // Mock contracts for testing
    address public mockBridgeRouter = makeAddr("bridgeRouter");
    address public mockBridgeQueue = makeAddr("bridgeQueue");
    address public mockFleetContract = makeAddr("fleetContract");

    address public governor = makeAddr("governor");
    address public guardian = makeAddr("guardian");
    address public keeper = makeAddr("keeper");

    uint16 public constant CURRENT_CHAIN_ID = 1;
    uint16 public constant TARGET_CHAIN_ID = 42161;

    bytes32 public constant ARK_FLEET_RELATIONSHIP = keccak256("ARK_FLEET");

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
                           INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_endToEndRegistrationAndValidation() public {
        address arkAddress = makeAddr("testArk");
        address proxyAddress = makeAddr("testProxy");

        // Register the relationship
        vm.expectEmit(true, true, true, true);
        emit CrossChainRelationshipRegistered(
            arkAddress,
            proxyAddress,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );

        vm.prank(governor);
        registry.registerCrossChainRelationship(
            arkAddress,
            proxyAddress,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );

        // Verify the relationship
        (address targetContract, uint16 chainId) = registry.getTargetForSource(
            arkAddress,
            ARK_FLEET_RELATIONSHIP
        );
        assertEq(targetContract, proxyAddress);
        assertEq(chainId, TARGET_CHAIN_ID);

        address sourceContract = registry.getSourceForTarget(
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxyAddress,
            ARK_FLEET_RELATIONSHIP
        );
        assertEq(sourceContract, arkAddress);

        // Validate the relationship
        assertTrue(
            registry.isValidCrossChainPair(
                arkAddress,
                proxyAddress,
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                ARK_FLEET_RELATIONSHIP
            )
        );
    }

    function test_registrationWithDifferentChainIds() public {
        address arkAddress = makeAddr("ark");
        address proxyAddress = makeAddr("proxy");

        uint16 differentSourceChain = CURRENT_CHAIN_ID; // Current deployment chain (1)
        uint16 differentTargetChain = 10; // Optimism

        vm.prank(governor);
        registry.registerCrossChainRelationship(
            arkAddress,
            proxyAddress,
            differentSourceChain,
            differentTargetChain,
            ARK_FLEET_RELATIONSHIP
        );

        // Verify with correct chain IDs
        assertTrue(
            registry.isValidCrossChainPair(
                arkAddress,
                proxyAddress,
                differentSourceChain,
                differentTargetChain,
                ARK_FLEET_RELATIONSHIP
            )
        );

        // Should fail with wrong target chain
        assertFalse(
            registry.isValidCrossChainPair(
                arkAddress,
                proxyAddress,
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID, // Different target chain
                ARK_FLEET_RELATIONSHIP
            )
        );

        // Verify target chain ID in relationship data
        (address targetContract, uint16 chainId) = registry.getTargetForSource(
            arkAddress,
            ARK_FLEET_RELATIONSHIP
        );
        assertEq(targetContract, proxyAddress);
        assertEq(chainId, differentTargetChain);
    }

    function test_multipleRelationshipTypes() public {
        address arkAddress = makeAddr("ark");
        address proxy1 = makeAddr("proxy1");
        address proxy2 = makeAddr("proxy2");

        bytes32 arkFleetType = keccak256("ARK_FLEET");
        bytes32 bridgeType = keccak256("BRIDGE_ADAPTER");

        // Register ark with two different relationship types
        vm.prank(governor);
        registry.registerCrossChainRelationship(
            arkAddress,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            arkFleetType
        );

        vm.prank(governor);
        registry.registerCrossChainRelationship(
            arkAddress,
            proxy2,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            bridgeType
        );

        // Verify both relationships exist
        (address target1, uint16 chain1) = registry.getTargetForSource(
            arkAddress,
            arkFleetType
        );
        assertEq(target1, proxy1);
        assertEq(chain1, TARGET_CHAIN_ID);

        (address target2, uint16 chain2) = registry.getTargetForSource(
            arkAddress,
            bridgeType
        );
        assertEq(target2, proxy2);
        assertEq(chain2, TARGET_CHAIN_ID);

        // Check both are valid
        assertTrue(
            registry.isValidCrossChainPair(
                arkAddress,
                proxy1,
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                arkFleetType
            )
        );
        assertTrue(
            registry.isValidCrossChainPair(
                arkAddress,
                proxy2,
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                bridgeType
            )
        );

        // Check counts
        assertEq(registry.getRelationshipCount(arkFleetType), 1);
        assertEq(registry.getRelationshipCount(bridgeType), 1);
    }

    function test_unregistrationCleansUpCorrectly() public {
        address ark1 = makeAddr("ark1");
        address ark2 = makeAddr("ark2");
        address proxy1 = makeAddr("proxy1");
        address proxy2 = makeAddr("proxy2");

        // Register two relationships
        vm.prank(governor);
        registry.registerCrossChainRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );

        vm.prank(governor);
        registry.registerCrossChainRelationship(
            ark2,
            proxy2,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );

        assertEq(registry.getRelationshipCount(ARK_FLEET_RELATIONSHIP), 2);

        // Unregister first one
        vm.expectEmit(true, true, true, true);
        emit CrossChainRelationshipUnregistered(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );

        vm.prank(governor);
        registry.unregisterCrossChainRelationship(ark1, ARK_FLEET_RELATIONSHIP);

        // Verify first is gone, second remains
        assertEq(registry.getRelationshipCount(ARK_FLEET_RELATIONSHIP), 1);
        assertFalse(
            registry.isSourceContractRegistered(ark1, ARK_FLEET_RELATIONSHIP)
        );
        assertTrue(
            registry.isSourceContractRegistered(ark2, ARK_FLEET_RELATIONSHIP)
        );

        // Verify second relationship still works
        (address targetContract, uint16 chainId) = registry.getTargetForSource(
            ark2,
            ARK_FLEET_RELATIONSHIP
        );
        assertEq(targetContract, proxy2);
        assertEq(chainId, TARGET_CHAIN_ID);

        address sourceContract = registry.getSourceForTarget(
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy2,
            ARK_FLEET_RELATIONSHIP
        );
        assertEq(sourceContract, ark2);

        assertTrue(
            registry.isValidCrossChainPair(
                ark2,
                proxy2,
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                ARK_FLEET_RELATIONSHIP
            )
        );
    }

    function test_relationshipTypesAreIndependent() public {
        address arkAddress = makeAddr("ark");
        address proxyAddress = makeAddr("proxy");

        bytes32 type1 = keccak256("TYPE_1");
        bytes32 type2 = keccak256("TYPE_2");

        // Register same source-target pair with different types
        vm.prank(governor);
        registry.registerCrossChainRelationship(
            arkAddress,
            proxyAddress,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            type1
        );

        vm.prank(governor);
        registry.registerCrossChainRelationship(
            arkAddress,
            proxyAddress,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            type2
        );

        // Both should exist independently
        assertTrue(registry.isSourceContractRegistered(arkAddress, type1));
        assertTrue(registry.isSourceContractRegistered(arkAddress, type2));

        // Both should remain active since status update functionality was removed
        assertTrue(
            registry.isValidCrossChainPair(
                arkAddress,
                proxyAddress,
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                type1
            )
        );
        assertTrue(
            registry.isValidCrossChainPair(
                arkAddress,
                proxyAddress,
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                type2
            )
        );

        // Unregister one type
        vm.prank(governor);
        registry.unregisterCrossChainRelationship(arkAddress, type1);

        // Should only affect the specific type
        assertFalse(registry.isSourceContractRegistered(arkAddress, type1));
        assertTrue(registry.isSourceContractRegistered(arkAddress, type2));

        assertEq(registry.getRelationshipCount(type1), 0);
        assertEq(registry.getRelationshipCount(type2), 1);
    }

    function test_supportedRelationshipTypes() public {
        // Initially should have ARK_FLEET type pre-registered in constructor
        bytes32[] memory supportedTypes = registry
            .getSupportedRelationshipTypes();
        assertEq(supportedTypes.length, 1);
        assertEq(supportedTypes[0], keccak256("ARK_FLEET"));

        // Add a new relationship type by using it
        bytes32 newType = keccak256("NEW_TYPE");
        address arkAddress = makeAddr("ark");
        address proxyAddress = makeAddr("proxy");

        vm.prank(governor);
        registry.registerCrossChainRelationship(
            arkAddress,
            proxyAddress,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            newType
        );

        // Should now have 2 supported types
        supportedTypes = registry.getSupportedRelationshipTypes();
        assertEq(supportedTypes.length, 2);

        // Check both types are present (order may vary)
        bool hasArkFleet = false;
        bool hasNewType = false;
        for (uint i = 0; i < supportedTypes.length; i++) {
            if (supportedTypes[i] == keccak256("ARK_FLEET")) hasArkFleet = true;
            if (supportedTypes[i] == newType) hasNewType = true;
        }
        assertTrue(hasArkFleet);
        assertTrue(hasNewType);
    }
}
