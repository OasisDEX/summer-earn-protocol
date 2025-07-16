// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { IBridgeRouter } from "../../src/interfaces/IBridgeRouter.sol";
import { ICrossChainAssetReceiver } from "../../src/interfaces/ICrossChainAssetReceiver.sol";
import { ICrossChainMessageReceiver } from "../../src/interfaces/ICrossChainMessageReceiver.sol";
import { BridgeRouterSetup } from "./BridgeRouter.setup.t.sol";

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
                address(token),
                AMOUNT,
                payload,
                SOURCE_CHAIN_ID
            )
        );

        vm.prank(address(mockAdapter));
        router.deliver(operationId, SOURCE_CHAIN_ID, address(token), AMOUNT, address(mockReceiver), payload);

        // Tokens forwarded
        assertEq(token.balanceOf(address(mockReceiver)), balBefore + AMOUNT, "tokens not forwarded");

        // Router recorded the handling adapter
        assertEq(router.requestReceivedByAdapter(operationId), address(mockAdapter), "adapter not recorded");
    }

    function testDeliverMessageOnly() public {
        bytes32 operationId = keccak256("deliverMessageOnly");
        bytes memory payload = abi.encodePacked(uint256(42));

        vm.expectCall(
            address(mockReceiver),
            abi.encodeWithSelector(ICrossChainMessageReceiver.receiveMessage.selector, SOURCE_CHAIN_ID, payload)
        );

        vm.prank(address(mockAdapter));
        router.deliver(
            operationId,
            SOURCE_CHAIN_ID,
            address(0), // no asset
            0,
            address(mockReceiver),
            payload
        );

        // Mapping updated
        assertEq(router.requestReceivedByAdapter(operationId), address(mockAdapter), "adapter mapping incorrect");
    }

    /* -------------------------------------------------------------------------- */
    /*                                revert paths                                */
    /* -------------------------------------------------------------------------- */

    function testDeliverUnknownAdapterReverts() public {
        bytes32 operationId = keccak256("unknownAdapter");

        vm.prank(address(mockAdapter2)); // not registered
        vm.expectRevert(IBridgeRouter.UnknownAdapter.selector);
        router.deliver(operationId, SOURCE_CHAIN_ID, address(0), 0, address(mockReceiver), "");
    }

    function testDeliverReceiverRejectsReverts() public {
        mockReceiver.setReceiveSuccess(false); // make receiver revert
        bytes32 operationId = keccak256("receiverRejects");

        vm.prank(address(mockAdapter));
        vm.expectRevert(); // bubble-up from receiver revert
        router.deliver(operationId, SOURCE_CHAIN_ID, address(0), 0, address(mockReceiver), abi.encode("fail"));
    }

}
