// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BaseCrossChainRegistryTest} from "../../helpers/BaseCrossChainRegistry.t.sol";

/**
 * @title CrossChainRegistry.integration
 * @notice End-to-end registry workflow happy-path
 */
contract CrossChainRegistryIntegrationTest is BaseCrossChainRegistryTest {
    function test_endToEndRegistrationAndValidation() public {
        address arkAddress = makeAddr("testArk");
        address proxyAddress = makeAddr("testProxy");

        vm.expectEmit(true, true, true, true, address(registry));
        emit CrossChainRelationshipRegistered(
            arkAddress,
            proxyAddress,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            peerType
        );

        vm.prank(governor);
        registry.registerRelationship(
            arkAddress,
            proxyAddress,
            CURRENT_CHAIN_ID,
            TARGET_CHAIN_ID,
            peerType
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
    }
}
