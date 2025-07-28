// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
import {ICrossChainAssetReceiver} from "../../src/interfaces/ICrossChainAssetReceiver.sol";
import {ICrossChainMessageReceiver} from "../../src/interfaces/ICrossChainMessageReceiver.sol";
import {BridgeRouterSetup} from "./BridgeRouter.setup.t.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";

contract BridgeRouterDeliverTest is BridgeRouterSetup {
    uint256 public constant AMOUNT = 500e18;

    /* -------------------------------------------------------------------------- */
    /*                               success paths                                */
    /* -------------------------------------------------------------------------- */

    function testDeliverWithAssets() public {
        bytes32 operationId = keccak256("deliverWithAssets");
        bytes memory payload = abi.encode("hello world");

        uint256 balBefore = token.balanceOf(address(mockReceiver));

        // Expect receiver call with correct argument order
        vm.expectCall(
            address(mockReceiver),
            abi.encodeWithSelector(
                ICrossChainAssetReceiver.receiveMessageWithAssets.selector,
                BridgeTypes.DeliveredTransferParams({
                    operationId: operationId,
                    originator: address(mockAdapter),
                    sourceChainId: uint16(SOURCE_CHAIN_ID),
                    recipient: address(mockReceiver),
                    asset: address(token),
                    amount: AMOUNT,
                    message: payload
                })
            )
        );

        vm.prank(address(mockAdapter));
        router.deliver(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            abi.encode(
                BridgeTypes.DeliveredTransferParams({
                    operationId: operationId,
                    originator: address(mockAdapter),
                    sourceChainId: uint16(SOURCE_CHAIN_ID),
                    recipient: address(mockReceiver),
                    asset: address(token),
                    amount: AMOUNT,
                    message: payload
                })
            )
        );

        // Tokens forwarded
        assertEq(
            token.balanceOf(address(mockReceiver)),
            balBefore + AMOUNT,
            "tokens not forwarded"
        );
    }

    function testDeliverMessageOnly() public {
        bytes32 operationId = keccak256("deliverMessageOnly");
        bytes memory payload = abi.encodePacked(uint256(42));

        vm.expectCall(
            address(mockReceiver),
            abi.encodeWithSelector(
                ICrossChainMessageReceiver.receiveMessage.selector,
                BridgeTypes.DeliveredMessageParams({
                    operationId: operationId,
                    originator: address(mockAdapter),
                    sourceChainId: uint16(SOURCE_CHAIN_ID),
                    recipient: address(mockReceiver),
                    message: payload
                })
            )
        );

        vm.prank(address(mockAdapter));
        router.deliver(
            BridgeTypes.OperationType.MESSAGE,
            abi.encode(
                BridgeTypes.DeliveredMessageParams({
                    operationId: operationId,
                    originator: address(mockAdapter),
                    sourceChainId: uint16(SOURCE_CHAIN_ID),
                    recipient: address(mockReceiver),
                    message: payload
                })
            )
        );
    }

    function testDeliverReadResponse() public {
        bytes32 operationId = keccak256("deliverReadResponse");
        bytes memory responseData = abi.encode(uint256(123), "test response");

        // Assuming there's a way to set up the readRequestToOriginator mapping
        // This might need to be handled differently based on your router implementation
        router.setOperationToAdapter(operationId, address(mockAdapter));
        router.setReadRequestOriginator(operationId, address(mockReceiver));

        vm.prank(address(mockAdapter));
        router.deliver(
            BridgeTypes.OperationType.READ_STATE,
            abi.encode(
                BridgeTypes.DeliveredReadResponse({
                    operationId: operationId,
                    sourceChainId: uint16(SOURCE_CHAIN_ID),
                    readResponseData: responseData
                })
            )
        );
    }

    /* -------------------------------------------------------------------------- */
    /*                                revert paths                                */
    /* -------------------------------------------------------------------------- */

    function testDeliverUnknownAdapterReverts() public {
        bytes32 operationId = keccak256("unknownAdapter");

        vm.prank(address(mockAdapter2)); // not registered
        vm.expectRevert(IBridgeRouter.UnknownAdapter.selector);
        router.deliver(
            BridgeTypes.OperationType.MESSAGE,
            abi.encode(
                BridgeTypes.DeliveredMessageParams({
                    operationId: operationId,
                    originator: address(mockAdapter2),
                    sourceChainId: uint16(SOURCE_CHAIN_ID),
                    recipient: address(mockReceiver),
                    message: abi.encode("test")
                })
            )
        );
    }

    function testDeliverReceiverRejectsReverts() public {
        mockReceiver.setReceiveSuccess(false); // make receiver revert
        bytes32 operationId = keccak256("receiverRejects");

        vm.prank(address(mockAdapter));
        vm.expectRevert(); // bubble-up from receiver revert
        router.deliver(
            BridgeTypes.OperationType.MESSAGE,
            abi.encode(
                BridgeTypes.DeliveredMessageParams({
                    operationId: operationId,
                    originator: address(mockAdapter),
                    sourceChainId: uint16(SOURCE_CHAIN_ID),
                    recipient: address(mockReceiver),
                    message: abi.encode("fail")
                })
            )
        );
    }

    function testDeliverUnsupportedOperationTypeReverts() public {
        bytes32 operationId = keccak256("unsupportedOperation");

        vm.prank(address(mockAdapter));
        vm.expectRevert(); // Should revert for unsupported operation type
        router.deliver(
            BridgeTypes.OperationType.TRANSFER_ASSET, // Invalid operation type
            abi.encode("invalid")
        );
    }
}
