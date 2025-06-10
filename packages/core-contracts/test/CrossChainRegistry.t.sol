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

    string public constant DEFAULT_DESCRIPTION = "Test relationship";

    event ArkProxyRegistered(
        address indexed ark,
        uint16 indexed targetChainId,
        address indexed proxy,
        address creator
    );

    event ArkProxyUnregistered(
        address indexed ark,
        uint16 indexed targetChainId,
        address indexed proxy
    );

    event RelationshipStatusUpdated(
        address indexed ark,
        uint16 indexed targetChainId,
        address indexed proxy,
        bool isActive
    );

    event RelationshipStatusChanged(
        address indexed ark,
        uint16 indexed targetChainId,
        address indexed proxy,
        ICrossChainRegistry.RelationshipStatus oldStatus,
        ICrossChainRegistry.RelationshipStatus newStatus
    );

    event RelationshipMetadataUpdated(
        address indexed ark,
        string description,
        bytes32 configHash
    );

    event BatchRegistrationCompleted(uint256 count, address indexed actor);

    event RelationshipActionRecorded(
        address indexed ark,
        ICrossChainRegistry.RelationshipAction indexed action,
        address indexed actor
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

        // Deploy mock contracts for validation
        vm.etch(
            ark1,
            hex"608060405234801561001057600080fd5b50600436106100575760003560e01c80638da5cb5b1461005c578063a41368620461007a578063f2fde38b14610080575b600080fd5b6100646100a3565b60405161007191906100d4565b60405180910390f35b50600190565b61009361008e3660046100ef565b505050505050565b005b600061009e6100a3565b905090565b60006100ae6100a3565b905090565b600073ffffffffffffffffffffffffffffffffffffffff82169050919050565b60006100de826100b3565b9050919050565b6100ee816100d3565b82525050565b60006020828403121561010657610105610122565b5b6000610114848285016100e5565b91505092915050565b600080fd5b50565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052602260045260246000fdfea264697066735822"
        );
        vm.etch(
            ark2,
            hex"608060405234801561001057600080fd5b50600436106100575760003560e01c80638da5cb5b1461005c578063a41368620461007a578063f2fde38b14610080575b600080fd5b6100646100a3565b60405161007191906100d4565b60405180910390f35b50600190565b61009361008e3660046100ef565b505050505050565b005b600061009e6100a3565b905090565b60006100ae6100a3565b905090565b600073ffffffffffffffffffffffffffffffffffffffff82169050919050565b60006100de826100b3565b9050919050565b6100ee816100d3565b82525050565b60006020828403121561010657610105610122565b5b6000610114848285016100e5565b91505092915050565b600080fd5b50565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052602260045260246000fdfea264697066735822"
        );
        vm.etch(
            ark3,
            hex"608060405234801561001057600080fd5b50600436106100575760003560e01c80638da5cb5b1461005c578063a41368620461007a578763f2fde38b14610080575b600080fd5b6100646100a3565b60405161007191906100d4565b60405180910390f35b50600190565b61009361008e3660046100ef565b505050505050565b005b600061009e6100a3565b905090565b60006100ae6100a3565b905090565b600073ffffffffffffffffffffffffffffffffffffffff82169050919050565b60006100de826100b3565b9050919050565b6100ee816100d3565b82525050565b60006020828403121561010657610105610122565b5b6000610114848285016100e5565b91505092915050565b600080fd5b50565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052602260045260246000fdfea264697066735822"
        );
        vm.etch(
            proxy1,
            hex"608060405234801561001057600080fd5b50600436106100575760003560e01c80638da5cb5b1461005c578063a41368620461007a578063f2fde38b14610080575b600080fd5b6100646100a3565b60405161007191906100d4565b60405180910390f35b50600190565b61009361008e3660046100ef565b505050505050565b005b600061009e6100a3565b905090565b60006100ae6100a3565b905090565b600073ffffffffffffffffffffffffffffffffffffffff82169050919050565b60006100de826100b3565b9050919050565b6100ee816100d3565b82525050565b60006020828403121561010657610105610122565b5b6000610114848285016100e5565b91505092915050565b600080fd5b50565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052602260045260246000fdfea264697066735822"
        );
        vm.etch(
            proxy2,
            hex"608060405234801561001057600080fd5b50600436106100575760003560e01c80638da5cb5b1461005c578063a41368620461007a578063f2fde38b14610080575b600080fd5b6100646100a3565b60405161007191906100d4565b60405180910390f35b50600190565b61009361008e3660046100ef565b505050505050565b005b600061009e6100a3565b905090565b60006100ae6100a3565b905090565b600073ffffffffffffffffffffffffffffffffffffffff82169050919050565b60006100de826100b3565b9050919050565b6100ee816100d3565b82525050565b60006020828403121561010657610105610122565b5b6000610114848285016100e5565b91505092915050565b600080fd5b50565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052602260045260246000fdfea264697066735822"
        );
        vm.etch(
            proxy3,
            hex"608060405234801561001057600080fd5b50600436106100575760003560e01c80638da5cb5b1461005c578063a41368620461007a578063f2fde38b14610080575b600080fd5b6100646100a3565b60405161007191906100d4565b60405180910390f35b50600190565b61009361008e3660046100ef565b505050505050565b005b600061009e6100a3565b905090565b60006100ae6100a3565b905090565b600073ffffffffffffffffffffffffffffffffffffffff82169050919050565b60006100de826100b3565b9050919050565b6100ee816100d3565b82525050565b60006020828403121561010657610105610122565b5b6000610114848285016100e5565b91505092915050565b600080fd5b50565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052602260045260246000fdfea264697066735822"
        );
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
        emit ArkProxyRegistered(ark1, TARGET_CHAIN_ID, proxy1, governor);

        vm.expectEmit(true, true, true, false);
        emit RelationshipActionRecorded(
            ark1,
            ICrossChainRegistry.RelationshipAction.CREATED,
            governor
        );

        vm.prank(governor);
        registry.registerArkProxy(
            ark1,
            TARGET_CHAIN_ID,
            proxy1,
            DEFAULT_DESCRIPTION
        );

        // Check relationship was created
        (address proxy, uint16 chainId) = registry.getProxyForArk(ark1);
        assertEq(proxy, proxy1);
        assertEq(chainId, TARGET_CHAIN_ID);

        // Check reverse mapping
        address ark = registry.getArkForProxy(CURRENT_CHAIN_ID, proxy1);
        assertEq(ark, ark1);

        // Check validation
        assertTrue(registry.isValidArkProxyPair(ark1, TARGET_CHAIN_ID, proxy1));
        assertTrue(registry.isArkRegistered(ark1));
        assertTrue(registry.isProxyRegistered(proxy1, CURRENT_CHAIN_ID));

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
            TARGET_CHAIN_ID,
            proxy1,
            DEFAULT_DESCRIPTION
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
            TARGET_CHAIN_ID,
            address(0),
            DEFAULT_DESCRIPTION
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
        registry.registerArkProxy(ark1, 0, proxy1, DEFAULT_DESCRIPTION);
    }

    function test_registerArkProxy_revertRelationshipAlreadyExists() public {
        vm.prank(governor);
        registry.registerArkProxy(
            ark1,
            TARGET_CHAIN_ID,
            proxy1,
            DEFAULT_DESCRIPTION
        );

        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipAlreadyExists.selector,
                ark1,
                TARGET_CHAIN_ID,
                proxy2
            )
        );
        registry.registerArkProxy(
            ark1,
            TARGET_CHAIN_ID,
            proxy2,
            "Different proxy"
        );
    }

    function test_registerArkProxy_revertProxyAlreadyRegistered() public {
        vm.prank(governor);
        registry.registerArkProxy(
            ark1,
            TARGET_CHAIN_ID,
            proxy1,
            DEFAULT_DESCRIPTION
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
            TARGET_CHAIN_ID,
            proxy1,
            "Different ark"
        );
    }

    function test_registerArkProxy_revertUnauthorized() public {
        vm.prank(user);
        vm.expectRevert();
        registry.registerArkProxy(
            ark1,
            TARGET_CHAIN_ID,
            proxy1,
            DEFAULT_DESCRIPTION
        );
    }

    function test_unregisterArkProxy() public {
        // First register
        vm.prank(governor);
        registry.registerArkProxy(
            ark1,
            TARGET_CHAIN_ID,
            proxy1,
            DEFAULT_DESCRIPTION
        );

        vm.expectEmit(true, true, true, true);
        emit ArkProxyUnregistered(ark1, TARGET_CHAIN_ID, proxy1);

        vm.expectEmit(true, true, true, false);
        emit RelationshipActionRecorded(
            ark1,
            ICrossChainRegistry.RelationshipAction.DELETED,
            governor
        );

        vm.prank(governor);
        registry.unregisterArkProxy(ark1);

        // Check relationship was removed
        assertFalse(registry.isArkRegistered(ark1));
        assertFalse(registry.isProxyRegistered(proxy1, CURRENT_CHAIN_ID));
        assertEq(registry.getRelationshipCount(), 0);
    }

    function test_unregisterArkProxy_revertRelationshipDoesNotExist() public {
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                ark1
            )
        );
        registry.unregisterArkProxy(ark1);
    }

    function test_updateRelationshipStatus() public {
        // Register first
        vm.prank(governor);
        registry.registerArkProxy(
            ark1,
            TARGET_CHAIN_ID,
            proxy1,
            DEFAULT_DESCRIPTION
        );

        // Deactivate
        vm.expectEmit(true, true, true, true);
        emit RelationshipStatusChanged(
            ark1,
            TARGET_CHAIN_ID,
            proxy1,
            ICrossChainRegistry.RelationshipStatus.ACTIVE,
            ICrossChainRegistry.RelationshipStatus.INACTIVE
        );

        vm.expectEmit(true, true, true, true);
        emit RelationshipStatusUpdated(ark1, TARGET_CHAIN_ID, proxy1, false);

        vm.expectEmit(true, true, true, false);
        emit RelationshipActionRecorded(
            ark1,
            ICrossChainRegistry.RelationshipAction.DEACTIVATED,
            governor
        );

        vm.prank(governor);
        registry.updateRelationshipStatus(ark1, false);

        // Check status was updated
        assertFalse(
            registry.isValidArkProxyPair(ark1, TARGET_CHAIN_ID, proxy1)
        );

        // Reactivate
        vm.prank(governor);
        registry.updateRelationshipStatus(ark1, true);

        // Check status was updated
        assertTrue(registry.isValidArkProxyPair(ark1, TARGET_CHAIN_ID, proxy1));
    }

    function test_getRelation() public {
        vm.prank(governor);
        registry.registerArkProxy(
            ark1,
            TARGET_CHAIN_ID,
            proxy1,
            DEFAULT_DESCRIPTION
        );

        ICrossChainRegistry.ArkProxyRelation memory relation = registry
            .getRelation(ark1);
        assertEq(relation.proxy, proxy1);
        assertEq(relation.targetChainId, TARGET_CHAIN_ID);
        assertEq(
            uint256(relation.status),
            uint256(ICrossChainRegistry.RelationshipStatus.ACTIVE)
        );
    }

    function test_getRelationshipMetadata() public {
        vm.prank(governor);
        registry.registerArkProxy(
            ark1,
            TARGET_CHAIN_ID,
            proxy1,
            DEFAULT_DESCRIPTION
        );

        ICrossChainRegistry.RelationshipMetadata memory metadata = registry
            .getRelationshipMetadata(ark1);
        assertEq(metadata.description, DEFAULT_DESCRIPTION);
        assertEq(metadata.creator, governor);
        assertTrue(metadata.createdAt > 0);
        assertTrue(metadata.configHash != bytes32(0));
    }

    /*//////////////////////////////////////////////////////////////
                          ENHANCED FEATURES TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setRelationshipStatus() public {
        // Register first
        vm.prank(governor);
        registry.registerArkProxy(
            ark1,
            TARGET_CHAIN_ID,
            proxy1,
            DEFAULT_DESCRIPTION
        );

        // Test setting to PAUSED
        vm.expectEmit(true, true, true, true);
        emit RelationshipStatusChanged(
            ark1,
            TARGET_CHAIN_ID,
            proxy1,
            ICrossChainRegistry.RelationshipStatus.ACTIVE,
            ICrossChainRegistry.RelationshipStatus.PAUSED
        );

        vm.expectEmit(true, true, true, false);
        emit RelationshipActionRecorded(
            ark1,
            ICrossChainRegistry.RelationshipAction.PAUSED,
            governor
        );

        vm.prank(governor);
        registry.setRelationshipStatus(
            ark1,
            ICrossChainRegistry.RelationshipStatus.PAUSED
        );

        // Check status
        assertEq(
            uint256(registry.getRelationshipStatus(ark1)),
            uint256(ICrossChainRegistry.RelationshipStatus.PAUSED)
        );
        assertFalse(
            registry.isValidArkProxyPair(ark1, TARGET_CHAIN_ID, proxy1)
        ); // Only ACTIVE relationships are valid

        // Test setting to DEPRECATED
        vm.prank(governor);
        registry.setRelationshipStatus(
            ark1,
            ICrossChainRegistry.RelationshipStatus.DEPRECATED
        );

        assertEq(
            uint256(registry.getRelationshipStatus(ark1)),
            uint256(ICrossChainRegistry.RelationshipStatus.DEPRECATED)
        );
    }

    function test_batchRegisterArkProxy() public {
        ICrossChainRegistry.BatchRegistrationParams[]
            memory params = new ICrossChainRegistry.BatchRegistrationParams[](
                3
            );
        params[0] = ICrossChainRegistry.BatchRegistrationParams({
            ark: ark1,
            targetChainId: TARGET_CHAIN_ID,
            proxy: proxy1,
            description: "Batch register 1"
        });
        params[1] = ICrossChainRegistry.BatchRegistrationParams({
            ark: ark2,
            targetChainId: TARGET_CHAIN_ID,
            proxy: proxy2,
            description: "Batch register 2"
        });
        params[2] = ICrossChainRegistry.BatchRegistrationParams({
            ark: ark3,
            targetChainId: TARGET_CHAIN_ID,
            proxy: proxy3,
            description: "Batch register 3"
        });

        vm.expectEmit(true, false, false, true);
        emit BatchRegistrationCompleted(3, governor);

        vm.prank(governor);
        registry.batchRegisterArkProxy(params);

        // Check all relationships were created
        assertEq(registry.getRelationshipCount(), 3);
        assertTrue(registry.isArkRegistered(ark1));
        assertTrue(registry.isArkRegistered(ark2));
        assertTrue(registry.isArkRegistered(ark3));

        // Check individual relationships
        (address proxy, uint16 chainId) = registry.getProxyForArk(ark1);
        assertEq(proxy, proxy1);
        assertEq(chainId, TARGET_CHAIN_ID);
    }

    function test_batchUnregisterArkProxy() public {
        // First register multiple relationships
        vm.prank(governor);
        registry.registerArkProxy(ark1, TARGET_CHAIN_ID, proxy1, "Test 1");
        vm.prank(governor);
        registry.registerArkProxy(ark2, TARGET_CHAIN_ID, proxy2, "Test 2");
        vm.prank(governor);
        registry.registerArkProxy(ark3, TARGET_CHAIN_ID, proxy3, "Test 3");

        assertEq(registry.getRelationshipCount(), 3);

        // Batch unregister
        address[] memory arks = new address[](2);
        arks[0] = ark1;
        arks[1] = ark2;

        vm.prank(governor);
        registry.batchUnregisterArkProxy(arks);

        // Check relationships were removed
        assertEq(registry.getRelationshipCount(), 1);
        assertFalse(registry.isArkRegistered(ark1));
        assertFalse(registry.isArkRegistered(ark2));
        assertTrue(registry.isArkRegistered(ark3)); // Still registered
    }

    function test_updateRelationshipMetadata() public {
        // Register first
        vm.prank(governor);
        registry.registerArkProxy(
            ark1,
            TARGET_CHAIN_ID,
            proxy1,
            DEFAULT_DESCRIPTION
        );

        string memory newDescription = "Updated description";
        bytes32 newConfigHash = keccak256("new config");

        vm.expectEmit(true, false, false, true);
        emit RelationshipMetadataUpdated(ark1, newDescription, newConfigHash);

        vm.expectEmit(true, true, true, false);
        emit RelationshipActionRecorded(
            ark1,
            ICrossChainRegistry.RelationshipAction.METADATA_UPDATED,
            governor
        );

        vm.prank(governor);
        registry.updateRelationshipMetadata(
            ark1,
            newDescription,
            newConfigHash
        );

        // Check metadata was updated
        ICrossChainRegistry.RelationshipMetadata memory metadata = registry
            .getRelationshipMetadata(ark1);
        assertEq(metadata.description, newDescription);
        assertEq(metadata.configHash, newConfigHash);
    }

    function test_getRelationshipHistory() public {
        // Register
        vm.prank(governor);
        registry.registerArkProxy(
            ark1,
            TARGET_CHAIN_ID,
            proxy1,
            DEFAULT_DESCRIPTION
        );

        // Update status
        vm.prank(governor);
        registry.setRelationshipStatus(
            ark1,
            ICrossChainRegistry.RelationshipStatus.PAUSED
        );

        // Update metadata
        vm.prank(governor);
        registry.updateRelationshipMetadata(
            ark1,
            "New description",
            keccak256("new config")
        );

        // Get history
        ICrossChainRegistry.RelationshipHistoryEntry[] memory history = registry
            .getRelationshipHistory(ark1);

        assertEq(history.length, 3);
        assertEq(
            uint256(history[0].action),
            uint256(ICrossChainRegistry.RelationshipAction.CREATED)
        );
        assertEq(
            uint256(history[1].action),
            uint256(ICrossChainRegistry.RelationshipAction.PAUSED)
        );
        assertEq(
            uint256(history[2].action),
            uint256(ICrossChainRegistry.RelationshipAction.METADATA_UPDATED)
        );

        // Check latest entry
        ICrossChainRegistry.RelationshipHistoryEntry memory latest = registry
            .getLatestHistoryEntry(ark1);
        assertEq(
            uint256(latest.action),
            uint256(ICrossChainRegistry.RelationshipAction.METADATA_UPDATED)
        );
        assertEq(latest.actor, governor);
    }

    function test_getRelationshipsByStatus() public {
        // Register multiple relationships with different statuses
        vm.prank(governor);
        registry.registerArkProxy(ark1, TARGET_CHAIN_ID, proxy1, "Test 1");
        vm.prank(governor);
        registry.registerArkProxy(ark2, TARGET_CHAIN_ID, proxy2, "Test 2");
        vm.prank(governor);
        registry.registerArkProxy(ark3, TARGET_CHAIN_ID, proxy3, "Test 3");

        // Set different statuses
        vm.prank(governor);
        registry.setRelationshipStatus(
            ark2,
            ICrossChainRegistry.RelationshipStatus.PAUSED
        );
        vm.prank(governor);
        registry.setRelationshipStatus(
            ark3,
            ICrossChainRegistry.RelationshipStatus.DEPRECATED
        );

        // Get relationships by status
        address[] memory activeArks = registry.getRelationshipsByStatus(
            ICrossChainRegistry.RelationshipStatus.ACTIVE
        );
        address[] memory pausedArks = registry.getRelationshipsByStatus(
            ICrossChainRegistry.RelationshipStatus.PAUSED
        );
        address[] memory deprecatedArks = registry.getRelationshipsByStatus(
            ICrossChainRegistry.RelationshipStatus.DEPRECATED
        );

        assertEq(activeArks.length, 1);
        assertEq(pausedArks.length, 1);
        assertEq(deprecatedArks.length, 1);

        assertEq(activeArks[0], ark1);
        assertEq(pausedArks[0], ark2);
        assertEq(deprecatedArks[0], ark3);
    }

    function test_getRelationshipStatistics() public {
        // Register multiple relationships with different statuses
        vm.prank(governor);
        registry.registerArkProxy(ark1, TARGET_CHAIN_ID, proxy1, "Test 1");
        vm.prank(governor);
        registry.registerArkProxy(ark2, TARGET_CHAIN_ID, proxy2, "Test 2");
        vm.prank(governor);
        registry.registerArkProxy(ark3, TARGET_CHAIN_ID, proxy3, "Test 3");

        // Set different statuses
        vm.prank(governor);
        registry.setRelationshipStatus(
            ark2,
            ICrossChainRegistry.RelationshipStatus.PAUSED
        );
        vm.prank(governor);
        registry.setRelationshipStatus(
            ark3,
            ICrossChainRegistry.RelationshipStatus.DEPRECATED
        );

        // Get statistics
        (
            uint256 totalRelationships,
            uint256 activeRelationships,
            uint256 pausedRelationships,
            uint256 deprecatedRelationships
        ) = registry.getRelationshipStatistics();

        assertEq(totalRelationships, 3);
        assertEq(activeRelationships, 1);
        assertEq(pausedRelationships, 1);
        assertEq(deprecatedRelationships, 1);
    }

    function test_getChainStatistics() public {
        // Register multiple relationships
        vm.prank(governor);
        registry.registerArkProxy(ark1, TARGET_CHAIN_ID, proxy1, "Test 1");
        vm.prank(governor);
        registry.registerArkProxy(ark2, TARGET_CHAIN_ID, proxy2, "Test 2");
        vm.prank(governor);
        registry.registerArkProxy(ark3, TARGET_CHAIN_ID, proxy3, "Test 3");

        // Set one to inactive
        vm.prank(governor);
        registry.setRelationshipStatus(
            ark2,
            ICrossChainRegistry.RelationshipStatus.PAUSED
        );

        // Get chain statistics
        (uint256 totalProxies, uint256 activeProxies) = registry
            .getChainStatistics(CURRENT_CHAIN_ID);

        assertEq(totalProxies, 3);
        assertEq(activeProxies, 2); // ark1 and ark3 are active, ark2 is paused
    }

    function test_validateContractExists() public {
        // Test with existing contract (our registry)
        assertTrue(registry.validateContractExists(address(registry)));

        // Test with EOA
        assertFalse(registry.validateContractExists(user));

        // Test with zero address
        assertFalse(registry.validateContractExists(address(0)));
    }

    function test_relationshipExists() public {
        assertFalse(registry.relationshipExists(ark1));

        vm.prank(governor);
        registry.registerArkProxy(
            ark1,
            TARGET_CHAIN_ID,
            proxy1,
            DEFAULT_DESCRIPTION
        );

        assertTrue(registry.relationshipExists(ark1));
    }

    /*//////////////////////////////////////////////////////////////
                             ERROR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getRelationshipStatus_revertRelationshipDoesNotExist()
        public
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                ark1
            )
        );
        registry.getRelationshipStatus(ark1);
    }

    function test_getRelationshipHistory_emptyForNonexistentArk() public {
        ICrossChainRegistry.RelationshipHistoryEntry[] memory history = registry
            .getRelationshipHistory(ark1);
        assertEq(history.length, 0);
    }

    function test_getLatestHistoryEntry_revertNoHistoryEntries() public {
        vm.expectRevert("No history entries");
        registry.getLatestHistoryEntry(ark1);
    }

    function test_batchRegisterArkProxy_revertEmptyBatch() public {
        ICrossChainRegistry.BatchRegistrationParams[]
            memory params = new ICrossChainRegistry.BatchRegistrationParams[](
                0
            );

        vm.prank(governor);
        vm.expectRevert("Empty batch");
        registry.batchRegisterArkProxy(params);
    }

    function test_batchUnregisterArkProxy_revertEmptyBatch() public {
        address[] memory arks = new address[](0);

        vm.prank(governor);
        vm.expectRevert("Empty batch");
        registry.batchUnregisterArkProxy(arks);
    }

    /*//////////////////////////////////////////////////////////////
                          ENUMERATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getRegisteredArks() public {
        address[] memory arks = registry.getRegisteredArks();
        assertEq(arks.length, 0);

        vm.prank(governor);
        registry.registerArkProxy(ark1, TARGET_CHAIN_ID, proxy1, "Test 1");
        vm.prank(governor);
        registry.registerArkProxy(ark2, TARGET_CHAIN_ID, proxy2, "Test 2");

        arks = registry.getRegisteredArks();
        assertEq(arks.length, 2);
        assertTrue(arks[0] == ark1 || arks[0] == ark2);
        assertTrue(arks[1] == ark1 || arks[1] == ark2);
        assertTrue(arks[0] != arks[1]);
    }

    function test_getRegisteredProxies() public {
        address[] memory proxies = registry.getRegisteredProxies(
            CURRENT_CHAIN_ID
        );
        assertEq(proxies.length, 0);

        vm.prank(governor);
        registry.registerArkProxy(ark1, TARGET_CHAIN_ID, proxy1, "Test 1");
        vm.prank(governor);
        registry.registerArkProxy(ark2, TARGET_CHAIN_ID, proxy2, "Test 2");

        proxies = registry.getRegisteredProxies(CURRENT_CHAIN_ID);
        assertEq(proxies.length, 2);
        assertTrue(proxies[0] == proxy1 || proxies[0] == proxy2);
        assertTrue(proxies[1] == proxy1 || proxies[1] == proxy2);
        assertTrue(proxies[0] != proxies[1]);
    }
}
