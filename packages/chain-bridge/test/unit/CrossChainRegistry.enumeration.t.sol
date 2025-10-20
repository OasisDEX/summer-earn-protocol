// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BaseCrossChainRegistryTest} from "../helpers/BaseCrossChainRegistry.t.sol";
import {ICrossChainRegistry} from "../../src/interfaces/ICrossChainRegistry.sol";

contract CrossChainRegistryEnumerationTest is BaseCrossChainRegistryTest {
    function test_getTargetsForSource_returnsMultiple() public {
        vm.startPrank(governor);
        // Since PEER_RELATIONSHIP is bijective, we need to use pair registration
        // For testing enumeration, we'll register each relationship individually
        registry.registerAdapterPeerPair(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID
        );
        registry.registerAdapterPeerPair(ark1, proxy2, CURRENT_CHAIN_ID, 10);
        registry.registerAdapterPeerPair(ark1, proxy3, CURRENT_CHAIN_ID, 137);
        vm.stopPrank();

        (address[] memory targets, uint16[] memory chains) = registry
            .getTargetsForSource(ark1, peerType);
        assertEq(targets.length, 3);
        assertEq(chains.length, 3);
    }

    function test_getRelationshipByTarget_returnsDetails() public {
        vm.prank(governor);
        registry.registerAdapterPeerPair(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID
        );

        ICrossChainRegistry.CrossChainRelation memory rel = registry
            .getRelationshipByTarget(ark1, peerType, TARGET_CHAIN_ID);

        assertEq(rel.sourceContract, ark1);
        assertEq(rel.targetContract, proxy1);
        assertEq(rel.sourceChainId, CURRENT_CHAIN_ID);
        assertEq(rel.targetChainId, TARGET_CHAIN_ID);
        assertEq(rel.relationshipType, peerType);
    }

    function test_getRelationship_returnsDetails() public {
        vm.prank(governor);
        registry.registerAdapterPeerPair(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID
        );

        ICrossChainRegistry.CrossChainRelation memory rel = registry
            .getRelationship(ark1, peerType);
        assertEq(rel.sourceContract, ark1);
        assertEq(rel.targetContract, proxy1);
        assertEq(rel.sourceChainId, CURRENT_CHAIN_ID);
        assertEq(rel.targetChainId, TARGET_CHAIN_ID);
        assertEq(rel.relationshipType, peerType);
    }

    function test_getRegisteredSourceContracts_listsSources() public {
        vm.startPrank(governor);
        registry.registerAdapterPeerPair(
            ark1,
            proxy1,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID
        );
        registry.registerAdapterPeerPair(
            ark2,
            proxy2,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID
        );
        vm.stopPrank();

        address[] memory sources = registry.getRegisteredSourceContracts(
            peerType
        );
        // Since we used registerAdapterPeerPair, we get both directions (4 total: ark1, proxy1, ark2, proxy2)
        assertEq(sources.length, 4);
    }
}
