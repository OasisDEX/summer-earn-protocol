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

    /// @dev Creates a payload for standard messages based on message type and transfer ID
    /// @param messageType The type of message (2 for STATE_READ, 3 for GENERAL_MESSAGE)
    /// @param transferId The transfer ID to include in the payload
    /// @return payload The encoded payload bytes
    function _createPayload(
        uint16 messageType,
        bytes32 transferId
    ) internal pure returns (bytes memory payload) {
        if (messageType == 2) {
            // STATE_READ
            // Format for state read message
            payload = abi.encodePacked(
                messageType,
                abi.encode(transferId, bytes("Read data payload"))
            );
        } else if (messageType == 3) {
            // GENERAL_MESSAGE
            // Format for general message
            payload = abi.encodePacked(
                messageType,
                abi.encode("General message payload")
            );
        } else {
            // Unknown message type
            revert("Unknown message type");
        }
    }

    function testStateRead() public {
        // Create a operationId that we'll use for both sending and receiving
        bytes32 operationId = bytes32(uint256(1));

        // Use the test helper's methods to set up the initial state
        routerA.setOperationToAdapter(operationId, address(adapterA));

        // Set the originator for the read request to our mock receiver instead of user
        routerA.setReadRequestOriginator(operationId, address(mockReceiver));

        // Set the initial status using the test helper
        BridgeRouterTestHelper(address(routerA)).setOperationStatus(
            operationId,
            BridgeTypes.OperationStatus.SENT
        );

        // Verify SENT status on chain A
        assertEq(
            uint256(routerA.operationStatuses(operationId)),
            uint256(BridgeTypes.OperationStatus.SENT)
        );

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
        // Call lzReceiveTest with the proper parameters
        adapterA.lzReceiveTest(
            origin,
            guid,
            payload,
            address(adapterB),
            bytes("")
        );

        // Verify the request status is now SENT (since we only have QUEUED, SENT, and FAILED)
        assertEq(
            uint256(routerA.operationStatuses(operationId)),
            uint256(BridgeTypes.OperationStatus.SENT)
        );

        // Verify the mock receiver received the correct data
        BridgeTypes.ReadResponse memory response = abi.decode(
            mockReceiver.lastReceivedData(),
            (BridgeTypes.ReadResponse)
        );
        assertEq(abi.decode(response.data, (uint256)), mockReadValue);
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
            uint16(3), // GENERAL_MESSAGE type
            abi.encode(message, recipient, messageId)
        );

        // Mock expectations for BridgeRouter.deliver call
        vm.expectCall(
            address(routerA),
            abi.encodeCall(
                IBridgeRouter.deliver,
                (messageId, CHAIN_ID_B, address(0), 0, recipient, message)
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
