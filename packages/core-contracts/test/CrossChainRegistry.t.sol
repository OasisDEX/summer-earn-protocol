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

    event ArkProxyRegistered(
        address indexed ark,
        uint16 indexed targetChainId,
        address indexed proxy
    );

    event ArkProxyUnregistered(
        address indexed ark,
        uint16 indexed targetChainId,
        address indexed proxy
    );

    event RelationshipStatusUpdated(address indexed ark, bool isActive);

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

    function test_registerArkProxy() public {
        vm.expectEmit(true, true, true, true);
        emit ArkProxyRegistered(ark1, CURRENT_CHAIN_ID, proxy1);

        vm.prank(governor);
        registry.registerArkProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );

        // Check relationship was created
        (address proxy, uint16 chainId) = registry.getProxyForArk(ark1);
        assertEq(proxy, proxy1);
        assertEq(chainId, TARGET_CHAIN_ID);

        // Check reverse mapping
        address ark = registry.getArkForProxy(CURRENT_CHAIN_ID, proxy1);
        assertEq(ark, ark1);

        // Check validation
        assertTrue(
            registry.isValidArkProxyPair(ark1, CURRENT_CHAIN_ID, proxy1)
        );
        assertTrue(registry.isArkRegistered(ark1));

        // Check count
        assertEq(registry.getRelationshipCount(), 1);
    }

    function test_registerArkProxy_revertInvalidArk() public {
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.InvalidArk.selector,
                address(0)
            )
        );
        registry.registerArkProxy(
            address(0),
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );
    }

    function test_registerArkProxy_revertInvalidProxy() public {
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.InvalidProxy.selector,
                address(0)
            )
        );
        registry.registerArkProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            address(0)
        );
    }

    function test_registerArkProxy_revertInvalidChainId() public {
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.InvalidChainId.selector,
                0
            )
        );
        registry.registerArkProxy(ark1, 0, TARGET_CHAIN_ID, proxy1);
    }

    function test_registerArkProxy_revertAlreadyExists() public {
        vm.prank(governor);
        registry.registerArkProxy(
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
        registry.registerArkProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );
    }

    function test_registerArkProxy_revertProxyAlreadyRegistered() public {
        vm.prank(governor);
        registry.registerArkProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );

        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.ProxyAlreadyRegistered.selector,
                proxy1,
                CURRENT_CHAIN_ID,
                ark1
            )
        );
        registry.registerArkProxy(
            ark2,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );
    }

    function test_registerArkProxy_onlyGovernor() public {
        vm.prank(user);
        vm.expectRevert();
        registry.registerArkProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );
    }

    function test_unregisterArkProxy() public {
        // First register
        vm.prank(governor);
        registry.registerArkProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );

        vm.expectEmit(true, true, true, true);
        emit ArkProxyUnregistered(ark1, CURRENT_CHAIN_ID, proxy1);

        vm.prank(governor);
        registry.unregisterArkProxy(ark1);

        // Check relationship was removed
        assertFalse(registry.isArkRegistered(ark1));
        assertEq(registry.getRelationshipCount(), 0);

        // Should revert when trying to access
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                ark1
            )
        );
        registry.getProxyForArk(ark1);
    }

    function test_unregisterArkProxy_revertNotExists() public {
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                ark1
            )
        );
        registry.unregisterArkProxy(ark1);
    }

    function test_unregisterArkProxy_onlyGovernor() public {
        vm.prank(governor);
        registry.registerArkProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );

        vm.prank(user);
        vm.expectRevert();
        registry.unregisterArkProxy(ark1);
    }

    function test_updateRelationshipStatus() public {
        // First register
        vm.prank(governor);
        registry.registerArkProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );

        // Check initially active
        assertTrue(
            registry.isValidArkProxyPair(ark1, CURRENT_CHAIN_ID, proxy1)
        );

        // Deactivate
        vm.expectEmit(true, false, false, true);
        emit RelationshipStatusUpdated(ark1, false);

        vm.prank(governor);
        registry.updateRelationshipStatus(ark1, false);

        // Check now inactive
        assertFalse(
            registry.isValidArkProxyPair(ark1, CURRENT_CHAIN_ID, proxy1)
        );

        // Reactivate
        vm.expectEmit(true, false, false, true);
        emit RelationshipStatusUpdated(ark1, true);

        vm.prank(governor);
        registry.updateRelationshipStatus(ark1, true);

        // Check active again
        assertTrue(
            registry.isValidArkProxyPair(ark1, CURRENT_CHAIN_ID, proxy1)
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
        registry.registerArkProxy(
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

    function test_getProxyForArk() public {
        vm.prank(governor);
        registry.registerArkProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );

        (address proxy, uint16 chainId) = registry.getProxyForArk(ark1);
        assertEq(proxy, proxy1);
        assertEq(chainId, TARGET_CHAIN_ID);
    }

    function test_getProxyForArk_revertNotExists() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                ark1
            )
        );
        registry.getProxyForArk(ark1);
    }

    function test_getArkForProxy() public {
        vm.prank(governor);
        registry.registerArkProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );

        address ark = registry.getArkForProxy(CURRENT_CHAIN_ID, proxy1);
        assertEq(ark, ark1);
    }

    function test_getArkForProxy_revertNotExists() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                proxy1
            )
        );
        registry.getArkForProxy(CURRENT_CHAIN_ID, proxy1);
    }

    function test_isValidArkProxyPair() public {
        // Should be false before registration
        assertFalse(
            registry.isValidArkProxyPair(ark1, CURRENT_CHAIN_ID, proxy1)
        );

        vm.prank(governor);
        registry.registerArkProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );

        // Should be true after registration
        assertTrue(
            registry.isValidArkProxyPair(ark1, CURRENT_CHAIN_ID, proxy1)
        );

        // Should be false for wrong combinations
        assertFalse(
            registry.isValidArkProxyPair(ark1, CURRENT_CHAIN_ID, proxy2)
        );
        assertFalse(
            registry.isValidArkProxyPair(ark2, CURRENT_CHAIN_ID, proxy1)
        );
        assertFalse(
            registry.isValidArkProxyPair(ark1, CURRENT_CHAIN_ID + 1, proxy1)
        );

        // Should be false when deactivated
        vm.prank(governor);
        registry.updateRelationshipStatus(ark1, false);
        assertFalse(
            registry.isValidArkProxyPair(ark1, CURRENT_CHAIN_ID, proxy1)
        );
    }

    /*//////////////////////////////////////////////////////////////
                        ENUMERATION FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getRegisteredArks() public {
        address[] memory arks = registry.getRegisteredArks();
        assertEq(arks.length, 0);

        vm.prank(governor);
        registry.registerArkProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );

        arks = registry.getRegisteredArks();
        assertEq(arks.length, 1);
        assertEq(arks[0], ark1);

        vm.prank(governor);
        registry.registerArkProxy(
            ark2,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy2
        );

        arks = registry.getRegisteredArks();
        assertEq(arks.length, 2);
        assertTrue(arks[0] == ark1 || arks[0] == ark2);
        assertTrue(arks[1] == ark1 || arks[1] == ark2);
        assertTrue(arks[0] != arks[1]);
    }

    function test_isArkRegistered() public {
        assertFalse(registry.isArkRegistered(ark1));

        vm.prank(governor);
        registry.registerArkProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );

        assertTrue(registry.isArkRegistered(ark1));
        assertFalse(registry.isArkRegistered(ark2));

        vm.prank(governor);
        registry.unregisterArkProxy(ark1);

        assertFalse(registry.isArkRegistered(ark1));
    }

    function test_getRelationshipCount() public {
        assertEq(registry.getRelationshipCount(), 0);

        vm.prank(governor);
        registry.registerArkProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );
        assertEq(registry.getRelationshipCount(), 1);

        vm.prank(governor);
        registry.registerArkProxy(
            ark2,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy2
        );
        assertEq(registry.getRelationshipCount(), 2);

        vm.prank(governor);
        registry.unregisterArkProxy(ark1);
        assertEq(registry.getRelationshipCount(), 1);

        vm.prank(governor);
        registry.unregisterArkProxy(ark2);
        assertEq(registry.getRelationshipCount(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                            INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_multipleRegistrations() public {
        // Register multiple relationships
        vm.startPrank(governor);
        registry.registerArkProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );
        registry.registerArkProxy(
            ark2,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy2
        );
        registry.registerArkProxy(
            ark3,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy3
        );
        vm.stopPrank();

        // Check all relationships exist
        assertEq(registry.getRelationshipCount(), 3);
        assertTrue(registry.isArkRegistered(ark1));
        assertTrue(registry.isArkRegistered(ark2));
        assertTrue(registry.isArkRegistered(ark3));

        // Check individual relationships
        (address proxy, uint16 chainId) = registry.getProxyForArk(ark1);
        assertEq(proxy, proxy1);
        assertEq(chainId, TARGET_CHAIN_ID);

        (proxy, chainId) = registry.getProxyForArk(ark2);
        assertEq(proxy, proxy2);
        assertEq(chainId, TARGET_CHAIN_ID);

        (proxy, chainId) = registry.getProxyForArk(ark3);
        assertEq(proxy, proxy3);
        assertEq(chainId, TARGET_CHAIN_ID);

        // Check reverse mappings
        assertEq(registry.getArkForProxy(CURRENT_CHAIN_ID, proxy1), ark1);
        assertEq(registry.getArkForProxy(CURRENT_CHAIN_ID, proxy2), ark2);
        assertEq(registry.getArkForProxy(CURRENT_CHAIN_ID, proxy3), ark3);

        // Check validations
        assertTrue(
            registry.isValidArkProxyPair(ark1, CURRENT_CHAIN_ID, proxy1)
        );
        assertTrue(
            registry.isValidArkProxyPair(ark2, CURRENT_CHAIN_ID, proxy2)
        );
        assertTrue(
            registry.isValidArkProxyPair(ark3, CURRENT_CHAIN_ID, proxy3)
        );
    }

    function test_registrationAndUnregistration() public {
        // Register
        vm.prank(governor);
        registry.registerArkProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );

        // Verify registration
        assertTrue(registry.isArkRegistered(ark1));
        assertEq(registry.getRelationshipCount(), 1);

        // Unregister
        vm.prank(governor);
        registry.unregisterArkProxy(ark1);

        // Verify unregistration
        assertFalse(registry.isArkRegistered(ark1));
        assertEq(registry.getRelationshipCount(), 0);

        // Should be able to register again
        vm.prank(governor);
        registry.registerArkProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );

        assertTrue(registry.isArkRegistered(ark1));
        assertEq(registry.getRelationshipCount(), 1);
    }

    function test_statusManagement() public {
        // Register
        vm.prank(governor);
        registry.registerArkProxy(
            ark1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxy1
        );

        // Initially active
        assertTrue(
            registry.isValidArkProxyPair(ark1, CURRENT_CHAIN_ID, proxy1)
        );

        // Deactivate
        vm.prank(governor);
        registry.updateRelationshipStatus(ark1, false);

        // Should be inactive but still registered
        assertTrue(registry.isArkRegistered(ark1));
        assertFalse(
            registry.isValidArkProxyPair(ark1, CURRENT_CHAIN_ID, proxy1)
        );

        // Reactivate
        vm.prank(governor);
        registry.updateRelationshipStatus(ark1, true);

        // Should be active again
        assertTrue(
            registry.isValidArkProxyPair(ark1, CURRENT_CHAIN_ID, proxy1)
        );
    }
}
