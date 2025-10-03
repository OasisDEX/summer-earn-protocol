// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {LayerZeroAdapterSetupTest} from "./LayerZeroAdapter.setup.t.sol";
import {BridgeTypes} from "../../../src/libraries/BridgeTypes.sol";
import {IBridgeRouter} from "../../../src/interfaces/IBridgeRouter.sol";
import {IBridgeAdapter} from "../../../src/interfaces/IBridgeAdapter.sol";
import {IMessageAdapter} from "../../../src/interfaces/IMessageAdapter.sol";

import {BridgeRouterTestHelper} from "../../helpers/BridgeRouterTestHelper.sol";
import {MockCrossChainReceiver} from "../../mocks/MockCrossChainReceiver.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import {BaseBridgeAdapter} from "../../../src/base/BaseBridgeAdapter.sol";

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
}
