// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BaseCrossChainRegistryTest} from "../../helpers/BaseCrossChainRegistry.t.sol";
import {AdapterCrossChainRegistry} from "../../../src/contracts/AdapterCrossChainRegistry.sol";
import {ICrossChainRegistry} from "../../../src/interfaces/ICrossChainRegistry.sol";

/**
 * @title CrossChainRegistry.integration
 * @notice End-to-end registry workflow happy-path
 */
contract CrossChainRegistryIntegrationTest is BaseCrossChainRegistryTest {
    function test_endToEndRegistrationAndValidation() public {
        address arkAddress = makeAddr("testArk");
        address proxyAddress = makeAddr("testProxy");

        // Since PEER_RELATIONSHIP is bijective, we need to use pair registration
        // This will emit two events: one for each direction
        vm.expectEmit(true, true, true, true, address(registry));
        emit CrossChainRelationshipRegistered(
            arkAddress,
            proxyAddress,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            peerType
        );

        vm.expectEmit(true, true, true, true, address(registry));
        emit CrossChainRelationshipRegistered(
            proxyAddress,
            arkAddress,
            TARGET_CHAIN_ID,
            CURRENT_CHAIN_ID,
            peerType
        );

        vm.prank(governor);
        registry.registerAdapterPeerPair(
            arkAddress,
            proxyAddress,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID
        );

        (address[] memory targetContracts, uint16[] memory chainIds) = registry
            .getAllTargetsForSource(arkAddress, peerType);
        assertEq(targetContracts.length, 1);
        assertEq(targetContracts[0], proxyAddress);
        assertEq(chainIds.length, 1);
        assertEq(chainIds[0], TARGET_CHAIN_ID);

        address sourceContract = registry.getSourceForTarget(
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            proxyAddress,
            peerType
        );
        assertEq(sourceContract, arkAddress);

        assertTrue(
            registry.isValidCrossChainPair(
                arkAddress,
                proxyAddress,
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID,
                peerType
            )
        );

        vm.prank(governor);
        registry.unregisterAdapterPeerPair(
            arkAddress,
            proxyAddress,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID
        );
        vm.stopPrank();
    }

    function test_Getters() public {
        address arkAddress = makeAddr("testArk");
        address proxyAddress = makeAddr("testProxy");

        vm.prank(governor);
        registry.registerAdapterPeerPair(
            arkAddress,
            proxyAddress,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID
        );
        vm.stopPrank();

        assertEq(registry.isAdapterRegistered(arkAddress), true);
        assertEq(registry.isAdapterRegistered(proxyAddress), true);
        assertEq(
            registry.isValidAdapterPeer(
                arkAddress,
                proxyAddress,
                CURRENT_CHAIN_ID,
                TARGET_CHAIN_ID
            ),
            true
        );

        (address[] memory adapters, uint16[] memory chainIds) = registry
            .getAdapterPeers(arkAddress);

        assertEq(adapters.length, 1);
        assertEq(chainIds.length, 1);

        assertEq(adapters[0], proxyAddress);

        assertEq(chainIds[0], TARGET_CHAIN_ID);

        address[] memory registeredAdapters = registry.getRegisteredAdapters();

        assertEq(registeredAdapters.length, 2);
        assertEq(registeredAdapters[0], arkAddress);
        assertEq(registeredAdapters[1], proxyAddress);

        assertEq(registry.getAdapterRelationshipCount(), 2);
    }

    function test_registerUnregisterExecutor() public {
        address executor = makeAddr("testExecutor");
        address bridgeRouter = makeAddr("bridgeRouter");

        vm.startPrank(governor);
        registry.setBridgeRouter(bridgeRouter);
        registry.registerExecutor(executor);
        vm.stopPrank();

        assertEq(registry.isExecutorRegistered(executor), true);

        address[] memory executors = registry.getRegisteredExecutors();
        assertEq(executors.length, 1);
        assertEq(executors[0], executor);

        assertEq(registry.getExecutorCount(), 1);

        ICrossChainRegistry.CrossChainRelation memory relation = registry
            .getExecutorRelationship(executor);
        assertEq(relation.sourceContract, executor);
        assertEq(relation.targetContract, bridgeRouter);
        assertEq(relation.sourceChainId, CURRENT_CHAIN_ID);
        assertEq(relation.targetChainId, CURRENT_CHAIN_ID);
        assertEq(relation.relationshipType, registry.EXECUTOR_RELATIONSHIP());

        vm.startPrank(governor);
        registry.removeExecutor(executor);
        vm.stopPrank();

        assertEq(registry.isExecutorRegistered(executor), false);
    }

    function test_registerUnregisterAdapter() public {
        address arkAddress = makeAddr("testArk");
        address proxyAddress = makeAddr("testProxy");

        vm.startPrank(governor);
        registry.registerAdapterPeerPair(
            arkAddress,
            proxyAddress,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID
        );
        vm.stopPrank();

        assertEq(
            registry.getRelationshipCount(registry.PEER_RELATIONSHIP()),
            2
        );

        vm.startPrank(governor);
        registry.unregisterAdapterPeerPair(
            arkAddress,
            proxyAddress,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID
        );
        vm.stopPrank();
    }
}
