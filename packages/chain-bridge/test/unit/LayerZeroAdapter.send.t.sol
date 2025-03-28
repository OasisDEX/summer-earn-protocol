// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {LayerZeroAdapterSetupTest} from "./LayerZeroAdapter.setup.t.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {IExecutorFeeLib} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/interfaces/IExecutorFeeLib.sol";
import {Errors} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/Errors.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import {ICrossChainReceiver} from "../../src/interfaces/ICrossChainReceiver.sol";
import {MockCrossChainReceiver} from "../../test/mocks/MockCrossChainReceiver.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
contract LayerZeroAdapterSendTest is LayerZeroAdapterSetupTest {
    using OptionsBuilder for bytes;

    // Add a MockCrossChainReceiver instance to test direct message delivery
    MockCrossChainReceiver public mockReceiver;

    // Override setup to deploy the mock receiver
    function setUp() public override {
        super.setUp();
        mockReceiver = new MockCrossChainReceiver();
    }

    function testDirectReadState() public {
        useNetworkA();

        // Create adapter params with empty options
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 100,
                msgValue: 0,
                options: bytes("")
            });

        // Call readState directly on the adapter
        vm.mockCall(
            address(routerA),
            abi.encodeWithSelector(routerA.setOperationToAdapter.selector),
            abi.encode()
        );

        vm.mockCall(
            address(routerA),
            abi.encodeWithSelector(routerA.setReadRequestOriginator.selector),
            abi.encode()
        );

        bytes32 requestId = keccak256(
            abi.encode(
                CHAIN_ID_B,
                address(tokenB),
                bytes4(keccak256("balanceOf(address)")),
                abi.encode(recipient),
                block.timestamp,
                address(user)
            )
        );

        routerA.setOperationToAdapter(requestId, address(adapterA));

        vm.startPrank(governor);
        adapterA.setReadChannel(adapterA.READ_CHANNEL_THRESHOLD() + 1, true);
        vm.stopPrank();

        // We expect this call to revert with LZ_DefaultSendLibUnavailable
        // This is because the LayerZeroOptionsHelper.createLzReadOptions is creating
        // options of type 5, which is not supported by the mock executor when !_isRead
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LZ_DefaultSendLibUnavailable.selector)
        );
        vm.deal(address(routerA), 1 ether);
        vm.prank(address(routerA));
        adapterA.readState{value: 0.1 ether}(
            CHAIN_ID_A,
            CHAIN_ID_B,
            address(tokenB),
            bytes4(keccak256("balanceOf(address)")),
            abi.encode(recipient),
            address(user),
            adapterParams
        );
    }

    function testDirectSendMessage() public {
        useNetworkA();
        vm.deal(user, 1 ether);

        vm.startPrank(address(routerA)); // Pretend to be the router for authorization

        // Create a test message to send cross-chain
        bytes memory message = abi.encode("Hello from Chain A!");

        // Create adapter params with appropriate gas limit for GENERAL_MESSAGE
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: bytes("")
            });

        bytes32 requestId = keccak256(
            abi.encode(
                CHAIN_ID_A,
                CHAIN_ID_B,
                recipient,
                message,
                block.timestamp
            )
        );

        routerA.setOperationToAdapter(requestId, address(adapterA));

        vm.deal(address(routerA), 1 ether);
        // Call sendMessage directly on the adapter
        bytes32 messageId = adapterA.sendMessage{value: 0.1 ether}(
            CHAIN_ID_B,
            recipient,
            message,
            address(user),
            adapterParams
        );

        // Verify messageId is not empty
        assertTrue(messageId != bytes32(0), "Message ID should not be empty");

        vm.stopPrank();
    }

    function testDirectEstimateFee() public {
        useNetworkA();

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                msgValue: 0,
                calldataSize: 0,
                options: bytes("")
            });

        // Call estimateFee directly on the adapter
        (uint256 nativeFee, uint256 tokenFee) = adapterA.estimateFee(
            CHAIN_ID_B,
            address(tokenA),
            1 ether,
            adapterParams,
            BridgeTypes.OperationType.MESSAGE
        );

        assertTrue(nativeFee > 0, "Native fee should be greater than 0");
        assertEq(tokenFee, 0, "Token fee should be 0 for LayerZero adapter");
    }

    function testMessageDelivery() public {
        useNetworkA();

        // Set up message parameters
        bytes memory message = abi.encode("Test message from Chain A");
        bytes32 guid = keccak256(abi.encode("unique-id"));
        bytes32 operationId = keccak256(abi.encode("more-unique-id"));

        // Create origin information
        Origin memory origin = Origin({
            srcEid: LZ_EID_B,
            sender: addressToBytes32(address(adapterB)),
            nonce: 1
        });

        // Format the payload as GENERAL_MESSAGE type with recipient info
        bytes memory payload = abi.encodePacked(
            uint16(adapterA.GENERAL_MESSAGE()),
            abi.encode(message, address(mockReceiver), operationId)
        );

        // Mock the router's notifyMessageReceived function
        vm.mockCall(
            address(routerA),
            abi.encodeWithSelector(routerA.notifyMessageReceived.selector),
            abi.encode()
        );

        adapterA.setLzMessageToOperationId(guid, operationId);

        // Call lzReceive directly on adapterA to simulate message receipt
        vm.prank(address(lzEndpointA));
        adapterA.lzReceiveTest(
            origin,
            guid,
            payload,
            address(adapterB),
            bytes("")
        );

        // Verify the mock receiver received the message
        assertEq(mockReceiver.lastMessageId(), operationId);
        assertEq(mockReceiver.lastReceivedData(), message);
    }

    function testUnauthorizedSendMessage() public {
        useNetworkA();
        vm.deal(user, 1 ether);

        vm.startPrank(user); // User is not the router

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: bytes("")
            });

        // Should revert with Unauthorized since only the router can call sendMessage
        vm.expectRevert(
            abi.encodeWithSelector(IBridgeAdapter.Unauthorized.selector)
        );

        adapterA.sendMessage{value: 0.1 ether}(
            CHAIN_ID_B,
            recipient,
            abi.encode("This should fail"),
            address(user),
            adapterParams
        );

        vm.stopPrank();
    }

    function testInsufficientMsgValue() public {
        useNetworkA();
        vm.deal(address(routerA), 1 ether);

        vm.startPrank(address(routerA));

        // Create adapter params requiring more msgValue than provided
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0.5 ether,
                options: bytes("")
            });

        // Should revert with InsufficientMsgValue since we only provide 0.1 ether
        vm.expectRevert(
            abi.encodeWithSelector(
                IBridgeAdapter.InsufficientMsgValue.selector,
                uint128(0.5 ether),
                0.1 ether
            )
        );

        adapterA.sendMessage{value: 0.1 ether}(
            CHAIN_ID_B,
            recipient,
            abi.encode("This should fail due to insufficient value"),
            address(user),
            adapterParams
        );

        vm.stopPrank();
    }
}
