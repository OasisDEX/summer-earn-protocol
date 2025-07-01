// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {CrossChainRegistry} from "../src/contracts/CrossChainRegistry.sol";
import {ICrossChainRegistry} from "../src/interfaces/ICrossChainRegistry.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";

contract CrossChainRegistryTest is Test {
    CrossChainRegistry public registry;
    ProtocolAccessManager public accessManager;

    address public governor = makeAddr("governor");
    address public keeper = makeAddr("keeper");
    address public user = makeAddr("user");

    // Test addresses
    address public ark1 = makeAddr("ark1");
    address public ark2 = makeAddr("ark2");
    address public ark3 = makeAddr("ark3");
    address public proxy1 = makeAddr("proxy1");
    address public proxy2 = makeAddr("proxy2");
    address public proxy3 = makeAddr("proxy3");

    uint16 public constant CURRENT_CHAIN_ID = 1;
    uint16 public constant TARGET_CHAIN_ID = 2;

    event CrossChainArkFleetProxyRegistered(
        address indexed crossChainArk,
        uint16 indexed sourceChainId,
        address indexed fleetProxy
    );

    event CrossChainArkFleetProxyUnregistered(
        address indexed crossChainArk,
        uint16 indexed sourceChainId,
        address indexed fleetProxy
    );

    event RelationshipStatusUpdated(
        address indexed crossChainArk,
        bool isActive
    );

    function setUp() public {
        // Deploy access manager
        accessManager = new ProtocolAccessManager(governor);

        // Deploy registry
        registry = new CrossChainRegistry(
            address(accessManager),
            CURRENT_CHAIN_ID
        );

        // Grant roles
        vm.prank(governor);
        accessManager.grantKeeperRole(address(registry), keeper);
    }

    /*//////////////////////////////////////////////////////////////
                           BASIC FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_deployment() public {
        assertEq(registry.currentChainId(), CURRENT_CHAIN_ID);
        assertEq(registry.getRelationshipCount(), 0);
    }

    function test_registerCrossChainArkFleetProxy() public {
        vm.expectEmit(true, true, true, true);
        emit CrossChainArkFleetProxyRegistered(ark1, CURRENT_CHAIN_ID, proxy1);

        vm.prank(governor);
        registry.registerCrossChainArkFleetProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );

        // Check relationship was created
        (address fleetProxy, uint16 chainId) = registry
            .getFleetProxyForCrossChainArk(ark1);
        assertEq(fleetProxy, proxy1);
        assertEq(chainId, TARGET_CHAIN_ID);

        // Check reverse mapping
        address crossChainArk = registry.getCrossChainArkForFleetProxy(
            CURRENT_CHAIN_ID,
            proxy1
        );
        assertEq(crossChainArk, ark1);

        // Check validation
        assertTrue(
            registry.isValidCrossChainArkFleetProxyPair(
                ark1,
                CURRENT_CHAIN_ID,
                proxy1
            )
        );
        assertTrue(registry.isCrossChainArkRegistered(ark1));

        // Check count
        assertEq(registry.getRelationshipCount(), 1);
    }

    function test_registerCrossChainArkFleetProxy_revertInvalidCrossChainArk()
        public
    {
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.InvalidCrossChainArk.selector,
                address(0)
            )
        );
        registry.registerCrossChainArkFleetProxy(
            address(0),
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );
    }

    function test_registerCrossChainArkFleetProxy_revertInvalidFleetProxy()
        public
    {
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.InvalidFleetProxy.selector,
                address(0)
            )
        );
        registry.registerCrossChainArkFleetProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            address(0)
        );
    }

    function test_registerCrossChainArkFleetProxy_revertInvalidChainId()
        public
    {
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.InvalidChainId.selector,
                0
            )
        );
        registry.registerCrossChainArkFleetProxy(
            ark1,
            0,
            TARGET_CHAIN_ID,
            proxy1
        );
    }

    function test_registerCrossChainArkFleetProxy_revertAlreadyExists() public {
        vm.prank(governor);
        registry.registerCrossChainArkFleetProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );

        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipAlreadyExists.selector,
                ark1,
                CURRENT_CHAIN_ID,
                proxy1
            )
        );
        registry.registerCrossChainArkFleetProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );
    }

    function test_registerCrossChainArkFleetProxy_revertFleetProxyAlreadyRegistered()
        public
    {
        vm.prank(governor);
        registry.registerCrossChainArkFleetProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );

        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.FleetProxyAlreadyRegistered.selector,
                proxy1,
                CURRENT_CHAIN_ID,
                ark1
            )
        );
        registry.registerCrossChainArkFleetProxy(
            ark2,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );
    }

    function test_registerCrossChainArkFleetProxy_onlyGovernor() public {
        vm.prank(user);
        vm.expectRevert();
        registry.registerCrossChainArkFleetProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );
    }

    function test_unregisterCrossChainArkFleetProxy() public {
        // First register
        vm.prank(governor);
        registry.registerCrossChainArkFleetProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );

        vm.expectEmit(true, true, true, true);
        emit CrossChainArkFleetProxyUnregistered(
            ark1,
            CURRENT_CHAIN_ID,
            proxy1
        );

        vm.prank(governor);
        registry.unregisterCrossChainArkFleetProxy(ark1);

        // Check relationship was removed
        assertFalse(registry.isCrossChainArkRegistered(ark1));
        assertEq(registry.getRelationshipCount(), 0);

        // Should revert when trying to access
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                ark1
            )
        );
        registry.getFleetProxyForCrossChainArk(ark1);
    }

    function test_unregisterCrossChainArkFleetProxy_revertNotExists() public {
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                ark1
            )
        );
        registry.unregisterCrossChainArkFleetProxy(ark1);
    }

    function test_unregisterCrossChainArkFleetProxy_onlyGovernor() public {
        vm.prank(governor);
        registry.registerCrossChainArkFleetProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );

        vm.prank(user);
        vm.expectRevert();
        registry.unregisterCrossChainArkFleetProxy(ark1);
    }

    function test_updateRelationshipStatus() public {
        // First register
        vm.prank(governor);
        registry.registerCrossChainArkFleetProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );

        // Check initially active
        assertTrue(
            registry.isValidCrossChainArkFleetProxyPair(
                ark1,
                CURRENT_CHAIN_ID,
                proxy1
            )
        );

        // Deactivate
        vm.expectEmit(true, false, false, true);
        emit RelationshipStatusUpdated(ark1, false);

        vm.prank(governor);
        registry.updateRelationshipStatus(ark1, false);

        // Check now inactive
        assertFalse(
            registry.isValidCrossChainArkFleetProxyPair(
                ark1,
                CURRENT_CHAIN_ID,
                proxy1
            )
        );

        // Reactivate
        vm.expectEmit(true, false, false, true);
        emit RelationshipStatusUpdated(ark1, true);

        vm.prank(governor);
        registry.updateRelationshipStatus(ark1, true);

        // Check active again
        assertTrue(
            registry.isValidCrossChainArkFleetProxyPair(
                ark1,
                CURRENT_CHAIN_ID,
                proxy1
            )
        );
    }

    function test_updateRelationshipStatus_revertNotExists() public {
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                ark1
            )
        );
        registry.updateRelationshipStatus(ark1, false);
    }

    function test_updateRelationshipStatus_onlyGovernor() public {
        vm.prank(governor);
        registry.registerCrossChainArkFleetProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );

        vm.prank(user);
        vm.expectRevert();
        registry.updateRelationshipStatus(ark1, false);
    }

    /*//////////////////////////////////////////////////////////////
                            QUERY FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getFleetProxyForCrossChainArk() public {
        vm.prank(governor);
        registry.registerCrossChainArkFleetProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );

        (address fleetProxy, uint16 chainId) = registry
            .getFleetProxyForCrossChainArk(ark1);
        assertEq(fleetProxy, proxy1);
        assertEq(chainId, TARGET_CHAIN_ID);
    }

    function test_getFleetProxyForCrossChainArk_revertNotExists() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                ark1
            )
        );
        registry.getFleetProxyForCrossChainArk(ark1);
    }

    function test_getCrossChainArkForFleetProxy() public {
        vm.prank(governor);
        registry.registerCrossChainArkFleetProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );

        address crossChainArk = registry.getCrossChainArkForFleetProxy(
            CURRENT_CHAIN_ID,
            proxy1
        );
        assertEq(crossChainArk, ark1);
    }

    function test_getCrossChainArkForFleetProxy_revertNotExists() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                proxy1
            )
        );
        registry.getCrossChainArkForFleetProxy(CURRENT_CHAIN_ID, proxy1);
    }

    function test_isValidCrossChainArkFleetProxyPair() public {
        // Should be false before registration
        assertFalse(
            registry.isValidCrossChainArkFleetProxyPair(
                ark1,
                CURRENT_CHAIN_ID,
                proxy1
            )
        );

        vm.prank(governor);
        registry.registerCrossChainArkFleetProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );

        // Should be true after registration
        assertTrue(
            registry.isValidCrossChainArkFleetProxyPair(
                ark1,
                CURRENT_CHAIN_ID,
                proxy1
            )
        );

        // Should be false for wrong combinations
        assertFalse(
            registry.isValidCrossChainArkFleetProxyPair(
                ark1,
                CURRENT_CHAIN_ID,
                proxy2
            )
        );
        assertFalse(
            registry.isValidCrossChainArkFleetProxyPair(
                ark2,
                CURRENT_CHAIN_ID,
                proxy1
            )
        );
        assertFalse(
            registry.isValidCrossChainArkFleetProxyPair(
                ark1,
                CURRENT_CHAIN_ID + 1,
                proxy1
            )
        );

        // Should be false when deactivated
        vm.prank(governor);
        registry.updateRelationshipStatus(ark1, false);
        assertFalse(
            registry.isValidCrossChainArkFleetProxyPair(
                ark1,
                CURRENT_CHAIN_ID,
                proxy1
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                        ENUMERATION FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getRegisteredCrossChainArks() public {
        address[] memory crossChainArks = registry
            .getRegisteredCrossChainArks();
        assertEq(crossChainArks.length, 0);

        vm.prank(governor);
        registry.registerCrossChainArkFleetProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );

        crossChainArks = registry.getRegisteredCrossChainArks();
        assertEq(crossChainArks.length, 1);
        assertEq(crossChainArks[0], ark1);

        vm.prank(governor);
        registry.registerCrossChainArkFleetProxy(
            ark2,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy2
        );

        crossChainArks = registry.getRegisteredCrossChainArks();
        assertEq(crossChainArks.length, 2);
        assertTrue(crossChainArks[0] == ark1 || crossChainArks[0] == ark2);
        assertTrue(crossChainArks[1] == ark1 || crossChainArks[1] == ark2);
        assertTrue(crossChainArks[0] != crossChainArks[1]);
    }

    function test_isCrossChainArkRegistered() public {
        assertFalse(registry.isCrossChainArkRegistered(ark1));

        vm.prank(governor);
        registry.registerCrossChainArkFleetProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );

        assertTrue(registry.isCrossChainArkRegistered(ark1));
        assertFalse(registry.isCrossChainArkRegistered(ark2));

        vm.prank(governor);
        registry.unregisterCrossChainArkFleetProxy(ark1);

        assertFalse(registry.isCrossChainArkRegistered(ark1));
    }

    function test_getRelationshipCount() public {
        assertEq(registry.getRelationshipCount(), 0);

        vm.prank(governor);
        registry.registerCrossChainArkFleetProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );
        assertEq(registry.getRelationshipCount(), 1);

        vm.prank(governor);
        registry.registerCrossChainArkFleetProxy(
            ark2,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy2
        );
        assertEq(registry.getRelationshipCount(), 2);

        vm.prank(governor);
        registry.unregisterCrossChainArkFleetProxy(ark1);
        assertEq(registry.getRelationshipCount(), 1);

        vm.prank(governor);
        registry.unregisterCrossChainArkFleetProxy(ark2);
        assertEq(registry.getRelationshipCount(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                            INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_multipleRegistrations() public {
        // Register multiple relationships
        vm.startPrank(governor);
        registry.registerCrossChainArkFleetProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );
        registry.registerCrossChainArkFleetProxy(
            ark2,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy2
        );
        registry.registerCrossChainArkFleetProxy(
            ark3,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy3
        );
        vm.stopPrank();

        // Check all relationships exist
        assertEq(registry.getRelationshipCount(), 3);
        assertTrue(registry.isCrossChainArkRegistered(ark1));
        assertTrue(registry.isCrossChainArkRegistered(ark2));
        assertTrue(registry.isCrossChainArkRegistered(ark3));

        // Check individual relationships
        (address fleetProxy, uint16 chainId) = registry
            .getFleetProxyForCrossChainArk(ark1);
        assertEq(fleetProxy, proxy1);
        assertEq(chainId, TARGET_CHAIN_ID);

        (fleetProxy, chainId) = registry.getFleetProxyForCrossChainArk(ark2);
        assertEq(fleetProxy, proxy2);
        assertEq(chainId, TARGET_CHAIN_ID);

        (fleetProxy, chainId) = registry.getFleetProxyForCrossChainArk(ark3);
        assertEq(fleetProxy, proxy3);
        assertEq(chainId, TARGET_CHAIN_ID);

        // Check reverse mappings
        assertEq(
            registry.getCrossChainArkForFleetProxy(CURRENT_CHAIN_ID, proxy1),
            ark1
        );
        assertEq(
            registry.getCrossChainArkForFleetProxy(CURRENT_CHAIN_ID, proxy2),
            ark2
        );
        assertEq(
            registry.getCrossChainArkForFleetProxy(CURRENT_CHAIN_ID, proxy3),
            ark3
        );

        // Check validations
        assertTrue(
            registry.isValidCrossChainArkFleetProxyPair(
                ark1,
                CURRENT_CHAIN_ID,
                proxy1
            )
        );
        assertTrue(
            registry.isValidCrossChainArkFleetProxyPair(
                ark2,
                CURRENT_CHAIN_ID,
                proxy2
            )
        );
        assertTrue(
            registry.isValidCrossChainArkFleetProxyPair(
                ark3,
                CURRENT_CHAIN_ID,
                proxy3
            )
        );
    }

    function test_registrationAndUnregistration() public {
        // Register
        vm.prank(governor);
        registry.registerCrossChainArkFleetProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );

        // Verify registration
        assertTrue(registry.isCrossChainArkRegistered(ark1));
        assertEq(registry.getRelationshipCount(), 1);

        // Unregister
        vm.prank(governor);
        registry.unregisterCrossChainArkFleetProxy(ark1);

        // Verify unregistration
        assertFalse(registry.isCrossChainArkRegistered(ark1));
        assertEq(registry.getRelationshipCount(), 0);

        // Should be able to register again
        vm.prank(governor);
        registry.registerCrossChainArkFleetProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );

        assertTrue(registry.isCrossChainArkRegistered(ark1));
        assertEq(registry.getRelationshipCount(), 1);
    }

    function test_statusManagement() public {
        // Register
        vm.prank(governor);
        registry.registerCrossChainArkFleetProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );

        // Initially active
        assertTrue(
            registry.isValidCrossChainArkFleetProxyPair(
                ark1,
                CURRENT_CHAIN_ID,
                proxy1
            )
        );

        // Deactivate
        vm.prank(governor);
        registry.updateRelationshipStatus(ark1, false);

        // Should be inactive but still registered
        assertTrue(registry.isCrossChainArkRegistered(ark1));
        assertFalse(
            registry.isValidCrossChainArkFleetProxyPair(
                ark1,
                CURRENT_CHAIN_ID,
                proxy1
            )
        );

        // Reactivate
        vm.prank(governor);
        registry.updateRelationshipStatus(ark1, true);

        // Should be active again
        assertTrue(
            registry.isValidCrossChainArkFleetProxyPair(
                ark1,
                CURRENT_CHAIN_ID,
                proxy1
            )
        );
    }
}
