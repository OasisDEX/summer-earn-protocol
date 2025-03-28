// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {LayerZeroAdapterSetupTest} from "./LayerZeroAdapter.setup.t.sol";
import {LayerZeroAdapter} from "../../src/adapters/LayerZeroAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";

contract LayerZeroAdapterGeneralTest is LayerZeroAdapterSetupTest {
    // Implement the executeMessage helper function required by the abstract base test
    function executeMessage(
        uint32 srcEid,
        address srcAdapter,
        address dstAdapter
    ) internal {
        // Implementation for general tests
        Origin memory origin = Origin({
            srcEid: srcEid,
            sender: addressToBytes32(srcAdapter),
            nonce: 1
        });

        if (address(dstAdapter) == address(adapterA)) {
            adapterA.lzReceiveTest(
                origin,
                bytes32(uint256(1)), // requestId
                abi.encodePacked(uint16(3), "test payload"), // Simple transfer payload with GENERAL_MESSAGE type
                srcAdapter,
                bytes("")
            );
        } else if (address(dstAdapter) == address(adapterB)) {
            adapterB.lzReceiveTest(
                origin,
                bytes32(uint256(1)), // requestId
                abi.encodePacked(uint16(3), "test payload"), // Simple transfer payload with GENERAL_MESSAGE type
                srcAdapter,
                bytes("")
            );
        }
        // Note: Removed duplicate if conditions
    }

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
        assertFalse(adapterA.supportsChain(2)); // Arbitrary unsupported chain
    }

    function testSupportsAsset() public view {
        // Currently all assets are supported on supported chains
        assertTrue(adapterA.supportsAsset(CHAIN_ID_A, address(tokenA)));
        assertTrue(adapterA.supportsAsset(CHAIN_ID_B, address(tokenB)));
        assertFalse(adapterA.supportsAsset(2, address(tokenA))); // Unsupported chain
    }

    // Update test for UnsupportedMessageType error since type 5 is now COMPOSE
    function testUnsupportedMessageType() public {
        // Create a message with an unsupported type (9 - which doesn't exist)
        bytes memory invalidPayload = abi.encodePacked(
            uint16(9),
            bytes("test payload")
        );

        // Create origin data
        Origin memory origin = Origin({
            srcEid: LZ_EID_B, // Source is chain B
            sender: addressToBytes32(address(adapterB)),
            nonce: 1
        });

        // Expect revert with UnsupportedMessageType
        vm.expectRevert(LayerZeroAdapter.UnsupportedMessageType.selector);

        // Call the test helper's lzReceiveTest function with the invalid payload
        adapterA.lzReceiveTest(
            origin,
            bytes32(uint256(1)), // requestId
            invalidPayload,
            address(adapterB), // sender
            bytes("") // extraData
        );
    }

    function testGetRequiredFeeWithMinGasLimit() public {
        useNetworkA();
        vm.startPrank(governor);

        // Set minimum gas limit for GENERAL_MESSAGE with a high value
        adapterA.setMinGasLimit(adapterA.GENERAL_MESSAGE(), 1000000);

        // Create a simple payload for testing
        bytes memory payload = abi.encodePacked(
            uint16(adapterA.GENERAL_MESSAGE()),
            bytes("test payload")
        );

        // Get required fee directly from adapter
        uint256 requiredFee = adapterA.getRequiredFee(
            LZ_EID_B,
            adapterA.GENERAL_MESSAGE(),
            payload
        );

        // Fee should be non-zero
        assertTrue(requiredFee > 0);

        vm.stopPrank();
    }

    function testSetMinGasLimit() public {
        useNetworkA();

        // Check current value
        uint16 messageType = adapterA.GENERAL_MESSAGE();
        assertEq(adapterA.minGasLimits(messageType), 300000);

        // Try to set minGasLimit as unauthorized address
        vm.prank(address(2));
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                address(2)
            )
        );

        // Actually call the function that should revert
        adapterA.setMinGasLimit(messageType, 600000);
    }

    function testAdapterDirectEstimateFee() public {
        useNetworkA();

        // Create adapter params with a specific gas limit
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                msgValue: 0,
                calldataSize: 0,
                options: bytes("")
            });

        // Call estimateFee directly on the adapter
        (uint256 nativeFee, uint256 tokenFee) = adapterA.estimateFee(
            CHAIN_ID_B,
            address(0), // No asset for general message
            0, // No amount for general message
            adapterParams,
            BridgeTypes.OperationType.MESSAGE
        );

        // Fee should be non-zero
        assertTrue(nativeFee > 0);
        // Token fee should be zero for LayerZero
        assertEq(tokenFee, 0);
    }

    function testAdapterMinGasLimitEnforcement() public {
        useNetworkA();
        vm.startPrank(governor);

        // Set a high minimum gas limit for GENERAL_MESSAGE
        uint128 minGasLimit = 1000000;
        adapterA.setMinGasLimit(adapterA.GENERAL_MESSAGE(), minGasLimit);

        // Create adapter params with a lower gas limit than the minimum
        BridgeTypes.AdapterParams memory lowerParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000, // Lower than our minimum
                msgValue: 0,
                calldataSize: 0,
                options: bytes("")
            });

        // Create adapter params with a higher gas limit than the minimum
        BridgeTypes.AdapterParams memory higherParams = BridgeTypes
            .AdapterParams({
                gasLimit: 1500000, // Higher than our minimum
                msgValue: 0,
                calldataSize: 0,
                options: bytes("")
            });

        // Estimate fees directly with adapter for both cases
        (uint256 lowerFee, ) = adapterA.estimateFee(
            CHAIN_ID_B,
            address(0),
            0,
            lowerParams,
            BridgeTypes.OperationType.MESSAGE
        );

        (uint256 higherFee, ) = adapterA.estimateFee(
            CHAIN_ID_B,
            address(0),
            0,
            higherParams,
            BridgeTypes.OperationType.MESSAGE
        );

        // Higher gas limit should result in a higher fee
        assertTrue(higherFee > lowerFee);

        vm.stopPrank();
    }

    function testSupportsFeatures() public {
        // Test capability flags directly on adapter
        assertTrue(adapterA.supportsMessaging());
        assertTrue(adapterA.supportsStateRead());
        assertFalse(adapterA.supportsAssetTransfer());
    }
}
