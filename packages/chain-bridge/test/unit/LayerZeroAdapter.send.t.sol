// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {LayerZeroAdapterSetupTest} from "./LayerZeroAdapter.setup.t.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {IExecutorFeeLib} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/interfaces/IExecutorFeeLib.sol";
import {Errors} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/Errors.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
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

        // Generate a proper operation ID (fake but realistic)
        bytes32 operationId = keccak256(
            abi.encode(
                block.chainid,
                CHAIN_ID_B,
                address(0), // No asset for read operations
                0, // No amount for read operations
                address(0), // No recipient for read operations
                abi.encode(
                    address(tokenB),
                    bytes4(keccak256("balanceOf(address)")),
                    abi.encode(recipient),
                    address(user)
                ),
                block.timestamp,
                BridgeTypes.OperationType.READ_STATE
            )
        );

        routerA.setOperationToAdapter(operationId, address(adapterA));

        vm.startPrank(governor);
        adapterA.activateReadChannel(adapterA.READ_CHANNEL_THRESHOLD() + 1);
        vm.stopPrank();

        // Mock the router's updateOperationStatus function
        vm.mockCall(
            address(routerA),
            abi.encodeWithSelector(routerA.updateOperationStatus.selector),
            abi.encode()
        );

        // We expect this call to revert with LZ_DefaultSendLibUnavailable
        // This is because the LayerZeroOptionsHelper.createLzReadOptions is creating
        // options of type 5, which is not supported by the mock executor when !_isRead
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LZ_DefaultSendLibUnavailable.selector)
        );
        vm.deal(address(routerA), 1 ether);
        vm.prank(address(routerA));
        adapterA.readState{value: 0.1 ether}(
            operationId, // Use proper operation ID
            CHAIN_ID_A,
            CHAIN_ID_B,
            address(tokenB),
            bytes4(keccak256("balanceOf(address)")),
            abi.encode("read params"),
            address(user), // keeper
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

        // Generate a proper operation ID that matches BridgeRouter's logic
        bytes32 operationId = keccak256(
            abi.encode(
                block.chainid,
                CHAIN_ID_B,
                address(0), // No asset for messages
                0, // No amount for messages
                recipient,
                abi.encode(message, address(user)), // Additional data
                block.timestamp,
                BridgeTypes.OperationType.MESSAGE
            )
        );

        routerA.setOperationToAdapter(operationId, address(adapterA));

        vm.deal(address(routerA), 1 ether);

        // Expect the MessageInitiated event to be emitted
        vm.expectEmit(true, true, true, true);
        emit MessageInitiated(operationId, CHAIN_ID_B, recipient, message);

        // Call sendMessage directly on the adapter - no return value expected
        adapterA.sendMessage{value: 0.1 ether}(
            operationId, // Use proper operation ID
            CHAIN_ID_B,
            recipient,
            message,
            address(user), // keeper
            adapterParams
        );

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

        // Generate a fake operation ID
        bytes32 operationId = keccak256(abi.encode("fake-operation"));

        // Should revert with Unauthorized since only the router can call sendMessage
        vm.expectRevert(
            abi.encodeWithSelector(IBridgeAdapter.Unauthorized.selector)
        );

        adapterA.sendMessage{value: 0.1 ether}(
            operationId, // Use proper operation ID
            CHAIN_ID_B,
            recipient,
            abi.encode("This should fail"),
            address(user), // keeper
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

        // Generate a fake operation ID
        bytes32 operationId = keccak256(abi.encode("fake-operation"));

        // Should revert with InsufficientMsgValue since we only provide 0.1 ether
        vm.expectRevert(
            abi.encodeWithSelector(
                IBridgeAdapter.InsufficientMsgValue.selector,
                uint128(0.5 ether),
                0.1 ether
            )
        );

        adapterA.sendMessage{value: 0.1 ether}(
            operationId, // Use proper operation ID
            CHAIN_ID_B,
            recipient,
            abi.encode("This should fail due to insufficient value"),
            address(user), // keeper
            adapterParams
        );

        vm.stopPrank();
    }

    function testReadStateWithProperOperationId() public {
        useNetworkA();

        // Create adapter params with empty options
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 100,
                msgValue: 0,
                options: bytes("")
            });

        // Generate a proper operation ID that matches BridgeRouter's logic
        bytes32 operationId = keccak256(
            abi.encode(
                block.chainid,
                CHAIN_ID_B,
                address(0), // No asset for read operations
                0, // No amount for read operations
                address(0), // No recipient for read operations
                abi.encode(
                    address(tokenB),
                    bytes4(keccak256("balanceOf(address)")),
                    abi.encode(recipient),
                    address(user)
                ),
                block.timestamp,
                BridgeTypes.OperationType.READ_STATE
            )
        );

        routerA.setOperationToAdapter(operationId, address(adapterA));

        vm.startPrank(governor);
        adapterA.activateReadChannel(adapterA.READ_CHANNEL_THRESHOLD() + 1);
        vm.stopPrank();

        // Mock the router's updateOperationStatus function
        vm.mockCall(
            address(routerA),
            abi.encodeWithSelector(routerA.updateOperationStatus.selector),
            abi.encode()
        );

        // We expect this call to revert with LZ_DefaultSendLibUnavailable
        // This is because the LayerZeroOptionsHelper.createLzReadOptions is creating
        // options of type 5, which is not supported by the mock executor when !_isRead
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LZ_DefaultSendLibUnavailable.selector)
        );

        vm.deal(address(routerA), 1 ether);
        vm.prank(address(routerA));

        // This should revert due to the mock LayerZero setup
        adapterA.readState{value: 0.1 ether}(
            operationId, // Use proper operation ID
            CHAIN_ID_A,
            CHAIN_ID_B,
            address(tokenB),
            bytes4(keccak256("balanceOf(address)")),
            abi.encode(recipient),
            address(user), // keeper
            adapterParams
        );
    }

    // Add event declarations for the events we expect
    event MessageInitiated(
        bytes32 indexed messageId,
        uint16 destinationChainId,
        address recipient,
        bytes message
    );

    event ReadRequestInitiated(
        bytes32 indexed requestId,
        uint16 srcChainId,
        uint16 destinationChainId,
        address dstContract,
        bytes4 selector
    );
}
