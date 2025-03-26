// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {StargateAdapterSetupTest} from "./StargateAdapter.setup.t.sol";
import {StargateAdapter} from "../../src/adapters/StargateAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";

contract StargateAdapterGeneralTest is StargateAdapterSetupTest {
    /*//////////////////////////////////////////////////////////////
                          ADAPTER FEATURES TESTS
    //////////////////////////////////////////////////////////////*/

    function testGetSupportedChains() public view {
        uint16[] memory supportedChains = adapterA.getSupportedChains();
        assertEq(supportedChains.length, 2);
        assertEq(supportedChains[0], CHAIN_ID_A);
        assertEq(supportedChains[1], CHAIN_ID_B);
    }

    function testSupportsChain() public view {
        assertTrue(adapterA.supportsChain(CHAIN_ID_A));
        assertTrue(adapterA.supportsChain(CHAIN_ID_B));
        assertFalse(adapterA.supportsChain(9999)); // Arbitrary unsupported chain
    }

    function testSupportsAsset() public view {
        assertTrue(adapterA.supportsAsset(CHAIN_ID_A, address(tokenA)));
        assertTrue(adapterA.supportsAsset(CHAIN_ID_B, address(tokenA)));
        assertFalse(adapterA.supportsAsset(9999, address(tokenA))); // Unsupported chain
        assertFalse(adapterA.supportsAsset(CHAIN_ID_A, address(0xdead))); // Unsupported asset
    }

    function testGetSupportedAssets() public view {
        address[] memory assets = adapterA.getSupportedAssets(CHAIN_ID_A);
        assertEq(assets.length, 1);
        assertEq(assets[0], address(tokenA));
    }

    function testGetSupportedAssetsUnsupportedChain() public {
        vm.expectRevert(IBridgeAdapter.UnsupportedChain.selector);
        adapterA.getSupportedAssets(9999); // Unsupported chain
    }

    function testFeatureSupport() public view {
        // StargateAdapter supports asset transfers but not messaging or state reads
        assertTrue(adapterA.supportsAssetTransfer());
        assertFalse(adapterA.supportsMessaging());
        assertFalse(adapterA.supportsStateRead());
    }

    /*//////////////////////////////////////////////////////////////
                          GOVERNANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function testSetMinDstGasForCall() public {
        useNetworkA();

        // Check current value
        assertEq(adapterA.minDstGasForCall(), 300000);

        // Update the value as governor
        vm.prank(governor);
        adapterA.setMinDstGasForCall(400000);

        // Verify the value was updated
        assertEq(adapterA.minDstGasForCall(), 400000);
    }

    function testSetMinDstGasForCallUnauthorized() public {
        useNetworkA();

        // Try to update the value as unauthorized user
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        adapterA.setMinDstGasForCall(400000);
    }

    function testAddSupportedChain() public {
        useNetworkA();

        // Add a new supported chain
        uint16 newChainId = 42161; // Arbitrum
        uint16 newStargateChainId = 110; // Stargate's chain ID for Arbitrum

        vm.prank(governor);
        adapterA.addSupportedChain(newChainId, newStargateChainId);

        // Verify the chain was added
        assertTrue(adapterA.supportsChain(newChainId));
        assertEq(
            adapterA.chainToStargateChainId(newChainId),
            newStargateChainId
        );

        // Verify it's in the list of supported chains
        uint16[] memory supportedChains = adapterA.getSupportedChains();
        bool found = false;
        for (uint i = 0; i < supportedChains.length; i++) {
            if (supportedChains[i] == newChainId) {
                found = true;
                break;
            }
        }
        assertTrue(found);
    }

    function testAddDuplicateSupportedChain() public {
        useNetworkA();

        // Try to add an already supported chain
        vm.prank(governor);
        vm.expectRevert(IBridgeAdapter.InvalidParams.selector);
        adapterA.addSupportedChain(CHAIN_ID_A, CHAIN_ID_A);
    }

    function testAddSupportedAsset() public {
        useNetworkA();

        // Create a new token
        ERC20Mock newToken = new ERC20Mock();

        // Add support for the new token
        vm.prank(governor);
        adapterA.addSupportedAsset(CHAIN_ID_A, address(newToken), 3);

        // Verify the asset was added
        assertTrue(adapterA.supportsAsset(CHAIN_ID_A, address(newToken)));
        assertEq(adapterA.chainAssetToPoolId(CHAIN_ID_A, address(newToken)), 3);

        // Verify it's in the list of supported assets
        address[] memory supportedAssets = adapterA.getSupportedAssets(
            CHAIN_ID_A
        );
        bool found = false;
        for (uint i = 0; i < supportedAssets.length; i++) {
            if (supportedAssets[i] == address(newToken)) {
                found = true;
                break;
            }
        }
        assertTrue(found);
    }

    function testAddAssetToUnsupportedChain() public {
        useNetworkA();

        // Try to add an asset to an unsupported chain
        vm.prank(governor);
        vm.expectRevert(IBridgeAdapter.UnsupportedChain.selector);
        adapterA.addSupportedAsset(9999, address(tokenA), 1);
    }

    function testAddInvalidAsset() public {
        useNetworkA();

        // Try to add address(0) as an asset
        vm.prank(governor);
        vm.expectRevert(IBridgeAdapter.InvalidParams.selector);
        adapterA.addSupportedAsset(CHAIN_ID_A, address(0), 1);
    }

    function testAddDuplicateAsset() public {
        useNetworkA();

        // Add the same asset again (should update pool ID but not add duplicate)
        vm.prank(governor);
        adapterA.addSupportedAsset(CHAIN_ID_A, address(tokenA), 5);

        // Verify the pool ID was updated
        assertEq(adapterA.chainAssetToPoolId(CHAIN_ID_A, address(tokenA)), 5);

        // Verify there's still only one supported asset
        address[] memory supportedAssets = adapterA.getSupportedAssets(
            CHAIN_ID_A
        );
        assertEq(supportedAssets.length, 1);
        assertEq(supportedAssets[0], address(tokenA));
    }
}
