// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {LayerZeroAdapterSetupTest} from "./LayerZeroAdapter.setup.t.sol";
import {LayerZeroAdapter} from "../../src/adapters/LayerZeroAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import {console} from "forge-std/console.sol";
contract LayerZeroAdapterReceiveTest is LayerZeroAdapterSetupTest {
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
                testHelperA.lzReceiveTest(
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
                testHelperB.lzReceiveTest(
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

    /*//////////////////////////////////////////////////////////////
                        DIRECT RECEIVE FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function testReceiveAssetTransferReverts() public {
        // Try to call receiveAssetTransfer directly, which should revert
        vm.expectRevert(LayerZeroAdapter.UseLayerZeroMessaging.selector);
        adapterA.receiveAssetTransfer(
            address(tokenA),
            100 ether,
            recipient,
            CHAIN_ID_B,
            bytes32(uint256(1)),
            ""
        );
    }

    function testReceiveMessageReverts() public {
        // Try to call receiveMessage directly, which should revert
        vm.expectRevert(LayerZeroAdapter.UseLayerZeroMessaging.selector);
        adapterA.receiveMessage(
            bytes("test message"),
            recipient,
            CHAIN_ID_B,
            bytes32(uint256(1))
        );
    }

    function testReceiveStateReadReverts() public {
        // Try to call receiveStateRead directly, which should revert
        vm.expectRevert(LayerZeroAdapter.UseLayerZeroMessaging.selector);
        adapterA.receiveStateRead(
            bytes("test data"),
            recipient,
            CHAIN_ID_B,
            bytes32(uint256(1))
        );
    }

    function testHandleAssetTransferMessage() public {
        useNetworkA();
        vm.deal(user, 1 ether);

        // Setup: Initiate a transfer from chain A to B
        vm.startPrank(user);
        // Approve tokens
        tokenA.approve(address(routerA), 1 ether);

        // Transfer from A to B
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                msgValue: 0,
                calldataSize: 0,
                options: bytes("")
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            adapterParams: adapterParams
        });

        bytes32 transferId = routerA.transferAssets{value: 0.1 ether}(
            CHAIN_ID_B,
            address(tokenA),
            1 ether,
            recipient,
            options
        );
        vm.stopPrank();

        // Verify pending status on chain A
        assertEq(
            uint256(routerA.transferStatuses(transferId)),
            uint256(BridgeTypes.TransferStatus.PENDING)
        );

        // Switch to network B and execute the LZ message
        useNetworkB();

        // Simulate message execution on chain B
        executeMessage(LZ_EID_A, address(adapterA), address(adapterB));

        // Verify transfer was completed on chain B
        assertEq(
            uint256(routerB.transferStatuses(transferId)),
            uint256(BridgeTypes.TransferStatus.COMPLETED)
        );
    }

    function testHandleStateReadMessage() public {
        useNetworkA();
        vm.deal(user, 1 ether);

        // Setup: Initiate a state read from chain A to B
        vm.startPrank(user);

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                msgValue: 0,
                calldataSize: 0,
                options: bytes("")
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            adapterParams: adapterParams
        });

        bytes32 requestId = routerA.readState{value: 0.1 ether}(
            CHAIN_ID_B,
            address(tokenB),
            bytes4(keccak256("balanceOf(address)")),
            abi.encode(recipient),
            options
        );
        vm.stopPrank();

        // Verify pending status on chain A
        assertEq(
            uint256(routerA.transferStatuses(requestId)),
            uint256(BridgeTypes.TransferStatus.PENDING)
        );

        // Switch to network B and execute the LZ message
        useNetworkB();

        // Simulate message execution on chain B
        executeMessage(LZ_EID_A, address(adapterA), address(adapterB));

        // Switch back to A and simulate the response message
        useNetworkA();
        executeMessage(LZ_EID_B, address(adapterB), address(adapterA));

        // Verify request was completed on chain A
        assertEq(
            uint256(routerA.transferStatuses(requestId)),
            uint256(BridgeTypes.TransferStatus.COMPLETED)
        );
    }

    function testHandleGeneralMessage() public {
        useNetworkA();
        vm.deal(user, 1 ether);

        vm.startPrank(user);

        // Create sample actions - we'll use composeActions with a single action
        // since sendMessage doesn't exist in BridgeRouter
        bytes[] memory actions = new bytes[](1);
        actions[0] = abi.encode("Test message"); // Our message as a single action

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                msgValue: 0,
                calldataSize: 0,
                options: bytes("")
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            adapterParams: adapterParams
        });

        // Use composeActions instead of sendMessage
        bytes32 messageId = routerA.composeActions{value: 0.1 ether}(
            CHAIN_ID_B,
            actions,
            options
        );
        vm.stopPrank();

        // Verify pending status on chain A
        assertEq(
            uint256(routerA.transferStatuses(messageId)),
            uint256(BridgeTypes.TransferStatus.PENDING)
        );

        // Switch to network B and execute the LZ message
        useNetworkB();

        // Simulate message execution on chain B
        executeMessage(LZ_EID_A, address(adapterA), address(adapterB));

        // Verify message was delivered on chain B
        assertEq(
            uint256(routerB.transferStatuses(messageId)),
            uint256(BridgeTypes.TransferStatus.COMPLETED)
        );
    }

    function testHandleComposeMessage() public {
        useNetworkA();
        vm.deal(user, 1 ether);

        vm.startPrank(user);

        // Create sample actions to compose
        bytes[] memory actions = new bytes[](2);
        actions[0] = abi.encodeWithSignature(
            "sampleAction1(address,uint256)",
            recipient,
            100
        );
        actions[1] = abi.encodeWithSignature(
            "sampleAction2(address,bool)",
            recipient,
            true
        );

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                msgValue: 0,
                calldataSize: 0,
                options: bytes("")
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            adapterParams: adapterParams
        });

        bytes32 requestId = routerA.composeActions{value: 0.1 ether}(
            CHAIN_ID_B,
            actions,
            options
        );
        vm.stopPrank();

        // Verify pending status on chain A
        assertEq(
            uint256(routerA.transferStatuses(requestId)),
            uint256(BridgeTypes.TransferStatus.PENDING)
        );

        // Switch to network B and execute the LZ message
        useNetworkB();

        // Simulate message execution on chain B
        executeMessage(LZ_EID_A, address(adapterA), address(adapterB));

        // Verify request was completed on chain B
        assertEq(
            uint256(routerB.transferStatuses(requestId)),
            uint256(BridgeTypes.TransferStatus.COMPLETED)
        );
    }
}
