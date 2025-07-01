// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/contracts/CrossChainRegistry.sol";
import "../src/interfaces/ICrossChainRegistry.sol";
import "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";

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
                           BASIC FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_deployment() public {
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
        registry.registerCrossChainRelationship(
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
        registry.registerCrossChainRelationship(
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
        registry.registerCrossChainRelationship(
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
        registry.registerCrossChainRelationship(
            ark1,
            proxy1,
            0,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );
    }

    function test_registerCrossChainRelationship_revertSameChainRelationship()
        public
    {
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.SameChainRelationship.selector,
                CURRENT_CHAIN_ID
            )
        );
        registry.registerCrossChainRelationship(
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
        registry.registerCrossChainRelationship(
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
        registry.registerCrossChainRelationship(
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
        registry.registerCrossChainRelationship(
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
                ARK_FLEET_RELATIONSHIP
            )
        );
        registry.registerCrossChainRelationship(
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
        registry.registerCrossChainRelationship(
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
        registry.registerCrossChainRelationship(
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
        registry.registerCrossChainRelationship(
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
        registry.registerCrossChainRelationship(
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
        registry.unregisterCrossChainRelationship(ark1, ARK_FLEET_RELATIONSHIP);

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
                ARK_FLEET_RELATIONSHIP
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
                ARK_FLEET_RELATIONSHIP
            )
        );
        registry.unregisterCrossChainRelationship(ark1, ARK_FLEET_RELATIONSHIP);
    }

    function test_unregisterCrossChainRelationship_onlyGovernor() public {
        vm.prank(governor);
        registry.registerCrossChainRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );

        vm.prank(user);
        vm.expectRevert();
        registry.unregisterCrossChainRelationship(ark1, ARK_FLEET_RELATIONSHIP);
    }

    function test_getTargetForSource() public {
        vm.prank(governor);
        registry.registerCrossChainRelationship(
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
                ARK_FLEET_RELATIONSHIP
            )
        );
        registry.getTargetForSource(ark1, ARK_FLEET_RELATIONSHIP);
    }

    function test_getSourceForTarget() public {
        vm.prank(governor);
        registry.registerCrossChainRelationship(
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
                proxy1,
                ARK_FLEET_RELATIONSHIP
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
        registry.registerCrossChainRelationship(
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

        vm.prank(governor);
        registry.registerCrossChainRelationship(
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

        vm.prank(governor);
        registry.unregisterCrossChainRelationship(ark1, ARK_FLEET_RELATIONSHIP);

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
        registry.registerCrossChainRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            ARK_FLEET_RELATIONSHIP
        );

        vm.prank(governor);
        registry.unregisterCrossChainRelationship(ark1, ARK_FLEET_RELATIONSHIP);

        vm.prank(governor);
        registry.registerCrossChainRelationship(
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
        bytes32 arkFleetType = keccak256("ARK_FLEET");
        bytes32 bridgeType = keccak256("BRIDGE_ADAPTER");

        vm.prank(governor);
        registry.registerCrossChainRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            arkFleetType
        );

        vm.prank(governor);
        registry.registerCrossChainRelationship(
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
        assertEq(supportedTypes.length, 2);
        // Note: The order might vary, so we check both types are present
        assertTrue(
            (supportedTypes[0] == arkFleetType &&
                supportedTypes[1] == bridgeType) ||
                (supportedTypes[0] == bridgeType &&
                    supportedTypes[1] == arkFleetType)
        );
    }
}
