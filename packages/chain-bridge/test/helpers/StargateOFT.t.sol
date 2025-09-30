// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";

// Shared helper utilities for building and decoding OFT compose messages
abstract contract StargateOFTHelpers {
    // Extract amountLD from a full OFT compose message
    function getAmountLD(
        bytes calldata message
    ) internal pure returns (uint256) {
        return OFTComposeMsgCodec.amountLD(message);
    }

    // Extract the inner compose message (payload) from a full OFT compose message
    function getComposeMsg(
        bytes calldata message
    ) internal pure returns (bytes memory) {
        return OFTComposeMsgCodec.composeMsg(message);
    }

    // Extract srcEid from a full OFT compose message
    function getSrcEid(bytes calldata message) internal pure returns (uint32) {
        return uint32(bytes4(message[8:12]));
    }

    // Extract composeFrom from a full OFT compose message
    // ABI-aligned layout only:
    // [8b nonce][4b srcEid][32b amount][32b composeFrom (left-padded)][32b offset][bytes composeMsg]
    // composeFrom occupies bytes 44..76
    function getComposeFrom(
        bytes calldata message
    ) internal pure returns (address) {
        return address(uint160(uint256(bytes32(message[44:76]))));
    }

    // External wrappers to allow passing bytes memory (auto-encoded to calldata)
    function oftAmountLD(
        bytes calldata message
    ) external pure returns (uint256) {
        return getAmountLD(message);
    }

    function oftComposeMsg(
        bytes calldata message
    ) external pure returns (bytes memory) {
        return getComposeMsg(message);
    }

    function oftSrcEid(bytes calldata message) external pure returns (uint32) {
        return getSrcEid(message);
    }

    function oftComposeFrom(
        bytes calldata message
    ) external pure returns (address) {
        return getComposeFrom(message);
    }

    // Helper to encode an OFT compose message matching StargateAdapter._decodeOFTCompose layout
    // Layout: [8b nonce][4b srcEid][32b amountLD][32b composeFrom] + raw abi.encode(RelayedTransferParams)
    function encodeOFTCompose(
        uint64 nonce,
        uint32 srcEid,
        uint256 amountLD,
        address composeFrom,
        bytes memory composeMsg
    ) internal pure returns (bytes memory) {
        // Compose tail = 32-byte left-padded address + raw encoded struct bytes
        bytes32 composeFromWord = bytes32(uint256(uint160(composeFrom)));
        bytes memory packed = abi.encodePacked(composeFromWord, composeMsg);
        return OFTComposeMsgCodec.encode(nonce, srcEid, amountLD, packed);
    }

    // Helper to create a properly encoded RelayedTransferParams payload
    function createRelayedTransferParams(
        address recipient,
        address asset,
        uint256 amount,
        uint256 sourceChainId,
        bytes32 operationId,
        address originator
    ) internal pure returns (bytes memory) {
        BridgeTypes.RelayedTransferParams memory params = BridgeTypes
            .RelayedTransferParams({
                recipient: recipient,
                asset: asset,
                amount: amount,
                sourceChainId: uint16(sourceChainId),
                operationId: operationId,
                originator: originator,
                message: ""
            });
        return abi.encode(params);
    }
}
