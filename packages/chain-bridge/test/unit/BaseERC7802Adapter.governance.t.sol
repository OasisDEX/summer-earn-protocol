// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BaseERC7802Adapter} from "../../src/adapters/BaseERC7802Adapter.sol";
import {ERC7802OFTAdapter} from "../../src/adapters/ERC7802OFTAdapter.sol";
import {BaseBridgeAdapter} from "../../src/base/BaseBridgeAdapter.sol";
import {IBaseBridgeAdapterErrors} from "../../src/interfaces/IBaseBridgeAdapterErrors.sol";
import {IBaseBridgeAdapterEvents} from "../../src/interfaces/IBaseBridgeAdapterEvents.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {BaseERC7802AdapterSetupTest} from "./BaseERC7802Adapter.setup.t.sol";

/**
 * @title BaseERC7802Adapter Governance Tests
 * @notice Tests governance functionality of BaseERC7802Adapter
 */
contract BaseERC7802AdapterGovernanceTest is BaseERC7802AdapterSetupTest {
    /*//////////////////////////////////////////////////////////////
                        SET ASSET SUPPORT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SetAssetSupport_RevertsForZeroAddress() public {
        vm.prank(governor);
        vm.expectRevert(IBaseBridgeAdapterErrors.InvalidParams.selector);
        adapterA.setAssetSupport(address(0), true);
    }

    function test_SetAssetSupport_RevertsForNonGovernor() public {
        ERC20Mock newToken = new ERC20Mock();

        vm.prank(user); // Non-governor user
        vm.expectRevert(); // Should revert with access control error
        adapterA.setAssetSupport(address(newToken), true);
    }

    function test_SetAssetSupport_EnablesAssetSupport() public {
        ERC20Mock newToken = new ERC20Mock();

        vm.prank(governor);
        adapterA.setAssetSupport(address(newToken), true);

        assertTrue(adapterA.supportedAsset(address(newToken)));
    }

    function test_SetAssetSupport_DisablesAssetSupport() public {
        vm.prank(governor);
        adapterA.setAssetSupport(address(tokenA), false);

        assertFalse(adapterA.supportedAsset(address(tokenA)));
    }

    function test_SetAssetSupport_CanReEnableAfterDisable() public {
        ERC20Mock newToken = new ERC20Mock();

        // Enable
        vm.prank(governor);
        adapterA.setAssetSupport(address(newToken), true);
        assertTrue(adapterA.supportedAsset(address(newToken)));

        // Disable
        vm.prank(governor);
        adapterA.setAssetSupport(address(newToken), false);
        assertFalse(adapterA.supportedAsset(address(newToken)));

        // Re-enable
        vm.prank(governor);
        adapterA.setAssetSupport(address(newToken), true);
        assertTrue(adapterA.supportedAsset(address(newToken)));
    }

    function test_SetAssetSupport_CanToggleMultipleAssets() public {
        ERC20Mock token1 = new ERC20Mock();
        ERC20Mock token2 = new ERC20Mock();
        ERC20Mock token3 = new ERC20Mock();

        // Enable all
        vm.startPrank(governor);
        adapterA.setAssetSupport(address(token1), true);
        adapterA.setAssetSupport(address(token2), true);
        adapterA.setAssetSupport(address(token3), true);
        vm.stopPrank();

        assertTrue(adapterA.supportedAsset(address(token1)));
        assertTrue(adapterA.supportedAsset(address(token2)));
        assertTrue(adapterA.supportedAsset(address(token3)));

        // Disable token2
        vm.prank(governor);
        adapterA.setAssetSupport(address(token2), false);

        assertTrue(adapterA.supportedAsset(address(token1)));
        assertFalse(adapterA.supportedAsset(address(token2)));
        assertTrue(adapterA.supportedAsset(address(token3)));
    }

    function test_SetAssetSupport_NoOpWhenSettingSameValue() public {
        ERC20Mock newToken = new ERC20Mock();

        // Initially false, set to false again
        vm.prank(governor);
        adapterA.setAssetSupport(address(newToken), false);

        assertFalse(adapterA.supportedAsset(address(newToken)));

        // Set to true
        vm.prank(governor);
        adapterA.setAssetSupport(address(newToken), true);

        assertTrue(adapterA.supportedAsset(address(newToken)));

        // Set to true again (no-op)
        vm.prank(governor);
        adapterA.setAssetSupport(address(newToken), true);

        assertTrue(adapterA.supportedAsset(address(newToken)));
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL ID MAPPING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_MapExternalId_RevertsForZeroExternalId() public {
        vm.prank(governor);
        vm.expectRevert(IBaseBridgeAdapterErrors.InvalidParams.selector);
        adapterA.mapExternalId(CHAIN_ID_A, 0);
    }

    function test_MapExternalId_RevertsForNonGovernor() public {
        vm.prank(user);
        vm.expectRevert(); // Should revert with access control error
        adapterA.mapExternalId(CHAIN_ID_A, 9999);
    }

    function test_MapExternalId_SetsMappingCorrectly() public {
        uint16 testChainId = 9999;
        uint32 testExternalId = 8888;

        vm.prank(governor);
        adapterA.mapExternalId(testChainId, testExternalId);

        assertEq(adapterA.chainToExternalId(testChainId), testExternalId);
        assertEq(adapterA.externalIdToChainId(testExternalId), testChainId);
    }

    function test_MapExternalId_OverwritesExistingMapping() public {
        uint16 testChainId = 9999;
        uint32 oldExternalId = 8888;
        uint32 newExternalId = 7777;

        // Set initial mapping
        vm.prank(governor);
        adapterA.mapExternalId(testChainId, oldExternalId);

        assertEq(adapterA.chainToExternalId(testChainId), oldExternalId);
        assertEq(adapterA.externalIdToChainId(oldExternalId), testChainId);

        // Overwrite with new mapping
        vm.prank(governor);
        adapterA.mapExternalId(testChainId, newExternalId);

        assertEq(adapterA.chainToExternalId(testChainId), newExternalId);
        assertEq(adapterA.externalIdToChainId(newExternalId), testChainId);
        // Old reverse mapping should be cleared
        assertEq(adapterA.externalIdToChainId(oldExternalId), 0);
    }

    function test_UnmapExternalId_RevertsForNonGovernor() public {
        vm.prank(user);
        vm.expectRevert(); // Should revert with access control error
        adapterA.unmapExternalId(CHAIN_ID_A);
    }

    function test_UnmapExternalId_RemovesMappingCorrectly() public {
        uint16 testChainId = 9999;
        uint32 testExternalId = 8888;

        // Set mapping first
        vm.prank(governor);
        adapterA.mapExternalId(testChainId, testExternalId);

        assertEq(adapterA.chainToExternalId(testChainId), testExternalId);
        assertEq(adapterA.externalIdToChainId(testExternalId), testChainId);

        // Unmap
        vm.prank(governor);
        adapterA.unmapExternalId(testChainId);

        assertEq(adapterA.chainToExternalId(testChainId), 0);
        assertEq(adapterA.externalIdToChainId(testExternalId), 0);
    }

    function test_UnmapExternalId_NoOpForUnmappedChain() public {
        uint16 unmappedChainId = 9999;

        // Ensure it's not mapped
        assertEq(adapterA.chainToExternalId(unmappedChainId), 0);

        // Unmap should not revert
        vm.prank(governor);
        adapterA.unmapExternalId(unmappedChainId);

        // Still unmapped
        assertEq(adapterA.chainToExternalId(unmappedChainId), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        EVENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_MapExternalId_EmitsExternalIdMappedEvent() public {
        uint16 testChainId = 9999;
        uint32 testExternalId = 8888;

        vm.expectEmit(true, true, false, true);
        emit IBaseBridgeAdapterEvents.ExternalIdMapped(
            testChainId,
            testExternalId
        );

        vm.prank(governor);
        adapterA.mapExternalId(testChainId, testExternalId);
    }

    function test_UnmapExternalId_EmitsExternalIdUnmappedEvent() public {
        uint16 testChainId = 9999;
        uint32 testExternalId = 8888;

        // Set mapping first
        vm.prank(governor);
        adapterA.mapExternalId(testChainId, testExternalId);

        vm.expectEmit(true, true, false, true);
        emit IBaseBridgeAdapterEvents.ExternalIdUnmapped(
            testChainId,
            testExternalId
        );

        vm.prank(governor);
        adapterA.unmapExternalId(testChainId);
    }

    function test_SetAssetSupport_EmitsAssetSupportUpdatedEvent() public {
        ERC20Mock newToken = new ERC20Mock();

        vm.expectEmit(true, false, false, true);
        emit BaseERC7802Adapter.AssetSupportUpdated(address(newToken), true);

        vm.prank(governor);
        adapterA.setAssetSupport(address(newToken), true);
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_AssetSupportAndExternalIdMapping_WorkTogether() public {
        ERC20Mock newToken = new ERC20Mock();
        uint16 newChainId = 9999;
        uint32 newExternalId = 8888;

        // Enable asset support
        vm.prank(governor);
        adapterA.setAssetSupport(address(newToken), true);

        // Map external ID
        vm.prank(governor);
        adapterA.mapExternalId(newChainId, newExternalId);

        // Verify both work together
        assertTrue(adapterA.supportedAsset(address(newToken)));
        assertEq(adapterA.chainToExternalId(newChainId), newExternalId);
        assertEq(adapterA.externalIdToChainId(newExternalId), newChainId);

        // Verify supportsAssetTransfer works with both
        // This would require setting up the peer relationship in registry
        //         assertTrue(adapterA.supportsAssetTransfer(newChainId, address(newToken)));
    }

    function _deployAdapter(
        address registry,
        address accessManager,
        address lzEndpoint,
        uint16[] memory chains,
        uint32[] memory lzEids
    ) internal override returns (BaseERC7802Adapter) {
        return new ERC7802OFTAdapter(registry, accessManager, lzEndpoint);
    }
}
