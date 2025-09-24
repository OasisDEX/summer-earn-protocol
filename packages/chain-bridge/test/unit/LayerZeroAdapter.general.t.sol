// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {LayerZeroAdapter} from "../../src/adapters/LayerZeroAdapter.sol";

import {ICrossChainRegistry} from "../../src/interfaces/ICrossChainRegistry.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {LayerZeroAdapterSetupTest} from "./LayerZeroAdapter.setup.t.sol";

import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";

contract LayerZeroAdapterGeneralTest is LayerZeroAdapterSetupTest {
    /*//////////////////////////////////////////////////////////////
                          ADAPTER FEATURES TESTS
    //////////////////////////////////////////////////////////////*/

    function testGetSupportedChains() public view {
        // Get chains through registry relationships
        (, uint16[] memory supportedChains) = registryA.getTargetsForSource(
            address(adapterA),
            registryA.PEER_RELATIONSHIP()
        );

        assertEq(supportedChains.length, 1);
        assertEq(supportedChains[0], CHAIN_ID_B);
    }

    function testSupportsChain() public {
        // First check still works
        assertTrue(
            adapterA.CROSS_CHAIN_REGISTRY().getAdapterPeer(
                address(adapterA),
                CHAIN_ID_B
            ) != address(0),
            "Chain B should be supported"
        );

        // Expect revert when unsupported chain is queried
        ICrossChainRegistry registryA = ICrossChainRegistry(
            address(adapterA.CROSS_CHAIN_REGISTRY())
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                address(adapterA),
                registryA.PEER_RELATIONSHIP(),
                2
            )
        );
        registryA.getAdapterPeer(address(adapterA), 2);
    }

    // Update test for UnsupportedMessageType error: use a valid but unsupported op (TRANSFER_ASSET)
    function test_reverts_on_unsupported_operation_type_in_receive() public {
        // Create a payload where op type is TRANSFER_ASSET (unsupported by LZ receive path)
        bytes memory invalidPayload = abi.encodePacked(
            uint16(BridgeTypes.OperationType.TRANSFER_ASSET),
            bytes("test payload")
        );

        // Create origin data
        Origin memory origin = Origin({
            srcEid: LZ_EID_B, // Source is chain B
            sender: addressToBytes32(address(adapterB)),
            nonce: 1
        });

        // Expect revert with UnsupportedMessageType
        vm.expectRevert(IBridgeAdapter.UnsupportedMessageType.selector);

        // Call the test helper's lzReceiveTest function with the invalid payload
        adapterA.lzReceiveTest(
            origin,
            bytes32(uint256(1)), // requestId
            invalidPayload,
            address(adapterB), // sender
            bytes("") // extraData
        );
    }

    // Duplicate of send suite fee estimate; keep single assertion in send tests
    function testAdapterDirectEstimateFee() public {
        useNetworkA();

        // Create adapter params with a specific gas limit
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: bytes("")
        });

        // Call estimateSendMessage directly on the adapter
        (uint256 nativeFee, uint256 tokenFee) = adapterA.estimateSendMessage(
            BridgeTypes.ExecuteSendMessageParams({
                destinationChainId: CHAIN_ID_B,
                target: address(0x1234), // Target contract
                message: abi.encode("Test message"),
                originator: address(this),
                refundAddress: address(this)
            }),
            options
        );

        // Fee should be non-zero
        assertTrue(nativeFee > 0);
        // Token fee should be zero for LayerZero
        assertEq(tokenFee, 0);
    }

    function testSupportsFeatures() public view {
        // Test capability flags directly on adapter
        assertTrue(
            adapterA.supportsOperation(BridgeTypes.OperationType.MESSAGE)
        );
        assertTrue(
            adapterA.supportsOperation(BridgeTypes.OperationType.READ_STATE)
        );
        assertFalse(
            adapterA.supportsOperation(BridgeTypes.OperationType.TRANSFER_ASSET)
        );
    }

    function testActivateAndUpdateReadChannel() public {
        useNetworkA();

        // Initially unset
        assertEq(adapterA.readChannelId(), 0);

        uint32 baseThreshold = adapterA.readChannelThreshold();
        uint32 firstChannelId = baseThreshold + 1;
        uint32 secondChannelId = baseThreshold + 2;

        vm.startPrank(governor);
        vm.expectEmit(true, false, false, true);
        emit LayerZeroAdapter.ReadChannelActivated(firstChannelId);
        adapterA.activateReadChannel(firstChannelId);
        assertEq(adapterA.readChannelId(), firstChannelId);

        // Update to a new read channel
        vm.expectEmit(true, false, false, true);
        emit LayerZeroAdapter.ReadChannelActivated(secondChannelId);
        adapterA.activateReadChannel(secondChannelId);
        assertEq(adapterA.readChannelId(), secondChannelId);
        assertEq(adapterA.peers(firstChannelId), bytes32(0));
        vm.stopPrank();
    }

    // Note: Role enforcement for activating the read channel is covered elsewhere via access manager tests
}
