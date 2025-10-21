// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {BridgeTypes} from "../../../src/libraries/BridgeTypes.sol";
import {BridgeCodec} from "../../../src/libraries/BridgeCodec.sol";

contract BridgeCodecHarness {
    function encode(
        BridgeTypes.OperationType op,
        bytes memory data
    ) external pure returns (bytes memory) {
        return BridgeCodec.encodePayload(op, data);
    }

    function decode(
        bytes calldata raw
    ) external pure returns (BridgeTypes.OperationType, bytes memory) {
        return BridgeCodec.decodePayload(raw);
    }
}

contract BridgeCodecTest is Test {
    BridgeCodecHarness internal harness;

    function setUp() public {
        harness = new BridgeCodecHarness();
    }

    function test_encodePayload_addsOpPrefixAndData() public view {
        bytes memory data = hex"deadbeef";
        bytes memory encoded = harness.encode(
            BridgeTypes.OperationType.READ_STATE,
            data
        );

        // first 2 bytes should equal the uint16 representation of READ_STATE (1)
        uint16 opPrefix = (uint16(uint8(encoded[0])) << 8) |
            uint16(uint8(encoded[1]));
        assertEq(opPrefix, uint16(BridgeTypes.OperationType.READ_STATE));

        // round-trip decode and compare
        (BridgeTypes.OperationType op, bytes memory decodedData) = harness
            .decode(encoded);
        assertEq(uint256(op), uint256(BridgeTypes.OperationType.READ_STATE));
        assertEq(decodedData, data);
    }

    function test_decodePayload_success_paths() public view {
        bytes memory data = hex"010203";

        // MESSAGE
        {
            bytes memory payload = abi.encodePacked(
                uint16(BridgeTypes.OperationType.MESSAGE),
                data
            );
            (BridgeTypes.OperationType op, bytes memory out) = harness.decode(
                payload
            );
            assertEq(uint256(op), uint256(BridgeTypes.OperationType.MESSAGE));
            assertEq(out, data);
        }

        // TRANSFER_ASSET
        {
            bytes memory payload = abi.encodePacked(
                uint16(BridgeTypes.OperationType.TRANSFER_ASSET),
                data
            );
            (BridgeTypes.OperationType op, bytes memory out) = harness.decode(
                payload
            );
            assertEq(
                uint256(op),
                uint256(BridgeTypes.OperationType.TRANSFER_ASSET)
            );
            assertEq(out, data);
        }
    }

    function test_decodePayload_revert_whenTooShort() public {
        // length 0
        vm.expectRevert(BridgeCodec.InvalidPayloadLength.selector);
        harness.decode("");

        // length 1
        vm.expectRevert(BridgeCodec.InvalidPayloadLength.selector);
        harness.decode(hex"01");
    }

    function test_decodePayload_revert_whenInvalidOperationType() public {
        // max enum value is 2, so 3 is invalid
        uint16 invalidType = uint16(3);
        bytes memory payload = abi.encodePacked(invalidType);
        vm.expectRevert(BridgeCodec.InvalidOperationType.selector);
        harness.decode(payload);
    }
}
