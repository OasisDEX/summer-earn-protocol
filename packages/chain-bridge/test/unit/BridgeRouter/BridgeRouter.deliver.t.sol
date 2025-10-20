// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBridgeRouter} from "../../../src/interfaces/IBridgeRouter.sol";
import {ICrossChainReceiver} from "../../../src/interfaces/ICrossChainReceiver.sol";
import {BridgeRouterSetup} from "./BridgeRouter.setup.t.sol";
import {BridgeTypes} from "../../../src/libraries/BridgeTypes.sol";

contract BridgeRouterDeliverTest is BridgeRouterSetup {
    uint256 public constant AMOUNT = 500e18;

    function setUp() public override {
        super.setUp();
    }

    /* -------------------------------------------------------------------------- */
    /*                               success paths                                */
    /* -------------------------------------------------------------------------- */

    function testDeliver_TransferAsset_Succeeds() public {
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

    function testDeliver_Message_Succeeds() public {
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

    /* -------------------------------------------------------------------------- */
    /*                         adapter peer verification tests                    */
    /* -------------------------------------------------------------------------- */

    function testDeliver_TransferAsset_RecordsFailure_WhenNoPeerRelationship()
        public
    {
        bytes32 operationId = keccak256("noPeerRelationshipTransferAsset");
        uint16 untrustedSourceChain = 999; // Chain with no peer relationship

        vm.startPrank(address(mockAdapter)); // registered adapter
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

        (
            BridgeTypes.OperationType opType,
            address failingAdapter,
            uint16 srcChain,
            ,
            uint256 failedAt
        ) = router.getFailedDeliveryRecord(operationId);

        assertEq(
            uint8(opType),
            uint8(BridgeTypes.OperationType.TRANSFER_ASSET)
        );
        assertEq(failingAdapter, address(mockAdapter));
        assertEq(srcChain, untrustedSourceChain);
        assertGt(failedAt, 0);
    }

    function testDeliver_Message_RecordsFailure_WhenNoPeerRelationship()
        public
    {
        bytes32 operationId = keccak256("noPeerRelationshipMessage");
        uint16 untrustedSourceChain = 999; // Chain with no peer relationship

        vm.startPrank(address(mockAdapter)); // registered adapter
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

        (
            BridgeTypes.OperationType opType,
            address failingAdapter,
            uint16 srcChain,
            ,
            uint256 failedAt
        ) = router.getFailedDeliveryRecord(operationId);

        assertEq(uint8(opType), uint8(BridgeTypes.OperationType.MESSAGE));
        assertEq(failingAdapter, address(mockAdapter));
        assertEq(srcChain, untrustedSourceChain);
        assertGt(failedAt, 0);
    }

    function testDeliver_Reverts_WhenCallerNotRegisteredAdapter() public {
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

    function testDeliver_TransferAsset_RecordsFailure_WhenPeerRelationshipMissing()
        public
    {
        // This tests the specific case where adapter is registered but peer relationship is missing
        bytes32 operationId = keccak256("validAdapterInvalidPeer");
        uint16 sourceChainWithNoPeer = 777; // Different chain with no peer relationship

        // mockAdapter is registered with router but has no peer relationship with sourceChainWithNoPeer
        vm.startPrank(address(mockAdapter));
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

        (
            BridgeTypes.OperationType opType,
            address failingAdapter,
            uint16 srcChain,
            ,
            uint256 failedAt
        ) = router.getFailedDeliveryRecord(operationId);
        assertEq(
            uint8(opType),
            uint8(BridgeTypes.OperationType.TRANSFER_ASSET)
        );
        assertEq(failingAdapter, address(mockAdapter));
        assertEq(srcChain, sourceChainWithNoPeer);
        assertGt(failedAt, 0);
    }

    function testDeliver_Message_Succeeds_WithValidPeer_OnDifferentSourceChain()
        public
    {
        // Test that peer verification works across different chain configurations
        uint16 anotherSourceChain = 555;

        // Register peer relationship for a different source chain
        vm.prank(governor);
        registry.registerAdapterPeerPair(
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

    function testDeliver_Reverts_WhenCallerUnknownAdapter() public {
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

    function testDeliver_Message_RecordsFailure_WhenReceiverReverts() public {
        mockReceiver.setReceiveSuccess(false); // make receiver revert
        bytes32 operationId = keccak256("receiverRejects");

        vm.prank(address(mockAdapter));
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

        (
            BridgeTypes.OperationType opType,
            address failingAdapter,
            uint16 srcChain,
            ,
            uint256 failedAt
        ) = router.getFailedDeliveryRecord(operationId);
        assertEq(uint8(opType), uint8(BridgeTypes.OperationType.MESSAGE));
        assertEq(failingAdapter, address(mockAdapter));
        assertEq(srcChain, uint16(SOURCE_CHAIN_ID));
        assertGt(failedAt, 0);
    }

    function testDeliver_OperationDelivered_EventEmitted() public {
        bytes32 operationId = keccak256("deliveredEvt");

        vm.expectEmit(true, false, false, true);
        emit IBridgeRouter.OperationDelivered(
            operationId,
            BridgeTypes.OperationType.MESSAGE
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
                    message: abi.encode("ok")
                })
            )
        );
    }
}
