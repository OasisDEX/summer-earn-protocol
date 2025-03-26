// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {LayerZeroAdapterSetupTest} from "./LayerZeroAdapter.setup.t.sol";
import {LayerZeroAdapter} from "../../src/adapters/LayerZeroAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import {console} from "forge-std/console.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
import {MockCrossChainReceiver} from "../../test/mocks/MockCrossChainReceiver.sol";

contract LayerZeroAdapterReceiveTest is LayerZeroAdapterSetupTest {
    // Add a MockCrossChainReceiver instance
    MockCrossChainReceiver public mockReceiver;

    // Override setup to deploy the mock receiver
    function setUp() public override {
        super.setUp();
        mockReceiver = new MockCrossChainReceiver();
    }

    // Implement the executeMessage helper function required by the abstract base test
    function executeMessage(
        uint32 srcEid,
        address srcAdapter,
        address dstAdapter
    ) internal override {
        // For receive tests, we need to simulate LZ message execution properly
        Origin memory origin = Origin({
            srcEid: srcEid,
            sender: addressToBytes32(srcAdapter),
            nonce: 1
        });

        // Get the message from the endpoint or create a default one
        bytes memory payload;
        bytes32 transferId = bytes32(uint256(1)); // Use a consistent transferId

        // Use the appropriate test helper based on the destination
        if (address(dstAdapter) == address(adapterA)) {
            // Create a properly formatted payload for asset transfer
            // Format: messageType (2 bytes) + transferId + tokenAddress + amount + recipient
            payload = abi.encodePacked(
                uint16(1), // MessageType.ASSET_TRANSFER = 1
                abi.encode(
                    transferId,
                    address(tokenB), // Source token on chain B
                    uint256(1 ether), // Amount
                    recipient // Recipient address
                )
            );

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
            payload = abi.encodePacked(
                uint16(1), // MessageType.ASSET_TRANSFER = 1
                abi.encode(
                    transferId,
                    address(tokenA), // Source token on chain A
                    uint256(1 ether), // Amount
                    recipient // Recipient address
                )
            );

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
        useNetworkA();

        // Create a requestId that we'll use for both sending and receiving
        bytes32 requestId = bytes32(uint256(1));

        // Use the test helper's methods to set up the initial state
        routerA.setTransferToAdapter(requestId, address(adapterA));

        // Set the originator for the read request to our mock receiver instead of user
        routerA.setReadRequestOriginator(requestId, address(mockReceiver));

        vm.startPrank(address(this)); // Acting as the test contract
        adapterA.updateTransferStatus(
            requestId,
            BridgeTypes.TransferStatus.PENDING
        );
        vm.stopPrank();

        // Verify pending status on chain A
        assertEq(
            uint256(routerA.transferStatuses(requestId)),
            uint256(BridgeTypes.TransferStatus.PENDING)
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

        useNetworkA(); // Make sure we're on network A

        // Call lzReceiveTest with the proper parameters
        adapterA.lzReceiveTest(
            origin,
            requestId,
            payload,
            address(adapterB),
            bytes("")
        );

        // Verify the request status is now DELIVERED
        assertEq(
            uint256(routerA.transferStatuses(requestId)),
            uint256(BridgeTypes.TransferStatus.DELIVERED)
        );

        // Verify the mock receiver received the correct data
        assertEq(mockReceiver.lastMessageId(), requestId);
        assertEq(
            abi.decode(mockReceiver.lastReceivedData(), (uint256)),
            mockReadValue
        );
    }
}
