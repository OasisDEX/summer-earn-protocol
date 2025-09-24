// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICrossChainRegistry} from "../../src/interfaces/ICrossChainRegistry.sol";
import {BaseCrossChainRegistryTest} from "../helpers/BaseCrossChainRegistry.t.sol";

contract CrossChainRegistryTest is BaseCrossChainRegistryTest {
    /*//////////////////////////////////////////////////////////////
                           BASIC FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_deployment() public view {
        assertEq(registry.currentChainId(), CURRENT_CHAIN_ID);
        assertEq(registry.getRelationshipCount(peerType), 0);
    }

    function test_registerRelationship_whenValid_emitsAndStores() public {
        vm.expectEmit(true, true, true, true, address(registry));
        emit CrossChainRelationshipRegistered(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            peerType
        );

        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            peerType
        );

        // Check relationship was created
        (address targetContract, uint16 chainId) = registry.getTargetForSource(
            ark1,
            peerType
        );
        assertEq(targetContract, proxy1);
        assertEq(chainId, TARGET_CHAIN_ID);

        // Check reverse mapping
        address sourceContract = registry.getSourceForTarget(
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1,
            peerType
        );
        assertEq(sourceContract, ark1);

        // Check validation
        assertTrue(
            registry.isValidCrossChainPair(
                ark1,
                proxy1,
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                peerType
            )
        );
        assertTrue(registry.isSourceContractRegistered(ark1, peerType));

        // Check count
        assertEq(registry.getRelationshipCount(peerType), 1);
    }

    function test_registerRelationship_whenSourceIsZero_reverts() public {
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
            peerType
        );
    }

    function test_registerRelationship_whenTargetIsZero_reverts() public {
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
            peerType
        );
    }

    function test_registerRelationship_whenSourceChainIsZero_reverts() public {
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
            peerType
        );
    }

    function test_registerRelationship_whenSourceAndTargetOnSameChain_succeeds()
        public
    {
        vm.expectEmit(true, true, true, true, address(registry));
        emit CrossChainRelationshipRegistered(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            CURRENT_CHAIN_ID,
            peerType
        );

        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            CURRENT_CHAIN_ID,
            peerType
        );

        (address tgt, uint16 chainId) = registry.getTargetForSource(
            ark1,
            peerType
        );
        assertEq(tgt, proxy1);
        assertEq(chainId, CURRENT_CHAIN_ID);
        assertTrue(
            registry.isValidCrossChainPair(
                ark1,
                proxy1,
                CURRENT_CHAIN_ID,
                CURRENT_CHAIN_ID,
                peerType
            )
        );
    }

    function test_registerRelationship_whenNeitherChainMatchesDeployment_reverts()
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
            peerType
        );
    }

    function test_registerRelationship_whenDeploymentChainIsTarget_succeeds()
        public
    {
        uint16 otherChain = 137; // Polygon

        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy1,
            otherChain,
            CURRENT_CHAIN_ID,
            peerType
        );

        // Verify relationship was created
        (address targetContract, uint16 chainId) = registry.getTargetForSource(
            ark1,
            peerType
        );
        assertEq(targetContract, proxy1);
        assertEq(chainId, CURRENT_CHAIN_ID);
    }

    function test_registerRelationship_whenDuplicate_reverts() public {
        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            peerType
        );

        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipAlreadyExists.selector,
                ark1,
                PEER_RELATIONSHIP,
                TARGET_CHAIN_ID
            )
        );
        registry.registerRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            peerType
        );
    }

    function test_registerRelationship_whenTargetAlreadyMapped_reverts()
        public
    {
        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            peerType
        );

        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.TargetContractAlreadyRegistered.selector,
                proxy1,
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                PEER_RELATIONSHIP,
                ark1
            )
        );
        registry.registerRelationship(
            ark2,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            peerType
        );
    }

    function test_registerRelationship_whenCallerNotGovernor_reverts() public {
        vm.prank(user);
        vm.expectRevert();
        registry.registerRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            peerType
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
            PEER_RELATIONSHIP
        );

        vm.expectEmit(true, true, true, true, address(registry));
        emit CrossChainRelationshipUnregistered(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            peerType
        );

        vm.prank(governor);
        registry.unregisterRelationship(ark1, peerType, TARGET_CHAIN_ID);

        // Check relationship was removed
        assertFalse(registry.isSourceContractRegistered(ark1, peerType));
        assertEq(registry.getRelationshipCount(peerType), 0);

        // Should revert when trying to access
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                ark1,
                PEER_RELATIONSHIP,
                0
            )
        );
        registry.getTargetForSource(ark1, peerType);
    }

    function test_unregisterCrossChainRelationship_revertNotExists() public {
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                ark1,
                peerType,
                TARGET_CHAIN_ID
            )
        );
        registry.unregisterRelationship(ark1, peerType, TARGET_CHAIN_ID);
    }

    function test_unregisterRelationship_whenCallerNotGovernor_reverts()
        public
    {
        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            peerType
        );

        vm.prank(user);
        vm.expectRevert();
        registry.unregisterRelationship(ark1, peerType, TARGET_CHAIN_ID);
    }

    function test_getTargetForSource() public {
        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            peerType
        );

        (address targetContract, uint16 chainId) = registry.getTargetForSource(
            ark1,
            peerType
        );
        assertEq(targetContract, proxy1);
        assertEq(chainId, TARGET_CHAIN_ID);
    }

    function test_getTargetForSource_revertNotExists() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                ark1,
                peerType,
                0
            )
        );
        registry.getTargetForSource(ark1, peerType);
    }

    function test_getSourceForTarget() public {
        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            peerType
        );

        address sourceContract = registry.getSourceForTarget(
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1,
            peerType
        );
        assertEq(sourceContract, ark1);
    }

    function test_getSourceForTarget_revertNotExists() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                address(0),
                peerType,
                TARGET_CHAIN_ID
            )
        );
        registry.getSourceForTarget(
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1,
            peerType
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
                peerType
            )
        );

        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            PEER_RELATIONSHIP
        );

        // Should be true after registration
        assertTrue(
            registry.isValidCrossChainPair(
                ark1,
                proxy1,
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                PEER_RELATIONSHIP
            )
        );

        // Should be false for wrong proxy
        assertFalse(
            registry.isValidCrossChainPair(
                ark1,
                proxy2,
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                peerType
            )
        );

        // Should be false for wrong source chain
        assertFalse(
            registry.isValidCrossChainPair(
                ark1,
                proxy1,
                TARGET_CHAIN_ID,
                TARGET_CHAIN_ID,
                peerType
            )
        );

        // Should be false for wrong target chain
        assertFalse(
            registry.isValidCrossChainPair(
                ark1,
                proxy1,
                CURRENT_CHAIN_ID,
                CURRENT_CHAIN_ID,
                peerType
            )
        );

        // Should be false for wrong ark
        assertFalse(
            registry.isValidCrossChainPair(
                ark2,
                proxy1,
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                peerType
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
            peerType
        );

        vm.prank(governor);
        registry.registerRelationship(
            ark2,
            proxy2,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            peerType
        );

        vm.prank(governor);
        registry.registerRelationship(
            ark3,
            proxy3,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            peerType
        );

        assertEq(registry.getRelationshipCount(peerType), 3);

        // Check first relationship
        (address targetContract, uint16 chainId) = registry.getTargetForSource(
            ark1,
            peerType
        );
        assertEq(targetContract, proxy1);
        assertEq(chainId, TARGET_CHAIN_ID);

        // Check second relationship
        (targetContract, chainId) = registry.getTargetForSource(ark2, peerType);
        assertEq(targetContract, proxy2);
        assertEq(chainId, TARGET_CHAIN_ID);

        // Check third relationship
        (targetContract, chainId) = registry.getTargetForSource(ark3, peerType);
        assertEq(targetContract, proxy3);
        assertEq(chainId, TARGET_CHAIN_ID);

        // Check reverse mappings
        assertEq(
            registry.getSourceForTarget(
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                proxy1,
                peerType
            ),
            ark1
        );
        assertEq(
            registry.getSourceForTarget(
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                proxy2,
                peerType
            ),
            ark2
        );
        assertEq(
            registry.getSourceForTarget(
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                proxy3,
                peerType
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
                peerType
            )
        );
        assertTrue(
            registry.isValidCrossChainPair(
                ark2,
                proxy2,
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                peerType
            )
        );
        assertTrue(
            registry.isValidCrossChainPair(
                ark3,
                proxy3,
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                peerType
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
            peerType
        );

        vm.prank(governor);
        registry.registerRelationship(
            ark2,
            proxy2,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            peerType
        );

        vm.prank(governor);
        registry.unregisterRelationship(ark1, peerType, TARGET_CHAIN_ID);

        assertEq(registry.getRelationshipCount(peerType), 1);
        assertFalse(registry.isSourceContractRegistered(ark1, peerType));
        assertTrue(registry.isSourceContractRegistered(ark2, peerType));
    }

    function test_reregisterAfterUnregister() public {
        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            peerType
        );

        vm.prank(governor);
        registry.unregisterRelationship(ark1, peerType, TARGET_CHAIN_ID);

        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy2,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            peerType
        );

        (address targetContract, uint16 chainId) = registry.getTargetForSource(
            ark1,
            peerType
        );
        assertEq(targetContract, proxy2);
        assertEq(chainId, TARGET_CHAIN_ID);
    }

    function test_multipleRelationshipTypes() public {
        bytes32 peerTypeLocal = keccak256("PEER_RELATIONSHIP");
        bytes32 executorTypeLocal = keccak256("EXECUTOR_RELATIONSHIP");

        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            peerTypeLocal
        );

        vm.prank(governor);
        registry.registerRelationship(
            ark1,
            proxy2,
            CURRENT_CHAIN_ID,
            CURRENT_CHAIN_ID,
            executorTypeLocal
        );

        // Check both relationships exist
        (address targetContract1, uint16 chainId1) = registry
            .getTargetForSource(ark1, peerTypeLocal);
        assertEq(targetContract1, proxy1);
        assertEq(chainId1, TARGET_CHAIN_ID);

        (address targetContract2, uint16 chainId2) = registry
            .getTargetForSource(ark1, executorTypeLocal);
        assertEq(targetContract2, proxy2);
        assertEq(chainId2, CURRENT_CHAIN_ID);

        // Check counts
        assertEq(registry.getRelationshipCount(peerTypeLocal), 1);
        assertEq(registry.getRelationshipCount(executorTypeLocal), 1);

        // Check supported types
        bytes32[] memory supportedTypes = registry
            .getSupportedRelationshipTypes();
        assertEq(supportedTypes.length, 2);
        // Note: The order might vary, so we check both types are present
        assertTrue(
            (supportedTypes[0] == peerType &&
                supportedTypes[1] == executorType) ||
                (supportedTypes[0] == executorType &&
                    supportedTypes[1] == peerType)
        );
    }

    /*//////////////////////////////////////////////////////////////
                        BRIDGE CONFIG TESTS
    //////////////////////////////////////////////////////////////*/

    function test_bridgeConfigInitialState() public view {
        assertEq(registry.bridgeRouter(), address(0));
    }

    function test_initializeBridgeConfiguration_revertUnauthorized() public {
        vm.prank(user);
        vm.expectRevert();
        registry.setBridgeRouter(mockBridgeRouter);
    }

    function test_initializeBridgeConfiguration_revertZeroBridgeRouter()
        public
    {
        vm.prank(governor);
        vm.expectRevert(ICrossChainRegistry.AddressZero.selector);
        registry.setBridgeRouter(address(0));
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

    function test_guardianCannotCallBridgeConfigSetters() public {
        _initializeBridgeConfig();

        vm.startPrank(guardian);

        vm.expectRevert();
        registry.setBridgeRouter(newMockBridgeRouter);

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

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _initializeBridgeConfig() internal {
        vm.startPrank(governor);
        registry.setBridgeRouter(mockBridgeRouter);
        vm.stopPrank();
    }

    function test_constructor() public view {
        // Test initial state after constructor
        assertEq(registry.bridgeRouter(), address(0));

        // Test that PEER_RELATIONSHIP and EXECUTOR_RELATIONSHIP relationship types are supported by default
        bytes32[] memory supportedTypes = registry
            .getSupportedRelationshipTypes();
        assertEq(supportedTypes.length, 2);

        // Check that both relationship types are present (order may vary)
        bool hasAdapterPeer = false;
        bool hasExecutor = false;

        for (uint256 i = 0; i < supportedTypes.length; i++) {
            if (supportedTypes[i] == keccak256("PEER_RELATIONSHIP")) {
                hasAdapterPeer = true;
            } else if (
                supportedTypes[i] == keccak256("EXECUTOR_RELATIONSHIP")
            ) {
                hasExecutor = true;
            }
        }

        assertTrue(
            hasAdapterPeer,
            "PEER_RELATIONSHIP relationship type not found"
        );
        assertTrue(
            hasExecutor,
            "EXECUTOR_RELATIONSHIP relationship type not found"
        );

        // Test that current chain ID is set correctly
        assertEq(registry.currentChainId(), CURRENT_CHAIN_ID);
    }

    /*─────────────────────────────────────────────────────────────────
        SOURCE-CHAIN RELATIONSHIP TESTS
    ─────────────────────────────────────────────────────────────────*/
    function test_registerSourceChainRelationship() public {
        bytes32 localRelationship = keccak256("LOCAL_REL");
        address src = makeAddr("localSrc");
        address dst = makeAddr("localDst");

        vm.prank(governor);
        registry.addSupportedRelationshipType(localRelationship);

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
