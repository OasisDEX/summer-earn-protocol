// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
import {ICrossChainReceiver} from "../../src/interfaces/ICrossChainReceiver.sol";
import {ICrossChainReceiver} from "../../src/interfaces/ICrossChainReceiver.sol";
import {ICrossChainRegistry} from "../../src/interfaces/ICrossChainRegistry.sol";
import {BridgeRouterSetup} from "./BridgeRouter.setup.t.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {console} from "forge-std/console.sol";

contract BridgeRouterDeliverTest is BridgeRouterSetup {
    uint256 public constant AMOUNT = 500e18;

    function setUp() public override {
        super.setUp();
    }

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
                ICrossChainReceiver.receiveOperation.selector,
                BridgeTypes.OperationType.TRANSFER_ASSET,
                abi.encode(
                    BridgeTypes.RelayedTransferParams({
                        operationId: operationId,
                        originator: address(mockAdapter),
                        sourceChainId: uint16(SOURCE_CHAIN_ID),
                        recipient: address(mockReceiver),
                        asset: address(token),
                        amount: AMOUNT,
                        message: payload
                    })
                )
            )
        );

        vm.prank(address(mockAdapter));
        router.deliver(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            abi.encode(
                BridgeTypes.RelayedTransferParams({
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
                ICrossChainReceiver.receiveOperation.selector,
                BridgeTypes.OperationType.MESSAGE,
                abi.encode(
                    BridgeTypes.RelayedMessageParams({
                        operationId: operationId,
                        originator: address(mockAdapter),
                        sourceChainId: uint16(SOURCE_CHAIN_ID),
                        recipient: address(mockReceiver),
                        message: payload
                    })
                )
            )
        );

        vm.prank(address(mockAdapter));
        router.deliver(
            BridgeTypes.OperationType.MESSAGE,
            abi.encode(
                BridgeTypes.RelayedMessageParams({
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
                BridgeTypes.RelayedReadResponse({
                    operationId: operationId,
                    sourceChainId: uint16(SOURCE_CHAIN_ID),
                    readResponseData: responseData
                })
            )
        );
    }

    /* -------------------------------------------------------------------------- */
    /*                         adapter peer verification tests                    */
    /* -------------------------------------------------------------------------- */

    function testDeliverTransferAssetNoPeerRelationshipReverts() public {
        bytes32 operationId = keccak256("noPeerRelationshipTransferAsset");
        uint16 untrustedSourceChain = 999; // Chain with no peer relationship

        vm.startPrank(address(mockAdapter)); // registered adapter
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                address(0),
                registry.PEER_RELATIONSHIP(),
                uint16(CURRENT_CHAIN_ID)
            )
        );
        router.deliver(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            abi.encode(
                BridgeTypes.RelayedTransferParams({
                    operationId: operationId,
                    originator: address(mockAdapter),
                    sourceChainId: untrustedSourceChain,
                    recipient: address(mockReceiver),
                    asset: address(token),
                    amount: AMOUNT,
                    message: abi.encode("test")
                })
            )
        );
        vm.stopPrank();
    }

    function testDeliverMessageNoPeerRelationshipReverts() public {
        bytes32 operationId = keccak256("noPeerRelationshipMessage");
        uint16 untrustedSourceChain = 999; // Chain with no peer relationship

        vm.startPrank(address(mockAdapter)); // registered adapter
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                address(0),
                registry.PEER_RELATIONSHIP(),
                uint16(CURRENT_CHAIN_ID)
            )
        );
        router.deliver(
            BridgeTypes.OperationType.MESSAGE,
            abi.encode(
                BridgeTypes.RelayedMessageParams({
                    operationId: operationId,
                    originator: address(mockAdapter),
                    sourceChainId: untrustedSourceChain,
                    recipient: address(mockReceiver),
                    message: abi.encode("test")
                })
            )
        );
        vm.stopPrank();
    }

    function testDeliverReadResponseIgnoresPeerVerification() public {
        bytes32 operationId = keccak256("untrustedReadResponse");
        uint16 untrustedSourceChain = 999; // Chain with no peer relationship
        bytes memory responseData = abi.encode(uint256(123), "test response");

        // Set up mappings so READ_STATE delivery is authorized and succeeds
        router.setOperationToAdapter(operationId, address(mockAdapter));
        router.setReadRequestOriginator(operationId, address(mockReceiver));

        vm.prank(address(mockAdapter));
        router.deliver(
            BridgeTypes.OperationType.READ_STATE,
            abi.encode(
                BridgeTypes.RelayedReadResponse({
                    operationId: operationId,
                    sourceChainId: untrustedSourceChain,
                    readResponseData: responseData
                })
            )
        );
    }

    function testDeliverWithUnregisteredAdapterButValidPeerReverts() public {
        // This tests that both adapter registration AND peer relationship are required
        bytes32 operationId = keccak256("unregisteredAdapterValidPeer");

        // The call should fail with UnknownAdapter even though peer relationship exists
        vm.startPrank(address(mockAdapterSource)); // mockAdapterSource is not registered
        vm.expectRevert(IBridgeRouter.UnknownAdapter.selector);
        router.deliver(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            abi.encode(
                BridgeTypes.RelayedTransferParams({
                    operationId: operationId,
                    originator: address(mockAdapterSource),
                    sourceChainId: uint16(SOURCE_CHAIN_ID),
                    recipient: address(mockReceiver),
                    asset: address(token),
                    amount: AMOUNT,
                    message: abi.encode("test")
                })
            )
        );
        vm.stopPrank();
    }

    function testDeliverValidAdapterButInvalidPeerRelationship() public {
        // This tests the specific case where adapter is registered but peer relationship is missing
        bytes32 operationId = keccak256("validAdapterInvalidPeer");
        uint16 sourceChainWithNoPeer = 777; // Different chain with no peer relationship

        // mockAdapter is registered with router but has no peer relationship with sourceChainWithNoPeer
        vm.startPrank(address(mockAdapter));
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                address(0),
                registry.PEER_RELATIONSHIP(),
                uint16(CURRENT_CHAIN_ID)
            )
        );
        router.deliver(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            abi.encode(
                BridgeTypes.RelayedTransferParams({
                    operationId: operationId,
                    originator: address(mockAdapter),
                    sourceChainId: sourceChainWithNoPeer,
                    recipient: address(mockReceiver),
                    asset: address(token),
                    amount: AMOUNT,
                    message: abi.encode("test")
                })
            )
        );
        vm.stopPrank();
    }

    function testDeliverValidPeerRelationshipDifferentChains() public {
        // Test that peer verification works across different chain configurations
        uint16 anotherSourceChain = 555;

        // Register peer relationship for a different source chain
        vm.prank(governor);
        registry.registerAdapterPeer(
            address(mockAdapter), // source adapter
            address(mockAdapter), // target adapter
            anotherSourceChain, // different source chain
            CURRENT_CHAIN_ID // target chain
        );

        bytes32 operationId = keccak256("differentChainPeer");

        // This should succeed because we have a valid peer relationship
        vm.prank(address(mockAdapter));
        router.deliver(
            BridgeTypes.OperationType.MESSAGE,
            abi.encode(
                BridgeTypes.RelayedMessageParams({
                    operationId: operationId,
                    originator: address(mockAdapter),
                    sourceChainId: anotherSourceChain,
                    recipient: address(mockReceiver),
                    message: abi.encode("success")
                })
            )
        );
    }

    /* -------------------------------------------------------------------------- */
    /*                                revert paths                                */
    /* -------------------------------------------------------------------------- */

    function testDeliverUnknownAdapterReverts() public {
        bytes32 operationId = keccak256("unknownAdapter");

        vm.prank(address(mockAdapterSource)); // not registered
        vm.expectRevert(IBridgeRouter.UnknownAdapter.selector);
        router.deliver(
            BridgeTypes.OperationType.MESSAGE,
            abi.encode(
                BridgeTypes.RelayedMessageParams({
                    operationId: operationId,
                    originator: address(mockAdapterSource),
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
                BridgeTypes.RelayedMessageParams({
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
        vm.prank(address(mockAdapter));
        vm.expectRevert(); // Should revert for unsupported operation type
        router.deliver(
            BridgeTypes.OperationType.TRANSFER_ASSET, // Invalid operation type
            abi.encode("invalid")
        );
    }
}
