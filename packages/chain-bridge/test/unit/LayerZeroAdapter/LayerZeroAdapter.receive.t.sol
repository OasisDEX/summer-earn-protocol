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

    function test_readResponse_clears_state_after_delivery() public {
        // Arrange a valid read response flow
        bytes32 operationId = bytes32(uint256(42));
        routerA.setOperationToAdapter(operationId, address(adapterA));
        bytes memory responseData = abi.encode(uint256(999));
        bytes memory payload = responseData; // read response payload is raw result

        Origin memory origin = Origin({
            srcEid: READ_CHANNEL_THRESHOLD + 1, // mark as read response
            sender: addressToBytes32(address(adapterB)),
            nonce: 1
        });

        bytes32 guid = keccak256("read-guid");
        adapterA.setLzMessageToOperationId(guid, operationId);
        adapterA.setExpectedReadChainByGuid(guid, CHAIN_ID_B);

        // Act
        adapterA.lzReceiveTest(
            origin,
            guid,
            payload,
            address(adapterB),
            bytes("")
        );

        // Assert: the mappings are cleared
        // We cannot directly read private mapping from here, but a second delivery with same guid should emit not found
        vm.expectEmit(true, false, false, true);
        emit IMessageAdapter.ReadOperationNotFound(
            guid,
            "No operationId found"
        );
        adapterA.lzReceiveTest(
            origin,
            guid,
            payload,
            address(adapterB),
            bytes("")
        );
    }

    function testStateRead() public {
        // Create a operationId that we'll use for both sending and receiving
        bytes32 operationId = bytes32(uint256(1));

        // Use the test helper's methods to set up the initial state
        routerA.setOperationToAdapter(operationId, address(adapterA));

        // Set the originator for the read request to our mock receiver instead of user
        routerA.setReadRequestOriginator(operationId, address(mockReceiver));

        // Create read response payload
        uint256 mockReadValue = 123456; // Mock balance value
        bytes memory responseData = abi.encode(mockReadValue);

        // Format the state read response appropriately
        bytes memory payload = responseData; // For read responses, the payload is just the result data

        // Create origin with special READ_CHANNEL_THRESHOLD to simulate read response
        Origin memory origin = Origin({
            srcEid: 4294965695, // Above READ_CHANNEL_THRESHOLD to indicate read response
            sender: addressToBytes32(address(adapterB)),
            nonce: 1
        });

        bytes32 guid = keccak256(abi.encodePacked(payload));

        adapterA.setLzMessageToOperationId(guid, operationId);
        // Ensure expected chain is set so _relayReadResponse passes trust checks
        adapterA.setExpectedReadChainByGuid(guid, CHAIN_ID_B);
        // Call lzReceiveTest with the proper parameters
        adapterA.lzReceiveTest(
            origin,
            guid,
            payload,
            address(adapterB),
            bytes("")
        );

        assertEq(
            abi.decode(mockReceiver.lastReceivedData(), (uint256)),
            mockReadValue
        );
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

    function test_readResponse_withoutOperationId_emitsEvent_and_returns()
        public
    {
        Origin memory origin = Origin({
            srcEid: READ_CHANNEL_THRESHOLD + 1,
            sender: addressToBytes32(address(adapterB)),
            nonce: 1
        });

        bytes32 unknownGuid = keccak256("no-op");
        bytes memory readPayload = abi.encodePacked(uint256(123));

        vm.expectEmit(true, false, false, true);
        emit IMessageAdapter.ReadOperationNotFound(
            unknownGuid,
            "No operationId found"
        );

        adapterA.lzReceiveTest(
            origin,
            unknownGuid,
            readPayload,
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
