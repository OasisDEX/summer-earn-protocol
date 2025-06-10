// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {CrossChainRegistry} from "../src/contracts/CrossChainRegistry.sol";
import {ICrossChainRegistry} from "../src/interfaces/ICrossChainRegistry.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";

contract CrossChainRegistryTest is Test {
    CrossChainRegistry public registry;
    ProtocolAccessManager public accessManager;

    address public governor = address(0x1);
    address public keeper = address(0x2);
    address public user = address(0x3);
    address public testAdmin = address(0x4);

    address public arkAddress = address(0x100);
    address public proxyAddress = address(0x200);
    uint16 public constant TARGET_CHAIN_ID = 42161; // Arbitrum
    uint16 public constant CURRENT_CHAIN_ID = 1; // Ethereum

    string public constant DESCRIPTION = "Test ark-proxy relationship";

    function setUp() public {
        // Deploy real access manager
        accessManager = new ProtocolAccessManager(testAdmin);

        // Grant governor role
        vm.prank(testAdmin);
        accessManager.grantGovernorRole(governor);

        // Deploy registry
        registry = new CrossChainRegistry(
            address(accessManager),
            CURRENT_CHAIN_ID
        );
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function testConstructor() public {
        assertEq(registry.currentChainId(), CURRENT_CHAIN_ID);
        assertEq(registry.getRelationshipCount(), 0);
    }

    function testConstructorRevertsOnZeroChainId() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.InvalidChainId.selector,
                0
            )
        );
        new CrossChainRegistry(address(accessManager), 0);
    }

    /*//////////////////////////////////////////////////////////////
                          REGISTRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testRegisterArkProxy() public {
        vm.startPrank(governor);

        // Register ark-proxy relationship
        vm.expectEmit(true, true, true, true);
        emit ICrossChainRegistry.ArkProxyRegistered(
            arkAddress,
            TARGET_CHAIN_ID,
            proxyAddress,
            governor
        );

        registry.registerArkProxy(
            arkAddress,
            TARGET_CHAIN_ID,
            proxyAddress,
            DESCRIPTION
        );

        // Verify relationship is stored correctly
        (address retrievedProxy, uint16 retrievedChainId) = registry
            .getProxyForArk(arkAddress);
        assertEq(retrievedProxy, proxyAddress);
        assertEq(retrievedChainId, TARGET_CHAIN_ID);

        // Verify reverse mapping
        address retrievedArk = registry.getArkForProxy(
            CURRENT_CHAIN_ID,
            proxyAddress
        );
        assertEq(retrievedArk, arkAddress);

        // Verify metadata
        ICrossChainRegistry.RelationshipMetadata memory metadata = registry
            .getRelationshipMetadata(arkAddress);
        assertEq(metadata.description, DESCRIPTION);
        assertEq(metadata.creator, governor);
        assertGt(metadata.createdAt, 0);

        // Verify enumeration
        assertEq(registry.getRelationshipCount(), 1);
        address[] memory arks = registry.getRegisteredArks();
        assertEq(arks.length, 1);
        assertEq(arks[0], arkAddress);

        address[] memory proxies = registry.getRegisteredProxies(
            TARGET_CHAIN_ID
        );
        assertEq(proxies.length, 1);
        assertEq(proxies[0], proxyAddress);

        vm.stopPrank();
    }

    function testRegisterArkProxyRevertsOnInvalidInputs() public {
        vm.startPrank(governor);

        // Test invalid ark address
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.InvalidArk.selector,
                address(0)
            )
        );
        registry.registerArkProxy(
            address(0),
            TARGET_CHAIN_ID,
            proxyAddress,
            DESCRIPTION
        );

        // Test invalid proxy address
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.InvalidProxy.selector,
                address(0)
            )
        );
        registry.registerArkProxy(
            arkAddress,
            TARGET_CHAIN_ID,
            address(0),
            DESCRIPTION
        );

        // Test invalid chain ID
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.InvalidChainId.selector,
                0
            )
        );
        registry.registerArkProxy(arkAddress, 0, proxyAddress, DESCRIPTION);

        vm.stopPrank();
    }

    function testRegisterArkProxyRevertsOnDuplicateArk() public {
        vm.startPrank(governor);

        // Register first relationship
        registry.registerArkProxy(
            arkAddress,
            TARGET_CHAIN_ID,
            proxyAddress,
            DESCRIPTION
        );

        // Try to register same ark again
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipAlreadyExists.selector,
                arkAddress,
                TARGET_CHAIN_ID,
                proxyAddress
            )
        );
        registry.registerArkProxy(
            arkAddress,
            TARGET_CHAIN_ID + 1,
            address(0x300),
            "Different description"
        );

        vm.stopPrank();
    }

    function testRegisterArkProxyRevertsOnDuplicateProxy() public {
        vm.startPrank(governor);

        // Register first relationship
        registry.registerArkProxy(
            arkAddress,
            TARGET_CHAIN_ID,
            proxyAddress,
            DESCRIPTION
        );

        // Try to register same proxy to different ark
        address secondArk = address(0x101);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.ProxyAlreadyRegistered.selector,
                proxyAddress,
                TARGET_CHAIN_ID,
                arkAddress
            )
        );
        registry.registerArkProxy(
            secondArk,
            TARGET_CHAIN_ID,
            proxyAddress,
            "Different description"
        );

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                          UNREGISTRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testUnregisterArkProxy() public {
        vm.startPrank(governor);

        // First register a relationship
        registry.registerArkProxy(
            arkAddress,
            TARGET_CHAIN_ID,
            proxyAddress,
            DESCRIPTION
        );

        // Verify it exists
        assertEq(registry.getRelationshipCount(), 1);
        assertTrue(registry.isArkRegistered(arkAddress));

        // Unregister
        vm.expectEmit(true, true, true, true);
        emit ICrossChainRegistry.ArkProxyUnregistered(
            arkAddress,
            TARGET_CHAIN_ID,
            proxyAddress
        );

        registry.unregisterArkProxy(arkAddress);

        // Verify it's removed
        assertEq(registry.getRelationshipCount(), 0);
        assertFalse(registry.isArkRegistered(arkAddress));

        // Verify arrays are updated
        address[] memory arks = registry.getRegisteredArks();
        assertEq(arks.length, 0);

        address[] memory proxies = registry.getRegisteredProxies(
            TARGET_CHAIN_ID
        );
        assertEq(proxies.length, 0);

        vm.stopPrank();
    }

    function testUnregisterArkProxyRevertsOnNonExistentArk() public {
        vm.startPrank(governor);

        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                arkAddress
            )
        );
        registry.unregisterArkProxy(arkAddress);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            STATUS UPDATE TESTS
    //////////////////////////////////////////////////////////////*/

    function testUpdateRelationshipStatus() public {
        vm.startPrank(governor);

        // Register relationship
        registry.registerArkProxy(
            arkAddress,
            TARGET_CHAIN_ID,
            proxyAddress,
            DESCRIPTION
        );

        // Verify it's initially active
        assertTrue(
            registry.isValidArkProxyPair(
                arkAddress,
                TARGET_CHAIN_ID,
                proxyAddress
            )
        );

        // Deactivate
        vm.expectEmit(true, true, true, true);
        emit ICrossChainRegistry.RelationshipStatusUpdated(
            arkAddress,
            TARGET_CHAIN_ID,
            proxyAddress,
            false
        );

        registry.updateRelationshipStatus(arkAddress, false);

        // Verify it's now inactive
        assertFalse(
            registry.isValidArkProxyPair(
                arkAddress,
                TARGET_CHAIN_ID,
                proxyAddress
            )
        );

        // Reactivate
        registry.updateRelationshipStatus(arkAddress, true);
        assertTrue(
            registry.isValidArkProxyPair(
                arkAddress,
                TARGET_CHAIN_ID,
                proxyAddress
            )
        );

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testIsValidArkProxyPair() public {
        vm.startPrank(governor);

        // Register relationship
        registry.registerArkProxy(
            arkAddress,
            TARGET_CHAIN_ID,
            proxyAddress,
            DESCRIPTION
        );

        // Test valid pair
        assertTrue(
            registry.isValidArkProxyPair(
                arkAddress,
                TARGET_CHAIN_ID,
                proxyAddress
            )
        );

        // Test invalid combinations
        assertFalse(
            registry.isValidArkProxyPair(
                address(0x999),
                TARGET_CHAIN_ID,
                proxyAddress
            )
        );
        assertFalse(
            registry.isValidArkProxyPair(
                arkAddress,
                TARGET_CHAIN_ID + 1,
                proxyAddress
            )
        );
        assertFalse(
            registry.isValidArkProxyPair(
                arkAddress,
                TARGET_CHAIN_ID,
                address(0x999)
            )
        );

        vm.stopPrank();
    }

    function testIsRegisteredFunctions() public {
        vm.startPrank(governor);

        // Initially not registered
        assertFalse(registry.isArkRegistered(arkAddress));
        assertFalse(registry.isProxyRegistered(proxyAddress, TARGET_CHAIN_ID));

        // Register relationship
        registry.registerArkProxy(
            arkAddress,
            TARGET_CHAIN_ID,
            proxyAddress,
            DESCRIPTION
        );

        // Now registered
        assertTrue(registry.isArkRegistered(arkAddress));
        assertTrue(registry.isProxyRegistered(proxyAddress, CURRENT_CHAIN_ID));

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL TESTS
    //////////////////////////////////////////////////////////////*/

    function testOnlyGovernorCanRegister() public {
        vm.startPrank(user);

        vm.expectRevert(); // Should revert due to access control
        registry.registerArkProxy(
            arkAddress,
            TARGET_CHAIN_ID,
            proxyAddress,
            DESCRIPTION
        );

        vm.stopPrank();
    }

    function testOnlyGovernorCanUnregister() public {
        // First register as governor
        vm.prank(governor);
        registry.registerArkProxy(
            arkAddress,
            TARGET_CHAIN_ID,
            proxyAddress,
            DESCRIPTION
        );

        // Try to unregister as user
        vm.startPrank(user);

        vm.expectRevert(); // Should revert due to access control
        registry.unregisterArkProxy(arkAddress);

        vm.stopPrank();
    }

    function testOnlyGovernorCanUpdateStatus() public {
        // First register as governor
        vm.prank(governor);
        registry.registerArkProxy(
            arkAddress,
            TARGET_CHAIN_ID,
            proxyAddress,
            DESCRIPTION
        );

        // Try to update status as user
        vm.startPrank(user);

        vm.expectRevert(); // Should revert due to access control
        registry.updateRelationshipStatus(arkAddress, false);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            ENUMERATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testMultipleRegistrations() public {
        vm.startPrank(governor);

        address ark1 = address(0x100);
        address ark2 = address(0x101);
        address proxy1 = address(0x200);
        address proxy2 = address(0x201);
        uint16 chain1 = 42161;
        uint16 chain2 = 137;

        // Register multiple relationships
        registry.registerArkProxy(ark1, chain1, proxy1, "First relationship");
        registry.registerArkProxy(ark2, chain2, proxy2, "Second relationship");

        // Check total count
        assertEq(registry.getRelationshipCount(), 2);

        // Check arks enumeration
        address[] memory arks = registry.getRegisteredArks();
        assertEq(arks.length, 2);
        assertTrue(arks[0] == ark1 || arks[1] == ark1);
        assertTrue(arks[0] == ark2 || arks[1] == ark2);

        // Check proxies enumeration by chain
        address[] memory proxiesChain1 = registry.getRegisteredProxies(chain1);
        assertEq(proxiesChain1.length, 1);
        assertEq(proxiesChain1[0], proxy1);

        address[] memory proxiesChain2 = registry.getRegisteredProxies(chain2);
        assertEq(proxiesChain2.length, 1);
        assertEq(proxiesChain2[0], proxy2);

        vm.stopPrank();
    }
}
