// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {LayerZeroAdapterSetupTest} from "./LayerZeroAdapter.setup.t.sol";
import {BridgeTypes} from "../../../src/libraries/BridgeTypes.sol";
import {IBridgeRouter} from "../../../src/interfaces/IBridgeRouter.sol";
import {IBridgeAdapter} from "../../../src/interfaces/IBridgeAdapter.sol";
import {IBaseBridgeAdapterErrors} from "../../../src/interfaces/IBaseBridgeAdapterErrors.sol";

import {MockCrossChainReceiver} from "../../mocks/MockCrossChainReceiver.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";

contract LayerZeroAdapterReceiveTest is LayerZeroAdapterSetupTest {
    // Add a MockCrossChainReceiver instance
    MockCrossChainReceiver public mockReceiver;

    // Override setup to deploy the mock receiver
    function setUp() public override {
        super.setUp();
        mockReceiver = new MockCrossChainReceiver();
    }

    function testGeneralMessageDelivery() public {
        bytes32 messageId = bytes32(uint256(1));
        bytes memory message = "test message";
        address recipient = address(mockReceiver);

        // Create origin data
        Origin memory origin = Origin({
            srcEid: LZ_EID_B,
            sender: addressToBytes32(address(adapterB)),
            nonce: 1
        });

        // Create payload with GENERAL_MESSAGE type
        bytes memory payload = abi.encodePacked(
            uint16(BridgeTypes.OperationType.MESSAGE), // GENERAL_MESSAGE type
            abi.encode(
                BridgeTypes.RelayedMessageParams({
                    operationId: messageId,
                    originator: address(adapterA),
                    sourceChainId: uint16(CHAIN_ID_B),
                    recipient: recipient,
                    message: message
                })
            )
        );

        // Mock expectations for BridgeRouter.deliver call
        vm.expectCall(
            address(routerA),
            abi.encodeCall(
                IBridgeRouter.deliver,
                (
                    BridgeTypes.OperationType.MESSAGE,
                    abi.encode(
                        BridgeTypes.RelayedMessageParams({
                            operationId: messageId,
                            originator: address(adapterA),
                            sourceChainId: uint16(CHAIN_ID_B),
                            recipient: recipient,
                            message: message
                        })
                    )
                )
            )
        );

        // Execute the message
        adapterA.lzReceiveTest(
            origin,
            messageId,
            payload,
            address(adapterB),
            bytes("")
        );
    }

    function test_receive_with_short_payload_reverts_UnsupportedMessageType()
        public
    {
        Origin memory origin = Origin({
            srcEid: LZ_EID_B,
            sender: addressToBytes32(address(adapterB)),
            nonce: 1
        });

        bytes memory tooShortPayload = hex"01";

        vm.expectRevert(IBridgeAdapter.UnsupportedMessageType.selector);

        adapterA.lzReceiveTest(
            origin,
            bytes32(uint256(1)),
            tooShortPayload,
            address(adapterB),
            bytes("")
        );
    }

    /*//////////////////////////////////////////////////////////////
                        SECURITY VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testLzReceiveRevertsWhenUntrustedSourceAdapter() public {
        bytes32 messageId = bytes32(uint256(1));
        bytes memory message = "test message";
        address recipient = address(mockReceiver);

        // Create origin data with untrusted source adapter
        Origin memory origin = Origin({
            srcEid: LZ_EID_B,
            sender: addressToBytes32(address(0xBAD)), // untrusted source
            nonce: 1
        });

        // Create payload with MESSAGE type
        bytes memory payload = abi.encodePacked(
            uint16(BridgeTypes.OperationType.MESSAGE),
            abi.encode(
                BridgeTypes.RelayedMessageParams({
                    operationId: messageId,
                    originator: address(0xBAD), // untrusted source
                    sourceChainId: uint16(CHAIN_ID_B),
                    recipient: recipient,
                    message: message
                })
            )
        );

        // Should revert when source adapter is not trusted
        vm.expectRevert(
            abi.encodeWithSelector(
                IBaseBridgeAdapterErrors.UntrustedSourceAdapter.selector,
                address(0xBAD), // untrusted source
                CHAIN_ID_B // source chain
            )
        );

        adapterA.lzReceiveTest(
            origin,
            messageId,
            payload,
            address(0xBAD), // untrusted source
            bytes("")
        );
    }

    function testLzReceiveRevertsWhenChainIdMismatch() public {
        bytes32 messageId = bytes32(uint256(1));
        bytes memory message = "test message";
        address recipient = address(mockReceiver);

        // Create origin data with mismatched chain ID
        Origin memory origin = Origin({
            srcEid: LZ_EID_B, // This maps to CHAIN_ID_B
            sender: addressToBytes32(address(adapterB)),
            nonce: 1
        });

        // Create payload with different source chain ID
        bytes memory payload = abi.encodePacked(
            uint16(BridgeTypes.OperationType.MESSAGE),
            abi.encode(
                BridgeTypes.RelayedMessageParams({
                    operationId: messageId,
                    originator: address(adapterB),
                    sourceChainId: uint16(999), // wrong chain ID
                    recipient: recipient,
                    message: message
                })
            )
        );

        // Should revert when chain ID doesn't match srcEid
        vm.expectRevert(IBaseBridgeAdapterErrors.InvalidSourceChainId.selector);

        adapterA.lzReceiveTest(
            origin,
            messageId,
            payload,
            address(adapterB),
            bytes("")
        );
    }

    function testLzReceiveRevertsWhenUnauthorizedCaller() public {
        bytes32 messageId = bytes32(uint256(1));
        bytes memory message = "test message";
        address recipient = address(mockReceiver);

        // Create origin data
        Origin memory origin = Origin({
            srcEid: LZ_EID_B,
            sender: addressToBytes32(address(adapterB)),
            nonce: 1
        });

        // Create payload with MESSAGE type
        bytes memory payload = abi.encodePacked(
            uint16(BridgeTypes.OperationType.MESSAGE),
            abi.encode(
                BridgeTypes.RelayedMessageParams({
                    operationId: messageId,
                    originator: address(adapterB),
                    sourceChainId: uint16(CHAIN_ID_B),
                    recipient: recipient,
                    message: message
                })
            )
        );

        // Call from unauthorized caller (not LayerZero endpoint)
        // This should be blocked by OApp's internal validation
        vm.prank(address(0x1234567890123456789012345678901234567890));
        vm.expectRevert(); // Should revert due to unauthorized caller

        adapterA.lzReceiveTest(
            origin,
            messageId,
            payload,
            address(0x1234567890123456789012345678901234567890),
            bytes("")
        );
    }

    function testLzReceiveSuccessWithValidPeerAdapter() public {
        bytes32 messageId = bytes32(uint256(1));
        bytes memory message = "test message";
        address recipient = address(mockReceiver);

        // Create origin data with valid peer adapter
        Origin memory origin = Origin({
            srcEid: LZ_EID_B,
            sender: addressToBytes32(address(adapterB)), // trusted peer
            nonce: 1
        });

        // Create payload with MESSAGE type
        bytes memory payload = abi.encodePacked(
            uint16(BridgeTypes.OperationType.MESSAGE),
            abi.encode(
                BridgeTypes.RelayedMessageParams({
                    operationId: messageId,
                    originator: address(adapterB),
                    sourceChainId: uint16(CHAIN_ID_B),
                    recipient: recipient,
                    message: message
                })
            )
        );

        // Mock expectations for BridgeRouter.deliver call
        vm.expectCall(
            address(routerA),
            abi.encodeCall(
                IBridgeRouter.deliver,
                (
                    BridgeTypes.OperationType.MESSAGE,
                    abi.encode(
                        BridgeTypes.RelayedMessageParams({
                            operationId: messageId,
                            originator: address(adapterB),
                            sourceChainId: uint16(CHAIN_ID_B),
                            recipient: recipient,
                            message: message
                        })
                    )
                )
            )
        );

        // Execute the message - should succeed with valid peer adapter
        adapterA.lzReceiveTest(
            origin,
            messageId,
            payload,
            address(adapterB), // trusted peer
            bytes("")
        );
    }
}
