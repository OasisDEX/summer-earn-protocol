// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";
import {AddressCast} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";

/**
 * @title LayerZeroComposeHelper
 * @notice Helper library for LayerZero compose message operations
 * @dev Provides utilities for decoding OFT compose messages and validating compose operations
 */
library LayerZeroComposeHelper {
    using AddressCast for bytes32;

    /// @notice Error thrown when the compose message is invalid
    error InvalidComposeMessage();

    /**
     * @notice Decode OFT compose message header and payload
     * @dev Layout: [8b nonce][4b srcEid][32b amountLD][32b composeFrom][bytes composeMsg]
     * @param message The OFT compose message to decode
     * @return srcEid Source endpoint ID
     * @return amountLD Amount in local decimals
     * @return composeFrom Address that sent the compose message
     * @return composeMsg The compose message payload
     */
    function decodeOFTCompose(
        bytes calldata message
    )
        internal
        pure
        returns (
            uint32 srcEid,
            uint256 amountLD,
            address composeFrom,
            bytes memory composeMsg
        )
    {
        // Sanity-check the OFT compose header is fully present before decoding.
        // Layout (ABI-aligned as produced by OFTComposeMsgCodec):
        //  - 8B nonce | 4B srcEid                                   (total so far: 12 bytes)
        //  - 32B amountLD                                           (total so far: 44 bytes)
        //  - 32B composeFrom (left-padded address, present when composeMsg != empty)
        // Minimum length when composeFrom is present: 12 + 32 + 32 = 76 bytes.
        if (message.length < 76) revert InvalidComposeMessage();

        // Use official codec for srcEid extraction
        srcEid = OFTComposeMsgCodec.srcEid(message);
        amountLD = OFTComposeMsgCodec.amountLD(message);
        composeMsg = OFTComposeMsgCodec.composeMsg(message);
        composeFrom = OFTComposeMsgCodec.composeFrom(message).toAddress();
    }
}
