// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {LayerZeroAdapterSetupTest} from "./LayerZeroAdapter.setup.t.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";

import {BridgeRouterTestHelper} from "../../test/helpers/BridgeRouterTestHelper.sol";
import {MockCrossChainReceiver} from "../../test/mocks/MockCrossChainReceiver.sol";
import {LayerZeroAdapterSetupTest} from "./LayerZeroAdapter.setup.t.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import {MockCrossChainReceiver} from "../../test/mocks/MockCrossChainReceiver.sol";
import {BridgeRouterTestHelper} from "../../test/helpers/BridgeRouterTestHelper.sol";

contract LayerZeroAdapterReceiveTest is LayerZeroAdapterSetupTest {
    // Add a MockCrossChainReceiver instance
    MockCrossChainReceiver public mockReceiver;

    // Override setup to deploy the mock receiver
    function setUp() public override {
        super.setUp();
        mockReceiver = new MockCrossChainReceiver();
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
}
