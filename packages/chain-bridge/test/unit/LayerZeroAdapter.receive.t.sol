// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {LayerZeroAdapterSetupTest} from "./LayerZeroAdapter.setup.t.sol";
import {LayerZeroAdapter} from "../../src/adapters/LayerZeroAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import {console} from "forge-std/console.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
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

    // Modify the executeMessage function to accept a message type parameter
    function executeMessage(
        uint32 srcEid,
        address srcAdapter,
        address dstAdapter,
        uint16 messageType // Add messageType parameter
    ) internal {
        // For receive tests, we need to simulate LZ message execution properly
        Origin memory origin = Origin({
            srcEid: srcEid,
            sender: addressToBytes32(srcAdapter),
            nonce: 1
        });

        // Get the message from the endpoint or create a default one
        bytes memory payload;
        bytes32 transferId = bytes32(uint256(1)); // Use a consistent transferId

        // Special handling for read responses
        if (srcEid > adapterA.READ_CHANNEL_THRESHOLD()) {
            // For read responses, we need different handling
            uint256 mockReadValue = 123456; // Mock balance value
            bytes memory responseData = abi.encode(mockReadValue);

            // Use the provided message type
            payload = abi.encodePacked(
                messageType, // Use the provided message type
                responseData
            );

            // Call the adapter directly with the origin indicating it's a read response
            adapterA.lzReceiveTest(
                origin,
                transferId,
                payload,
                srcAdapter,
                bytes("")
            );
            return;
        }

        // Standard message handling for non-read messages
        // Use the appropriate test helper based on the destination
        if (address(dstAdapter) == address(adapterA)) {
            payload = _createPayload(messageType, transferId);

            try
                adapterA.lzReceiveTest(
                    origin,
                    transferId,
                    payload,
                    srcAdapter,
                    bytes("")
                )
            {
                console.log("Message executed successfully on Chain A");
            } catch Error(string memory reason) {
                console.log("Execution failed on Chain A with reason:");
                console.log(reason);
                revert(reason);
            } catch (bytes memory) {
                console.log("Execution failed on Chain A with no reason");
                revert("Execution failed on Chain A with no reason");
            }
        } else if (address(dstAdapter) == address(adapterB)) {
            // Create a properly formatted payload for asset transfer
            payload = _createPayload(messageType, transferId);

            try
                adapterB.lzReceiveTest(
                    origin,
                    transferId,
                    payload,
                    srcAdapter,
                    bytes("")
                )
            {
                console.log("Message executed successfully on Chain B");
            } catch Error(string memory reason) {
                console.log("Execution failed on Chain B with reason:");
                console.log(reason);
                revert(reason);
            } catch (bytes memory) {
                console.log("Execution failed on Chain B with no reason");
                revert("Execution failed on Chain B with no reason");
            }
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
        assertEq(
            abi.decode(mockReceiver.lastReceivedData(), (uint256)),
            mockReadValue
        );
    }
}
