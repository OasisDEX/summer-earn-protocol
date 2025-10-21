// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICrossChainRegistry} from "../../../src/interfaces/ICrossChainRegistry.sol";
import {IBridgeAdapter} from "../../../src/interfaces/IBridgeAdapter.sol";
import {BridgeTypes} from "../../../src/libraries/BridgeTypes.sol";
import {LayerZeroAdapterSetupTest} from "./LayerZeroAdapter.setup.t.sol";

import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import {IBaseBridgeAdapterErrors} from "../../../src/interfaces/IBaseBridgeAdapterErrors.sol";

contract LayerZeroAdapterGeneralTest is LayerZeroAdapterSetupTest {
    /*//////////////////////////////////////////////////////////////
                          ADAPTER FEATURES TESTS
    //////////////////////////////////////////////////////////////*/

    function testGetSupportedChains() public view {
        // Get chains through registry relationships
        (, uint16[] memory supportedChains) = registryA.getAllTargetsForSource(
            address(adapterA),
            registryA.PEER_RELATIONSHIP()
        );

        assertEq(supportedChains.length, 1);
        assertEq(supportedChains[0], CHAIN_ID_B);
    }

    function testSupportsChain() public view {
        // First check still works
        assertTrue(
            adapterA.CROSS_CHAIN_REGISTRY().getAdapterPeer(
                address(adapterA),
                CHAIN_ID_B
            ) != address(0),
            "Chain B should be supported"
        );

        // Expect address(0) when unsupported chain is queried
        ICrossChainRegistry registryA = ICrossChainRegistry(
            address(adapterA.CROSS_CHAIN_REGISTRY())
        );
        address peer = registryA.getAdapterPeer(address(adapterA), 2);
        assertEq(
            peer,
            address(0),
            "Unsupported chain should return address(0)"
        );
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
            options: bytes(""),
            payInProtocolToken: false,
            feeTokenAmount: 0
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
            adapterA.supportsOperation(BridgeTypes.OperationType.TRANSFER_ASSET)
        );
    }

    /*//////////////////////////////////////////////////////////////
                        ESTIMATION & VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_estimateTransferAssets_reverts_UnsupportedAsset() public {
        useNetworkA();
        vm.expectRevert(IBridgeAdapter.UnsupportedAsset.selector);
        adapterA.estimateTransferAssets(
            BridgeTypes.ExecuteTransferParams({
                originator: address(this),
                destinationChainId: CHAIN_ID_B,
                target: address(this),
                asset: address(0), // Unsupported asset
                amount: 0,
                message: bytes(""),
                refundAddress: address(this)
            }),
            BridgeTypes.BridgeOptions({
                specifiedAdapter: address(adapterA),
                gasLimit: 100000,
                calldataSize: 0,
                msgValue: 0,
                options: bytes(""),
                payInProtocolToken: false,
                feeTokenAmount: 0
            })
        );
    }

    function test_estimateSendMessage_reverts_when_gasLimit_zero() public {
        useNetworkA();

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 0, // Zero gas limit should cause revert
            calldataSize: 0,
            msgValue: 0,
            options: bytes(""),
            payInProtocolToken: false,
            feeTokenAmount: 0
        });

        vm.expectRevert(IBaseBridgeAdapterErrors.InvalidParams.selector);
        adapterA.estimateSendMessage(
            BridgeTypes.ExecuteSendMessageParams({
                destinationChainId: CHAIN_ID_B,
                target: address(0x1234),
                message: abi.encode("test"),
                originator: address(this),
                refundAddress: address(this)
            }),
            options
        );
    }

    /*//////////////////////////////////////////////////////////////
                          RECEIVE VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_receive_reverts_on_invalid_source_chain_id() public {
        useNetworkA();

        // Create a payload with MESSAGE type
        bytes memory payload = abi.encodePacked(
            uint16(BridgeTypes.OperationType.MESSAGE),
            abi.encode(
                BridgeTypes.RelayedMessageParams({
                    operationId: bytes32(uint256(1)),
                    originator: address(this),
                    sourceChainId: uint16(999), // Invalid source chain ID
                    recipient: address(this),
                    message: abi.encode("test")
                })
            )
        );

        Origin memory origin = Origin({
            srcEid: LZ_EID_B,
            sender: addressToBytes32(address(adapterB)),
            nonce: 1
        });

        vm.expectRevert(IBaseBridgeAdapterErrors.InvalidSourceChainId.selector);
        adapterA.lzReceiveTest(
            origin,
            bytes32(uint256(1)),
            payload,
            address(adapterB),
            bytes("")
        );
    }

    function test_receive_reverts_when_sender_untrusted() public {
        useNetworkA();

        // Create a payload with MESSAGE type
        bytes memory payload = abi.encodePacked(
            uint16(BridgeTypes.OperationType.MESSAGE),
            abi.encode(
                BridgeTypes.RelayedMessageParams({
                    operationId: bytes32(uint256(1)),
                    originator: address(this),
                    sourceChainId: uint16(CHAIN_ID_B),
                    recipient: address(this),
                    message: abi.encode("test")
                })
            )
        );

        Origin memory origin = Origin({
            srcEid: LZ_EID_B,
            sender: addressToBytes32(address(0x1234)), // Untrusted sender
            nonce: 1
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IBaseBridgeAdapterErrors.UntrustedSourceAdapter.selector,
                address(0x1234),
                CHAIN_ID_B
            )
        );
        adapterA.lzReceiveTest(
            origin,
            bytes32(uint256(1)),
            payload,
            address(0x1234),
            bytes("")
        );
    }
}
