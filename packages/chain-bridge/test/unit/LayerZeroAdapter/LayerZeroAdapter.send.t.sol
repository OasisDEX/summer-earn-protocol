// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBridgeAdapter} from "../../../src/interfaces/IBridgeAdapter.sol";
import {IBaseBridgeAdapterErrors} from "../../../src/interfaces/IBaseBridgeAdapterErrors.sol";
import {BridgeTypes} from "../../../src/libraries/BridgeTypes.sol";
import {MockCrossChainReceiver} from "../../mocks/MockCrossChainReceiver.sol";
import {LayerZeroAdapterSetupTest} from "./LayerZeroAdapter.setup.t.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {ICrossChainConfigManaged} from "../../../src/interfaces/ICrossChainConfigManaged.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {console} from "forge-std/Test.sol";

contract LayerZeroAdapterSendTest is LayerZeroAdapterSetupTest {
    using OptionsBuilder for bytes;

    // Add a MockCrossChainReceiver instance to test direct message delivery
    MockCrossChainReceiver public mockReceiver;

    // Protocol token for testing
    ERC20Mock public protocolFeeToken;
    uint256 public constant PROTOCOL_FEE_AMOUNT = 1000e18;

    // Override setup to deploy the mock receiver and protocol token
    function setUp() public override {
        super.setUp();
        mockReceiver = new MockCrossChainReceiver();

        // Deploy protocol fee token
        protocolFeeToken = new ERC20Mock();

        // Configure protocol fee token on adapter
        vm.prank(governor);
        adapterA.setProtocolFeeToken(address(protocolFeeToken));

        // Mint protocol tokens to router and user
        protocolFeeToken.mint(address(routerA), 10000e18);
        protocolFeeToken.mint(user, 10000e18);

        // Router approves adapter to spend protocol tokens
        vm.prank(address(routerA));
        protocolFeeToken.approve(address(adapterA), type(uint256).max);
    }

    function testDirectSendMessage() public {
        useNetworkA();
        vm.deal(user, 1 ether);

        vm.startPrank(address(routerA)); // Pretend to be the router for authorization

        // Create a test message to send cross-chain
        bytes memory message = abi.encode("Hello from Chain A!");

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: bytes(""),
            payInProtocolToken: false,
            feeTokenAmount: 0
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

        vm.deal(address(routerA), 3 ether);

        // Expect the MessageInitiated event to be emitted
        vm.expectEmit(true, true, true, true);
        emit MessageInitiated(operationId, CHAIN_ID_B, recipient, message);

        // Call sendMessage directly on the adapter - no return value expected
        BridgeTypes.ExecuteSendMessageParams memory params = BridgeTypes
            .ExecuteSendMessageParams({
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                message: message,
                originator: address(user),
                refundAddress: address(user)
            });
        // Provide sufficient value for LayerZero fee (msgValue = 0 in this case)
        adapterA.sendMessage{value: 3 ether}(
            operationId, // Use proper operation ID
            params,
            options
        );

        vm.stopPrank();
    }

    function testDirectEstimateFee() public {
        useNetworkA();

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: bytes(""),
            payInProtocolToken: false,
            feeTokenAmount: 0
        });

        // Call estimateSendMessage directly on the adapter
        (uint256 nativeFee, uint256 tokenFee) = adapterA.estimateSendMessage(
            BridgeTypes.ExecuteSendMessageParams({
                destinationChainId: CHAIN_ID_B,
                target: address(0x1234), // Target contract
                message: abi.encode("Test message"),
                originator: address(this),
                refundAddress: address(this)
            }),
            options
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

        // Format the payload as MESSAGE type with recipient info
        bytes memory payload = abi.encodePacked(
            uint16(BridgeTypes.OperationType.MESSAGE),
            abi.encode(
                BridgeTypes.RelayedMessageParams({
                    operationId: operationId,
                    originator: address(mockReceiver),
                    sourceChainId: uint16(CHAIN_ID_B),
                    recipient: address(mockReceiver),
                    message: message
                })
            )
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

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: bytes(""),
            payInProtocolToken: false,
            feeTokenAmount: 0
        });

        // Generate a fake operation ID
        bytes32 operationId = keccak256(abi.encode("fake-operation"));

        // Should revert with Unauthorized since only the router can call sendMessage
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainConfigManaged.OnlyBridgeRouter.selector
            )
        );

        BridgeTypes.ExecuteSendMessageParams memory params = BridgeTypes
            .ExecuteSendMessageParams({
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                message: abi.encode("This should fail"),
                originator: address(user),
                refundAddress: address(user)
            });
        adapterA.sendMessage{value: 0.1 ether}(
            operationId, // Use proper operation ID
            params,
            options
        );

        vm.stopPrank();
    }

    function testInsufficientMsgValue() public {
        useNetworkA();
        vm.deal(address(routerA), 1 ether);

        vm.startPrank(address(routerA));

        // Create adapter params requiring more msgValue than provided
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0.01 ether,
            options: bytes(""),
            payInProtocolToken: false,
            feeTokenAmount: 0
        });

        // Generate a fake operation ID
        bytes32 operationId = keccak256(abi.encode("fake-operation"));

        BridgeTypes.ExecuteSendMessageParams memory params = BridgeTypes
            .ExecuteSendMessageParams({
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                message: abi.encode(
                    "This should fail due to insufficient value"
                ),
                originator: address(user),
                refundAddress: address(user)
            });

        // Should revert with InsufficientMsgValue since we provide 0.005 ether but need fee + 0.01 ether
        // The exact fee amount will be quoted by LayerZero, so we expect InsufficientMsgValue
        // We need to calculate the actual required amount (fee + msgValue)
        (uint256 nativeFee, ) = adapterA.estimateSendMessage(params, options);
        uint256 totalRequired = nativeFee + options.msgValue;

        vm.expectRevert(
            abi.encodeWithSelector(
                IBridgeAdapter.InsufficientMsgValue.selector,
                totalRequired, // Actual required amount (fee + msgValue)
                0.005 ether // msg.value provided
            )
        );
        adapterA.sendMessage{value: 0.005 ether}(
            operationId, // Use proper operation ID
            params,
            options
        );

        vm.stopPrank();
    }

    function testEstimateSendMessageWithProtocolToken() public {
        useNetworkA();

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0.5 ether,
            options: bytes(""),
            payInProtocolToken: true,
            feeTokenAmount: PROTOCOL_FEE_AMOUNT
        });

        // Call estimateSendMessage with protocol token payment
        (uint256 nativeFee, uint256 tokenFee) = adapterA.estimateSendMessage(
            BridgeTypes.ExecuteSendMessageParams({
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                message: abi.encode("Test message"),
                originator: address(user),
                refundAddress: address(user)
            }),
            options
        );

        // When paying in protocol tokens, native fee should be 0
        assertEq(
            nativeFee,
            0,
            "Native fee should be 0 when paying in protocol tokens"
        );
        assertGt(tokenFee, 0, "Token fee should be greater than 0");
    }

    // Add event declarations for the events we expect
    event MessageInitiated(
        bytes32 indexed messageId,
        uint16 destinationChainId,
        address recipient,
        bytes message
    );
}
