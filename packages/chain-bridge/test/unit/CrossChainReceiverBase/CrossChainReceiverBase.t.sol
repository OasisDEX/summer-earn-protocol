// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {MockCrossChainReceiver} from "../../mocks/MockCrossChainReceiver.sol";
import {MockFleetProxy} from "../../mocks/MockFleetProxy.sol";
import {BridgeTypes} from "../../../src/libraries/BridgeTypes.sol";
import {ICrossChainReceiver} from "../../../src/interfaces/ICrossChainReceiver.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

contract CrossChainReceiverBaseTest is Test {
    MockCrossChainReceiver internal receiverAll;
    MockFleetProxy internal receiverTransferOnly;

    address internal constant ORIGINATOR = address(0xA11CE);
    address internal constant RECIPIENT = address(0xB0B);
    address internal constant ASSET = address(0xC0FFEE);
    uint16 internal constant SOURCE_CHAIN_ID = 777;
    bytes32 internal constant OP_ID = bytes32(uint256(123));

    function setUp() public {
        receiverAll = new MockCrossChainReceiver();
        receiverTransferOnly = new MockFleetProxy(ASSET);
    }

    /* -------------------------------------------------------------------------- */
    /*                               routing tests                                */
    /* -------------------------------------------------------------------------- */

    function test_receiveOperation_routes_MESSAGE_and_updates_state() public {
        BridgeTypes.RelayedMessageParams memory p = BridgeTypes
            .RelayedMessageParams({
                operationId: OP_ID,
                originator: ORIGINATOR,
                sourceChainId: SOURCE_CHAIN_ID,
                recipient: RECIPIENT,
                message: bytes("hello-world")
            });

        receiverAll.receiveOperation(
            BridgeTypes.OperationType.MESSAGE,
            abi.encode(p)
        );

        assertEq(
            uint8(receiverAll.lastOperationType()),
            uint8(BridgeTypes.OperationType.MESSAGE)
        );
        assertEq(receiverAll.lastSender(), address(this));
        assertEq(receiverAll.lastSourceChainId(), SOURCE_CHAIN_ID);
        assertEq(receiverAll.lastOperationId(), OP_ID);
        assertEq(receiverAll.lastReceivedData(), p.message);
    }

    function test_receiveOperation_routes_TRANSFER_and_updates_state() public {
        BridgeTypes.RelayedTransferParams memory p = BridgeTypes
            .RelayedTransferParams({
                operationId: OP_ID,
                originator: ORIGINATOR,
                sourceChainId: SOURCE_CHAIN_ID,
                recipient: RECIPIENT,
                asset: ASSET,
                amount: 123e18,
                message: bytes("transfer-note")
            });

        receiverAll.receiveOperation(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            abi.encode(p)
        );

        assertEq(
            uint8(receiverAll.lastOperationType()),
            uint8(BridgeTypes.OperationType.TRANSFER_ASSET)
        );
        assertEq(receiverAll.lastSender(), address(this));
        assertEq(receiverAll.lastSourceChainId(), SOURCE_CHAIN_ID);
        assertEq(receiverAll.lastOperationId(), OP_ID);
        assertEq(receiverAll.lastReceivedData(), p.message);
    }

    function test_receiveOperation_routes_READSTATE_and_updates_state() public {
        BridgeTypes.RelayedReadResponse memory p = BridgeTypes
            .RelayedReadResponse({
                readResponseData: bytes("read-result"),
                operationId: OP_ID,
                sourceChainId: SOURCE_CHAIN_ID
            });

        receiverAll.receiveOperation(
            BridgeTypes.OperationType.READ_STATE,
            abi.encode(p)
        );

        assertEq(
            uint8(receiverAll.lastOperationType()),
            uint8(BridgeTypes.OperationType.READ_STATE)
        );
        assertEq(receiverAll.lastSender(), address(this));
        assertEq(receiverAll.lastSourceChainId(), SOURCE_CHAIN_ID);
        assertEq(receiverAll.lastOperationId(), OP_ID);
        assertEq(receiverAll.lastReceivedData(), p.readResponseData);
    }

    /* -------------------------------------------------------------------------- */
    /*                         auth & unsupported operation                        */
    /* -------------------------------------------------------------------------- */

    function test_receiveOperation_reverts_when_unauthorized() public {
        receiverAll.setShouldRevertAuth(true);
        BridgeTypes.RelayedMessageParams memory p = BridgeTypes
            .RelayedMessageParams({
                operationId: OP_ID,
                originator: ORIGINATOR,
                sourceChainId: SOURCE_CHAIN_ID,
                recipient: RECIPIENT,
                message: bytes("hi")
            });

        vm.expectRevert(ICrossChainReceiver.Unauthorized.selector);
        receiverAll.receiveOperation(
            BridgeTypes.OperationType.MESSAGE,
            abi.encode(p)
        );
    }

    function test_default_handlers_revert_when_not_overridden() public {
        // MockFleetProxy only supports TRANSFER; MESSAGE and READ_STATE fall back to base which should revert
        BridgeTypes.RelayedMessageParams memory m = BridgeTypes
            .RelayedMessageParams({
                operationId: OP_ID,
                originator: ORIGINATOR,
                sourceChainId: SOURCE_CHAIN_ID,
                recipient: RECIPIENT,
                message: bytes("unsupported")
            });
        vm.expectRevert(ICrossChainReceiver.UnsupportedOperationType.selector);
        receiverTransferOnly.receiveOperation(
            BridgeTypes.OperationType.MESSAGE,
            abi.encode(m)
        );

        BridgeTypes.RelayedReadResponse memory r = BridgeTypes
            .RelayedReadResponse({
                readResponseData: bytes("unsupported"),
                operationId: OP_ID,
                sourceChainId: SOURCE_CHAIN_ID
            });
        vm.expectRevert(ICrossChainReceiver.UnsupportedOperationType.selector);
        receiverTransferOnly.receiveOperation(
            BridgeTypes.OperationType.READ_STATE,
            abi.encode(r)
        );
    }

    /* -------------------------------------------------------------------------- */
    /*                    supportsInterface & supported types                      */
    /* -------------------------------------------------------------------------- */

    function test_supportsInterface_true_for_receiver_and_erc165() public {
        assertTrue(
            receiverAll.supportsInterface(type(ICrossChainReceiver).interfaceId)
        );
        assertTrue(receiverAll.supportsInterface(type(IERC165).interfaceId));
    }

    function test_supportsInterface_false_for_unknown_interface() public {
        assertFalse(receiverAll.supportsInterface(bytes4(0x12345678)));
    }

    function test_getSupportedOperationTypes_returns_from_impl() public {
        BridgeTypes.OperationType[] memory typesAll = receiverAll
            .getSupportedOperationTypes();
        assertEq(typesAll.length, 3);
        assertEq(uint8(typesAll[0]), uint8(BridgeTypes.OperationType.MESSAGE));
        assertEq(
            uint8(typesAll[1]),
            uint8(BridgeTypes.OperationType.TRANSFER_ASSET)
        );
        assertEq(
            uint8(typesAll[2]),
            uint8(BridgeTypes.OperationType.READ_STATE)
        );

        BridgeTypes.OperationType[]
            memory typesTransferOnly = receiverTransferOnly
                .getSupportedOperationTypes();
        assertEq(typesTransferOnly.length, 1);
        assertEq(
            uint8(typesTransferOnly[0]),
            uint8(BridgeTypes.OperationType.TRANSFER_ASSET)
        );
    }
}
