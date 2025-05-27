// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {StargateAdapterSetupTest} from "./StargateAdapter.setup.t.sol";
import {StargateAdapter} from "../../src/adapters/StargateAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {MockStargateV2} from "../mocks/MockStargateV2.sol";

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

    function testFeatureSupport() public view {
        // StargateAdapter supports asset transfers but not messaging or state reads
        assertTrue(
            adapterA.supportsOperation(BridgeTypes.OperationType.TRANSFER_ASSET)
        );
        assertFalse(
            adapterA.supportsOperation(BridgeTypes.OperationType.MESSAGE)
        );
        assertFalse(
            adapterA.supportsOperation(BridgeTypes.OperationType.READ_STATE)
        );
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
        uint32 newEndpointId = 30110; // LayerZero endpoint ID for Arbitrum

        vm.prank(governor);
        adapterA.addSupportedChain(newChainId, newEndpointId);

        // Verify the chain was added
        assertTrue(adapterA.supportsChain(newChainId));
        assertEq(adapterA.getEndpointId(newChainId), newEndpointId);

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
        adapterA.addSupportedChain(CHAIN_ID_A, uint32(CHAIN_ID_A));
    }

    function testAddSupportedAsset() public {
        useNetworkA();

        // Create a new token
        ERC20Mock newToken = new ERC20Mock();

        // Create a proper mock Stargate contract
        MockStargateV2 mockStargateContract = new MockStargateV2(
            address(newToken),
            MockStargateV2.StargateType.Pool
        );

        // Add the new token as supported asset
        vm.prank(governor);
        adapterA.addSupportedAsset(
            CHAIN_ID_A,
            address(newToken),
            address(mockStargateContract)
        );

        // Verify the asset was added
        assertEq(
            adapterA.getStargateContract(CHAIN_ID_A, address(newToken)),
            address(mockStargateContract)
        );

        // Get the supported assets using getSupportedAssets method
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

    function testAddDuplicateAsset() public {
        useNetworkA();

        // Create a proper mock Stargate contract
        MockStargateV2 newStargateContract = new MockStargateV2(
            address(tokenA),
            MockStargateV2.StargateType.OFT
        );

        // Add the same asset again (should update Stargate contract but not add duplicate)
        vm.prank(governor);
        adapterA.addSupportedAsset(
            CHAIN_ID_A,
            address(tokenA),
            address(newStargateContract)
        );

        // Verify the Stargate contract was updated
        assertEq(
            adapterA.getStargateContract(CHAIN_ID_A, address(tokenA)),
            address(newStargateContract)
        );

        // Get the supported assets using getSupportedAssets method
        address[] memory supportedAssets = adapterA.getSupportedAssets(
            CHAIN_ID_A
        );
        assertEq(supportedAssets.length, 1);
        assertEq(supportedAssets[0], address(tokenA));
    }

    function testAddAssetToUnsupportedChain() public {
        useNetworkA();

        // Create a proper mock Stargate contract for this test
        MockStargateV2 mockStargateContract = new MockStargateV2(
            address(tokenA),
            MockStargateV2.StargateType.Pool
        );

        // Try to add an asset to an unsupported chain
        vm.prank(governor);
        vm.expectRevert(IBridgeAdapter.UnsupportedChain.selector);
        adapterA.addSupportedAsset(
            9999,
            address(tokenA),
            address(mockStargateContract)
        );
    }

    function testAddInvalidAsset() public {
        useNetworkA();

        // Create a proper mock Stargate contract for this test
        MockStargateV2 mockStargateContract = new MockStargateV2(
            address(tokenA),
            MockStargateV2.StargateType.Pool
        );

        // Try to add address(0) as an asset
        vm.prank(governor);
        vm.expectRevert(IBridgeAdapter.InvalidParams.selector);
        adapterA.addSupportedAsset(
            CHAIN_ID_A,
            address(0),
            address(mockStargateContract)
        );
    }
}
