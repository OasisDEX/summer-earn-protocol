// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {CrossChainRegistry} from "../../../src/contracts/CrossChainRegistry.sol";
import {ICrossChainRegistry} from "../../../src/interfaces/ICrossChainRegistry.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";

/**
 * @title CrossChainRegistry Bijective Relationship Tests
 * @notice Tests for bijective relationship enforcement in CrossChainRegistry
 */
contract CrossChainRegistryBijectiveTest is Test {
    CrossChainRegistry registry;
    ProtocolAccessManager accessManager;
    address governor = makeAddr("governor");
    address adapterA = makeAddr("adapterA");
    address adapterB = makeAddr("adapterB");
    uint16 chainA = 1;
    uint16 chainB = 2;
    uint16 currentChain = 31337; // Foundry default chain ID

    function setUp() public {
        accessManager = new ProtocolAccessManager(governor);
        registry = new CrossChainRegistry(address(accessManager));
        vm.startPrank(governor);
    }

    function testPEER_RELATIONSHIP_IsBijectiveByDefault() public view {
        assertTrue(
            registry.isBijectiveRelationshipType(registry.PEER_RELATIONSHIP())
        );
        assertFalse(
            registry.isBijectiveRelationshipType(
                registry.EXECUTOR_RELATIONSHIP()
            )
        );
    }

    function testCannotRegisterPEER_RELATIONSHIP_Singularly() public {
        bool reverted = false;
        try
            registry.registerRelationship(
                adapterA,
                adapterB,
                currentChain,
                currentChain,
                registry.PEER_RELATIONSHIP()
            )
        {
            // If we get here, the function didn't revert
            reverted = false;
        } catch {
            // If we get here, the function did revert
            reverted = true;
        }

        assertTrue(
            reverted,
            "Function should have reverted with UsePairRegistrationMethods"
        );
    }

    function testCannotUnregisterPEER_RELATIONSHIP_Singularly() public {
        // First register using the pair method
        registry.registerAdapterPeerPair(
            adapterA,
            adapterB,
            currentChain,
            currentChain
        );

        bool reverted = false;
        try
            registry.unregisterRelationship(
                adapterA,
                registry.PEER_RELATIONSHIP(),
                chainB
            )
        {
            // If we get here, the function didn't revert
            reverted = false;
        } catch {
            // If we get here, the function did revert
            reverted = true;
        }

        assertTrue(
            reverted,
            "Function should have reverted with UsePairRegistrationMethods"
        );
    }

    function testCanRegisterEXECUTOR_RELATIONSHIP_Singularly() public {
        // EXECUTOR_RELATIONSHIP should not be bijective by default
        assertFalse(
            registry.isBijectiveRelationshipType(
                registry.EXECUTOR_RELATIONSHIP()
            )
        );

        // Set up bridge router first
        address bridgeRouter = makeAddr("bridgeRouter");
        registry.setBridgeRouter(bridgeRouter);

        // Should be able to register singularly
        registry.registerExecutor(adapterA);

        // Verify it was registered
        assertTrue(registry.isAuthorizedExecutor(adapterA));
    }

    function testCanSetBijectiveRelationshipType() public {
        // Make EXECUTOR_RELATIONSHIP bijective
        registry.addSupportedRelationshipType(
            registry.EXECUTOR_RELATIONSHIP(),
            true
        );
        assertTrue(
            registry.isBijectiveRelationshipType(
                registry.EXECUTOR_RELATIONSHIP()
            )
        );

        // Now should not be able to register singularly
        bool reverted = false;
        try
            registry.registerRelationship(
                adapterA,
                adapterB,
                currentChain,
                currentChain,
                registry.EXECUTOR_RELATIONSHIP()
            )
        {
            // If we get here, the function didn't revert
            reverted = false;
        } catch {
            // If we get here, the function did revert
            reverted = true;
        }

        assertTrue(
            reverted,
            "Function should have reverted with UsePairRegistrationMethods"
        );
    }

    function testAddSupportedRelationshipTypeWithBijective() public {
        bytes32 newType = keccak256("NEW_BIJECTIVE_TYPE");

        // Add a new bijective relationship type
        registry.addSupportedRelationshipType(newType, true);

        // Verify it's supported and bijective
        assertTrue(registry.isBijectiveRelationshipType(newType));

        // Should not be able to register singularly
        bool reverted = false;
        try
            registry.registerRelationship(
                adapterA,
                adapterB,
                currentChain,
                currentChain,
                newType
            )
        {
            // If we get here, the function didn't revert
            reverted = false;
        } catch {
            // If we get here, the function did revert
            reverted = true;
        }

        assertTrue(
            reverted,
            "Function should have reverted with UsePairRegistrationMethods"
        );
    }

    function testAddSupportedRelationshipTypeNonBijective() public {
        bytes32 newType = keccak256("NEW_NON_BIJECTIVE_TYPE");

        // Add a new non-bijective relationship type
        registry.addSupportedRelationshipType(newType, false);

        // Verify it's supported but not bijective
        assertFalse(registry.isBijectiveRelationshipType(newType));

        // Should be able to register singularly
        registry.registerRelationship(
            adapterA,
            adapterB,
            currentChain,
            currentChain,
            newType
        );

        // Verify it was registered
        assertTrue(
            registry.isValidCrossChainPair(
                adapterA,
                adapterB,
                currentChain,
                currentChain,
                newType
            )
        );
    }

    function testCanUnsetBijectiveRelationshipType() public {
        // Make PEER_RELATIONSHIP non-bijective
        registry.addSupportedRelationshipType(
            registry.PEER_RELATIONSHIP(),
            false
        );
        assertFalse(
            registry.isBijectiveRelationshipType(registry.PEER_RELATIONSHIP())
        );

        // Now should be able to register singularly
        registry.registerRelationship(
            adapterA,
            adapterB,
            currentChain,
            currentChain,
            registry.PEER_RELATIONSHIP()
        );
    }

    function testCanAddNewSupportedRelationshipType() public {
        bytes32 newType = keccak256("NEW_TYPE");

        // Should be able to add a new relationship type
        registry.addSupportedRelationshipType(newType, true);

        // Verify it was added and is bijective
        assertTrue(registry.isBijectiveRelationshipType(newType));
    }

    function testValidateBijectiveRelationships() public view {
        // For supported bijective types, should return true
        (bool isBijective, string[] memory violations) = registry
            .validateBijectiveRelationships(registry.PEER_RELATIONSHIP());
        assertTrue(isBijective);
        assertEq(violations.length, 0);

        // For non-bijective types, should also return true
        (isBijective, violations) = registry.validateBijectiveRelationships(
            registry.EXECUTOR_RELATIONSHIP()
        );
        assertTrue(isBijective);
        assertEq(violations.length, 0);
    }

    function testPairRegistrationStillWorks() public {
        // Should be able to register pairs normally
        registry.registerAdapterPeerPair(
            adapterA,
            adapterB,
            currentChain,
            currentChain
        );

        // Verify both directions are registered
        assertTrue(
            registry.isValidAdapterPeer(
                adapterA,
                adapterB,
                currentChain,
                currentChain
            )
        );
        assertTrue(
            registry.isValidAdapterPeer(
                adapterB,
                adapterA,
                currentChain,
                currentChain
            )
        );
    }

    function testPairUnregistrationStillWorks() public {
        // Register first
        registry.registerAdapterPeerPair(
            adapterA,
            adapterB,
            currentChain,
            currentChain
        );

        // Then unregister
        registry.unregisterAdapterPeerPair(
            adapterA,
            adapterB,
            currentChain,
            currentChain
        );

        // Verify both directions are unregistered
        assertFalse(
            registry.isValidAdapterPeer(
                adapterA,
                adapterB,
                currentChain,
                currentChain
            )
        );
        assertFalse(
            registry.isValidAdapterPeer(
                adapterB,
                adapterA,
                currentChain,
                currentChain
            )
        );
    }

    function testBijectiveRelationshipTypeUpdatedEvent() public {
        vm.expectEmit(true, false, false, true);
        emit ICrossChainRegistry.BijectiveRelationshipTypeUpdated(
            registry.EXECUTOR_RELATIONSHIP(),
            true
        );

        registry.addSupportedRelationshipType(
            registry.EXECUTOR_RELATIONSHIP(),
            true
        );
    }
}
